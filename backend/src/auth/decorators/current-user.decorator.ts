import {
  createParamDecorator,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import {
  AuthenticatedRequest,
  SafeUser,
  VerifiedIdentity,
} from '../auth.types';

export const VerifiedFirebaseIdentity = createParamDecorator(
  (_data: unknown, context: ExecutionContext): VerifiedIdentity => {
    const identity = context
      .switchToHttp()
      .getRequest<AuthenticatedRequest>().verifiedIdentity;
    if (!identity) throw new UnauthorizedException();
    return identity;
  },
);
export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): SafeUser => {
    const user = context
      .switchToHttp()
      .getRequest<AuthenticatedRequest>().currentUser;
    if (!user) throw new UnauthorizedException();
    return user;
  },
);
