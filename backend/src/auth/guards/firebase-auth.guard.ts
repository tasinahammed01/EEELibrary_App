import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { FirebaseService } from '../../firebase/firebase.service';
import { AuthenticatedRequest } from '../auth.types';

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(private readonly firebase: FirebaseService) {}
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    // Exactly one credential, no comma-joined/duplicate headers or whitespace tokens.
    const header = request.headers.authorization;
    if (
      typeof header !== 'string' ||
      header.length > 8192 ||
      request.rawHeaders.filter(
        (value, index) =>
          index % 2 === 0 && value.toLowerCase() === 'authorization',
      ).length !== 1
    )
      throw new UnauthorizedException();
    const match = /^Bearer ([^\s,]+)$/i.exec(header);
    const token = match?.[1];
    if (!token) throw new UnauthorizedException();
    request.verifiedIdentity = await this.firebase.verifyIdToken(token);
    return true;
  }
}
