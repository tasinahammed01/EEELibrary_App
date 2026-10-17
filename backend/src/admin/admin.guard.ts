import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthenticatedRequest } from '../auth/auth.types';
import { PrismaService } from '../database/prisma.service';
import { AdminRole } from '../generated/prisma/enums';
export const Roles = (...roles: AdminRole[]) =>
  SetMetadata('adminRoles', roles);
export interface AdminRequest extends AuthenticatedRequest {
  admin?: {
    id: string;
    role: AdminRole;
    status: string;
    displayName: string;
    email: string;
  };
}
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    private readonly db: PrismaService,
    private readonly reflector: Reflector,
  ) {}
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AdminRequest>();
    if (!req.verifiedIdentity) throw new UnauthorizedException();
    const admin = await this.db.adminUser.findUnique({
      where: { externalAuthId: req.verifiedIdentity.firebaseUid },
      select: {
        id: true,
        role: true,
        status: true,
        displayName: true,
        email: true,
      },
    });
    const roles = this.reflector.getAllAndOverride<AdminRole[]>('adminRoles', [
      context.getHandler(),
      context.getClass(),
    ]);
    if (
      !admin ||
      admin.status !== 'ACTIVE' ||
      (roles && !roles.includes(admin.role))
    )
      throw new ForbiddenException();
    req.admin = admin;
    return true;
  }
}
