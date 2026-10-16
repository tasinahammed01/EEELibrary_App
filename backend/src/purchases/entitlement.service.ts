import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '../generated/prisma/client';
import { publicBookSummarySelect } from '../catalog/catalog.service';
import { PurchasePageDto } from './purchase.dto';
@Injectable()
export class EntitlementService {
  constructor(private readonly db: PrismaService) {}
  async owned(tx: Prisma.TransactionClient, userId: string, bookId: string) {
    return tx.entitlement.findUnique({
      where: { userId_bookId: { userId, bookId } },
      select: {
        status: true,
        revokedAt: true,
        orderId: true,
        order: { select: { status: true } },
      },
    });
  }
  async library(userId: string, query: PurchasePageDto) {
    const where: Prisma.EntitlementWhereInput = {
      userId,
      status: 'ACTIVE',
      revokedAt: null,
      user: { status: 'ACTIVE' },
      order: { status: 'COMPLETED' },
      book: { status: 'PUBLISHED', category: { isActive: true } },
    };
    const [records, total] = await this.db.$transaction(
      [
        this.db.entitlement.findMany({
          where,
          skip: (query.page - 1) * query.pageSize,
          take: query.pageSize,
          orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
          select: { book: { select: publicBookSummarySelect } },
        }),
        this.db.entitlement.count({ where }),
      ],
      { isolationLevel: 'RepeatableRead' },
    );
    return {
      items: records.map((record) => record.book),
      page: query.page,
      pageSize: query.pageSize,
      total,
      hasMore: query.page * query.pageSize < total,
    };
  }
}
