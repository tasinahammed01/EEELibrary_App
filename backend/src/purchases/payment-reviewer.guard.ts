import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth/auth.types';
import { PrismaService } from '../database/prisma.service';
export interface ReviewRequest extends AuthenticatedRequest {
  paymentReviewerId?: string;
}
@Injectable()
export class PaymentReviewerGuard implements CanActivate {
  constructor(private readonly db: PrismaService) {}
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<ReviewRequest>();
    if (!request.verifiedIdentity) throw new UnauthorizedException();
    const admin = await this.db.adminUser.findUnique({
      where: { externalAuthId: request.verifiedIdentity.firebaseUid },
      select: { id: true, status: true, role: true },
    });
    if (
      !admin ||
      admin.status !== 'ACTIVE' ||
      !['SUPER_ADMIN', 'PAYMENT_REVIEWER'].includes(admin.role)
    )
      throw new ForbiddenException();
    request.paymentReviewerId = admin.id;
    return true;
  }
}
export const CurrentReviewer = createParamDecorator(
  (_data: unknown, context: ExecutionContext): string => {
    const id = context
      .switchToHttp()
      .getRequest<ReviewRequest>().paymentReviewerId;
    if (!id) throw new ForbiddenException();
    return id;
  },
);
