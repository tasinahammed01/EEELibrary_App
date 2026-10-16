import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { FirebaseModule } from '../firebase/firebase.module';
import { PrismaModule } from '../database/prisma.module';
import {
  PurchaseController,
  PaymentReviewController,
} from './purchase.controller';
import { PurchaseService } from './purchase.service';
import { EntitlementService } from './entitlement.service';
import { ManualPaymentOptions } from './manual-payment-options';
import { PaymentReviewerGuard } from './payment-reviewer.guard';
@Module({
  imports: [AuthModule, FirebaseModule, PrismaModule],
  controllers: [PurchaseController, PaymentReviewController],
  providers: [
    PurchaseService,
    EntitlementService,
    ManualPaymentOptions,
    PaymentReviewerGuard,
  ],
})
export class PurchaseModule {}
