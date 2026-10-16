import {
  Injectable,
  OnModuleDestroy,
  ServiceUnavailableException,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  App,
  applicationDefault,
  deleteApp,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import { Auth, DecodedIdToken, getAuth } from 'firebase-admin/auth';
import { isEmail } from 'class-validator';
import { Environment } from '../config/environment';
import { VerifiedIdentity } from '../auth/auth.types';
import { recordAuthDiagnostic } from '../common/auth-diagnostics';

@Injectable()
export class FirebaseService implements OnModuleDestroy {
  private readonly app?: App;
  private readonly auth?: Auth;
  private readonly projectId?: string;
  private readonly ownsApp: boolean;

  constructor(config: ConfigService<Environment, true>) {
    this.projectId = config.get('FIREBASE_PROJECT_ID', { infer: true });
    this.ownsApp = false;
    if (!this.projectId) return; // Unconfigured auth fails closed; health stays available.
    try {
      const existing = getApps().find(
        (app) => app.name === 'eeelibrary-backend',
      );
      if (existing && existing.options.projectId !== this.projectId)
        throw new Error('Project mismatch');
      this.app =
        existing ??
        initializeApp(
          { projectId: this.projectId, credential: applicationDefault() },
          'eeelibrary-backend',
        );
      this.ownsApp = !existing;
      this.auth = getAuth(this.app);
    } catch {
      throw new Error('Firebase initialization failed');
    }
  }

  async verifyIdToken(token: string): Promise<VerifiedIdentity> {
    if (!this.auth || !this.projectId) {
      recordAuthDiagnostic({
        event: 'verification-rejected',
        reason: 'firebase-unconfigured',
      });
      throw new ServiceUnavailableException();
    }
    let decoded: DecodedIdToken;
    try {
      // Revocation check also rejects Firebase-disabled accounts. No extra getUser call.
      decoded = await this.auth.verifyIdToken(token, true);
    } catch (error) {
      const code =
        typeof error === 'object' && error !== null && 'code' in error
          ? error.code
          : undefined;
      recordAuthDiagnostic({
        event: 'verification-rejected',
        reason:
          code === 'auth/insufficient-permission'
            ? 'admin-permission-denied'
            : typeof code === 'string' &&
                [
                  'auth/argument-error',
                  'auth/invalid-id-token',
                  'auth/id-token-expired',
                  'auth/id-token-revoked',
                  'auth/user-disabled',
                  'auth/user-not-found',
                ].includes(code)
              ? 'sdk-identity-rejected'
              : 'sdk-unavailable',
      });
      if (
        typeof code === 'string' &&
        [
          'auth/argument-error',
          'auth/invalid-id-token',
          'auth/id-token-expired',
          'auth/id-token-revoked',
          'auth/user-disabled',
          'auth/user-not-found',
        ].includes(code)
      )
        throw new UnauthorizedException();
      throw new ServiceUnavailableException();
    }
    const now = Math.floor(Date.now() / 1000);
    if (
      !decoded ||
      typeof decoded !== 'object' ||
      typeof decoded.uid !== 'string' ||
      decoded.uid.length < 1 ||
      decoded.uid.length > 128 ||
      decoded.sub !== decoded.uid ||
      decoded.firebase?.tenant !== undefined ||
      decoded.aud !== this.projectId ||
      decoded.iss !== 'https://securetoken.google.com/' + this.projectId ||
      !Number.isInteger(decoded.exp) ||
      decoded.exp <= now ||
      !Number.isInteger(decoded.iat) ||
      decoded.iat < 0 ||
      decoded.iat > now ||
      !Number.isInteger(decoded.auth_time) ||
      decoded.auth_time < 0 ||
      decoded.auth_time > now
    ) {
      recordAuthDiagnostic({
        event: 'verification-rejected',
        reason:
          Number.isInteger(decoded?.iat) && decoded.iat > now
            ? 'issued-in-future'
            : Number.isInteger(decoded?.auth_time) && decoded.auth_time > now
              ? 'authenticated-in-future'
              : 'invalid-claims',
      });
      throw new UnauthorizedException();
    }
    // Existing schema requires email; only a verified Firebase email is usable.
    if (
      decoded.email_verified !== true ||
      typeof decoded.email !== 'string' ||
      decoded.email !== decoded.email.trim() ||
      decoded.email.length > 254 ||
      !isEmail(decoded.email)
    ) {
      recordAuthDiagnostic({
        event: 'verification-rejected',
        reason: 'email-policy',
      });
      throw new ForbiddenException();
    }
    const name: unknown = decoded.name;
    return Object.freeze({
      firebaseUid: decoded.uid,
      email: decoded.email.toLowerCase(),
      displayName:
        typeof name === 'string' && name.trim()
          ? Array.from(name.trim()).slice(0, 120).join('')
          : 'EEELibrary Reader',
    });
  }

  async onModuleDestroy(): Promise<void> {
    if (this.app && this.ownsApp) {
      try {
        await deleteApp(this.app);
      } catch {
        throw new Error('Firebase shutdown failed');
      }
    }
  }
}
