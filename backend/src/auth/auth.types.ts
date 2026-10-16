import { Request } from 'express';
import { UserStatus } from '../generated/prisma/enums';

export interface VerifiedIdentity {
  readonly firebaseUid: string;
  readonly email: string;
  readonly displayName: string;
}
export interface SafeUser {
  readonly id: string;
  readonly email: string;
  readonly displayName: string;
  readonly status: UserStatus;
  readonly createdAt: Date;
}
export interface AuthenticatedRequest extends Request {
  verifiedIdentity?: VerifiedIdentity;
  currentUser?: SafeUser;
}
