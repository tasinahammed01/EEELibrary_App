import { PurchaseNoStoreInterceptor } from './purchase-no-store.interceptor';
import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { SafeUser } from '../auth/auth.types';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';
import { ActiveUserGuard } from '../auth/guards/active-user.guard';
import { BootstrapBodyPipe } from '../auth/pipes/bootstrap-body.pipe';
import {
  CurrentReviewer,
  PaymentReviewerGuard,
} from './payment-reviewer.guard';
import {
  BookSlugParams,
  CreateOrderDto,
  PurchasePageDto,
  RejectPaymentDto,
  ReviewPageDto,
  SubmitPaymentDto,
} from './purchase.dto';
import { PurchaseService } from './purchase.service';
import { EntitlementService } from './entitlement.service';
import { ManualPaymentOptions } from './manual-payment-options';
@Controller()
@UseInterceptors(PurchaseNoStoreInterceptor)
@UseGuards(FirebaseAuthGuard, ActiveUserGuard)
export class PurchaseController {
  constructor(
    private readonly purchases: PurchaseService,
    private readonly entitlements: EntitlementService,
    private readonly options: ManualPaymentOptions,
  ) {}
  @Get('orders/payment-options') optionsList() {
    return this.options.list();
  }
  @Post('orders') @HttpCode(200) create(
    @CurrentUser() user: SafeUser,
    @Body() body: CreateOrderDto,
  ) {
    return this.purchases.create(user.id, body.bookSlug);
  }
  @Get('orders') list(
    @CurrentUser() user: SafeUser,
    @Query() query: PurchasePageDto,
  ) {
    return this.purchases.list(user.id, query);
  }
  @Get('orders/:id') get(
    @CurrentUser() user: SafeUser,
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.purchases.get(user.id, id);
  }
  @Post('orders/:id/payment') @HttpCode(200) submit(
    @CurrentUser() user: SafeUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: SubmitPaymentDto,
  ) {
    return this.purchases.submit(user.id, id, body);
  }
  @Get('books/:slug/access') access(
    @CurrentUser() user: SafeUser,
    @Param() params: BookSlugParams,
  ) {
    return this.purchases.access(user.id, params.slug);
  }
  @Get('library') library(
    @CurrentUser() user: SafeUser,
    @Query() query: PurchasePageDto,
  ) {
    return this.entitlements.library(user.id, query);
  }
}
@Controller('admin/payments')
@UseInterceptors(PurchaseNoStoreInterceptor)
@UseGuards(FirebaseAuthGuard, PaymentReviewerGuard)
export class PaymentReviewController {
  constructor(private readonly purchases: PurchaseService) {}
  @Get() list(@Query() query: ReviewPageDto) {
    return this.purchases.reviews(query);
  }
  @Get(':id') get(@Param('id', new ParseUUIDPipe()) id: string) {
    return this.purchases.reviewDetail(id);
  }
  @Post(':id/approve') @HttpCode(200) approve(
    @CurrentReviewer() adminId: string,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body(BootstrapBodyPipe) _body: undefined,
  ) {
    return this.purchases.review(adminId, id, 'APPROVED');
  }
  @Post(':id/reject') @HttpCode(200) reject(
    @CurrentReviewer() adminId: string,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: RejectPaymentDto,
  ) {
    return this.purchases.review(adminId, id, 'REJECTED', body.reason);
  }
}
