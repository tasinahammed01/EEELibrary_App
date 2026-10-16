import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '../generated/prisma/client';
import { publicBookSummarySelect } from '../catalog/catalog.service';
import { EntitlementService } from './entitlement.service';
import { ManualPaymentOptions } from './manual-payment-options';
import {
  PurchasePageDto,
  ReviewPageDto,
  SubmitPaymentDto,
} from './purchase.dto';

export const safeOrderSelect = {
  id: true,
  amount: true,
  currency: true,
  status: true,
  createdAt: true,
  book: { select: publicBookSummarySelect },
  payments: {
    take: 1,
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    select: {
      status: true,
      method: true,
      createdAt: true,
      reviewedAt: true,
      rejectionReason: true,
    },
  },
} satisfies Prisma.OrderSelect;
type PublicOrder = Prisma.OrderGetPayload<{ select: typeof safeOrderSelect }>;
const publicReasons = new Set([
  'REFERENCE_NOT_FOUND',
  'AMOUNT_MISMATCH',
  'METHOD_MISMATCH',
]);
function safeOrderDto(order: PublicOrder): PublicOrder {
  return {
    ...order,
    payments: order.payments.map((payment) => ({
      ...payment,
      rejectionReason:
        payment.rejectionReason !== null &&
        publicReasons.has(payment.rejectionReason)
          ? payment.rejectionReason
          : null,
    })),
  };
}
// References are needed only by trusted payment reviewers; never in user DTOs/logs.
const reviewSelect = {
  id: true,
  method: true,
  transactionReference: true,
  amount: true,
  currency: true,
  status: true,
  createdAt: true,
  reviewedAt: true,
  rejectionReason: true,
  order: { select: safeOrderSelect },
} satisfies Prisma.PaymentSelect;
@Injectable()
export class PurchaseService {
  constructor(
    private readonly db: PrismaService,
    private readonly entitlements: EntitlementService,
    private readonly options: ManualPaymentOptions,
  ) {}
  private async mutate<T>(
    action: (tx: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    try {
      return await this.db.$transaction(action, {
        maxWait: 10000,
        timeout: 10000,
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        ['P2002', 'P2034'].includes(error.code)
      )
        throw new ConflictException();
      throw error;
    }
  }
  private async lockUser(tx: Prisma.TransactionClient, userId: string) {
    const rows = await tx.$queryRaw<
      { status: string }[]
    >`SELECT status FROM "User" WHERE id=${userId}::uuid FOR UPDATE`;
    if (rows[0]?.status !== 'ACTIVE') throw new ForbiddenException();
  }
  private async book(tx: Prisma.TransactionClient, slug: string) {
    await tx.$queryRaw`SELECT b.id FROM "Book" b JOIN "Category" c ON c.id=b."categoryId" WHERE b.slug=${slug} FOR SHARE OF b,c`;
    const book = await tx.book.findFirst({
      where: { slug, status: 'PUBLISHED', category: { isActive: true } },
      select: { id: true, price: true, currency: true },
    });
    if (!book) throw new NotFoundException();
    return book;
  }
  private async order(
    tx: Prisma.TransactionClient,
    id: string,
    userId: string,
  ) {
    const order = await tx.order.findFirst({
      where: { id, userId },
      select: safeOrderSelect,
    });
    if (!order) throw new NotFoundException();
    return safeOrderDto(order);
  }
  create(userId: string, slug: string) {
    return this.mutate(async (tx) => {
      await this.lockUser(tx, userId);
      const book = await this.book(tx, slug);
      const owned = await this.entitlements.owned(tx, userId, book.id);
      if (owned) {
        if (
          owned.status !== 'ACTIVE' ||
          owned.revokedAt !== null ||
          owned.order.status !== 'COMPLETED'
        )
          throw new ForbiddenException();
        return this.order(tx, owned.orderId, userId);
      }
      const pending = await tx.order.findFirst({
        where: {
          userId,
          bookId: book.id,
          status: { in: ['PENDING_PAYMENT', 'PAYMENT_SUBMITTED'] },
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        select: { id: true, status: true },
      });
      const free = book.price.isZero();
      if (pending) {
        // Preserve submitted payments for review. An unpaid quote must not force
        // a payment after the resource becomes free; cancel it without changing
        // its immutable amount, then create the zero-price acquisition below.
        if (!free || pending.status === 'PAYMENT_SUBMITTED')
          return this.order(tx, pending.id, userId);
        await tx.$queryRaw`SELECT id FROM "Order" WHERE id=${pending.id}::uuid FOR UPDATE`;
        if (
          await tx.payment.count({
            where: { orderId: pending.id, status: 'PENDING' },
          })
        )
          throw new ConflictException();
        const cancelled = await tx.order.updateMany({
          where: { id: pending.id, userId, status: 'PENDING_PAYMENT' },
          data: { status: 'CANCELLED' },
        });
        if (cancelled.count !== 1) throw new ConflictException();
      }
      if (!free) this.options.require();
      const order = await tx.order.create({
        data: {
          userId,
          bookId: book.id,
          amount: book.price,
          currency: book.currency,
          status: free ? 'COMPLETED' : 'PENDING_PAYMENT',
        },
        select: { id: true },
      });
      if (free)
        await tx.entitlement.create({
          data: {
            userId,
            bookId: book.id,
            orderId: order.id,
            status: 'ACTIVE',
          },
        });
      return this.order(tx, order.id, userId);
    });
  }
  submit(userId: string, id: string, input: SubmitPaymentDto) {
    return this.mutate(async (tx) => {
      await this.lockUser(tx, userId);
      await tx.$queryRaw`SELECT id FROM "Order" WHERE id=${id}::uuid AND "userId"=${userId}::uuid FOR UPDATE`;
      const order = await tx.order.findFirst({
        where: { id, userId },
        select: {
          id: true,
          bookId: true,
          status: true,
          amount: true,
          currency: true,
          book: { select: { slug: true } },
        },
      });
      if (!order) throw new NotFoundException();
      await this.book(tx, order.book.slug);
      const existing = await tx.payment.findUnique({
        where: { transactionReference: input.reference },
        select: { orderId: true, userId: true, method: true, status: true },
      });
      if (existing) {
        if (
          existing.orderId === id &&
          existing.userId === userId &&
          existing.method === input.method &&
          existing.status !== 'REJECTED'
        )
          return this.order(tx, id, userId);
        throw new ConflictException();
      }
      if (order.status !== 'PENDING_PAYMENT' || !order.amount.isPositive())
        throw new ConflictException();
      if (await this.entitlements.owned(tx, userId, order.bookId))
        throw new ConflictException();
      this.options.require(input.method);
      await tx.payment.create({
        data: {
          orderId: id,
          userId,
          method: input.method,
          transactionReference: input.reference,
          amount: order.amount,
          currency: order.currency,
        },
      });
      await tx.order.update({
        where: { id },
        data: { status: 'PAYMENT_SUBMITTED' },
      });
      return this.order(tx, id, userId);
    });
  }
  get(userId: string, id: string) {
    return this.db.order
      .findFirst({ where: { id, userId }, select: safeOrderSelect })
      .then((order) => {
        if (!order) throw new NotFoundException();
        return safeOrderDto(order);
      });
  }
  async list(userId: string, query: PurchasePageDto) {
    const where = { userId };
    const [items, total] = await this.db.$transaction(
      [
        this.db.order.findMany({
          where,
          skip: (query.page - 1) * query.pageSize,
          take: query.pageSize,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          select: safeOrderSelect,
        }),
        this.db.order.count({ where }),
      ],
      { isolationLevel: 'RepeatableRead' },
    );
    return {
      items: items.map(safeOrderDto),
      total,
      page: query.page,
      pageSize: query.pageSize,
      hasMore: query.page * query.pageSize < total,
    };
  }
  access(userId: string, slug: string) {
    return this.db.$transaction(
      async (tx) => {
        const book = await tx.book.findFirst({
          where: { slug, status: 'PUBLISHED', category: { isActive: true } },
          select: { id: true },
        });
        if (!book) throw new NotFoundException();
        const entitlement = await this.entitlements.owned(tx, userId, book.id);
        const owned =
          entitlement?.status === 'ACTIVE' &&
          entitlement.revokedAt === null &&
          entitlement.order.status === 'COMPLETED';
        const order = owned
          ? await this.order(tx, entitlement.orderId, userId)
          : await tx.order.findFirst({
              where: { userId, bookId: book.id },
              orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
              select: safeOrderSelect,
            });
        return { owned, order: order ? safeOrderDto(order) : null };
      },
      { isolationLevel: 'RepeatableRead' },
    );
  }
  async reviews(query: ReviewPageDto) {
    const where = { ...(query.status ? { status: query.status } : {}) };
    const [items, total] = await this.db.$transaction([
      this.db.payment.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        select: reviewSelect,
      }),
      this.db.payment.count({ where }),
    ]);
    return {
      items,
      total,
      page: query.page,
      pageSize: query.pageSize,
      hasMore: query.page * query.pageSize < total,
    };
  }
  async reviewDetail(id: string) {
    const payment = await this.db.payment.findUnique({
      where: { id },
      select: reviewSelect,
    });
    if (!payment) throw new NotFoundException();
    return payment;
  }
  review(
    adminId: string,
    id: string,
    decision: 'APPROVED' | 'REJECTED',
    reason?: string,
  ) {
    return this.mutate(async (tx) => {
      // Fixed lock order: owner, order, payment, reviewer, then catalog. All purchase writers
      // serialize on the same owner row, including free grants and submissions.
      const initial = await tx.payment.findUnique({
        where: { id },
        select: { userId: true, orderId: true },
      });
      if (!initial) throw new NotFoundException();
      await this.lockUser(tx, initial.userId);
      await tx.$queryRaw`SELECT id FROM "Order" WHERE id=${initial.orderId}::uuid FOR UPDATE`;
      await tx.$queryRaw`SELECT id FROM "Payment" WHERE id=${id}::uuid FOR UPDATE`;
      await tx.$queryRaw`SELECT id FROM "AdminUser" WHERE id=${adminId}::uuid FOR SHARE`;
      const admin = await tx.adminUser.findUnique({
        where: { id: adminId },
        select: { status: true, role: true },
      });
      if (
        !admin ||
        admin.status !== 'ACTIVE' ||
        !['SUPER_ADMIN', 'PAYMENT_REVIEWER'].includes(admin.role)
      )
        throw new ForbiddenException();
      const payment = await tx.payment.findUniqueOrThrow({
        where: { id },
        include: { order: { include: { book: { select: { slug: true } } } } },
      });
      if (
        payment.userId !== initial.userId ||
        payment.orderId !== initial.orderId
      )
        throw new ConflictException();
      if (payment.status === decision)
        return tx.payment.findUniqueOrThrow({
          where: { id },
          select: reviewSelect,
        });
      if (
        payment.status !== 'PENDING' ||
        payment.order.status !== 'PAYMENT_SUBMITTED' ||
        !payment.amount.equals(payment.order.amount) ||
        payment.currency !== payment.order.currency
      )
        throw new ConflictException();
      if (decision === 'APPROVED') {
        await this.book(tx, payment.order.book.slug);
        if (
          await this.entitlements.owned(
            tx,
            payment.userId,
            payment.order.bookId,
          )
        )
          throw new ConflictException();
        await tx.entitlement.create({
          data: {
            userId: payment.userId,
            bookId: payment.order.bookId,
            orderId: payment.orderId,
            status: 'ACTIVE',
          },
        });
        await tx.order.update({
          where: { id: payment.orderId },
          data: { status: 'COMPLETED' },
        });
      } else {
        if (
          !reason ||
          ![
            'REFERENCE_NOT_FOUND',
            'AMOUNT_MISMATCH',
            'METHOD_MISMATCH',
          ].includes(reason)
        )
          throw new ConflictException();
        await tx.order.update({
          where: { id: payment.orderId },
          data: { status: 'PENDING_PAYMENT' },
        });
      }
      await tx.payment.update({
        where: { id },
        data: {
          status: decision,
          reviewedById: adminId,
          reviewedAt: new Date(),
          rejectionReason: decision === 'REJECTED' ? reason : null,
        },
      });
      await tx.auditLog.create({
        data: {
          adminActorId: adminId,
          action:
            decision === 'APPROVED' ? 'PAYMENT_APPROVED' : 'PAYMENT_REJECTED',
          targetType: 'Payment',
          targetId: id,
          metadata: { orderId: payment.orderId },
        },
      });
      if (decision === 'APPROVED')
        await tx.auditLog.create({
          data: {
            adminActorId: adminId,
            action: 'ENTITLEMENT_GRANTED',
            targetType: 'Order',
            targetId: payment.orderId,
            metadata: { paymentId: id },
          },
        });
      return tx.payment.findUniqueOrThrow({
        where: { id },
        select: reviewSelect,
      });
    });
  }
}
