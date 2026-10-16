import { ConsoleLogger } from '@nestjs/common';

type VerificationReason =
  | 'firebase-unconfigured'
  | 'sdk-identity-rejected'
  | 'admin-permission-denied'
  | 'sdk-unavailable'
  | 'issued-in-future'
  | 'authenticated-in-future'
  | 'invalid-claims'
  | 'email-policy';
type AuthDiagnostic =
  | { event: 'verification-rejected'; reason: VerificationReason }
  | {
      event: 'http-response';
      route: '/api/v1/auth/bootstrap' | '/api/v1/auth/me';
      status: number;
    };
const logger = new ConsoleLogger('AuthDiagnostics', { logLevels: ['log'] });
export const authDiagnosticsEnabled = (): boolean =>
  process.env.NODE_ENV === 'development' &&
  process.env.AUTH_DEBUG_DIAGNOSTICS === 'true';

// Reconstruct the allowlisted fields; never serialize exceptions, requests or credentials.
export function recordAuthDiagnostic(data: AuthDiagnostic): void {
  if (!authDiagnosticsEnabled()) return;
  const safe =
    data.event === 'verification-rejected'
      ? { event: data.event, reason: data.reason }
      : { event: data.event, route: data.route, status: data.status };
  logger.log(JSON.stringify(safe));
}
