import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthService } from '../auth.service';
import { AuthenticatedRequest } from '../auth.types';

@Injectable()
export class ActiveUserGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (!request.verifiedIdentity) throw new UnauthorizedException();
    request.currentUser = await this.auth.getCurrentUser(
      request.verifiedIdentity,
    );
    return true;
  }
}
