import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '../generated/prisma/client';
import { CatalogQueryDto } from './catalog-query.dto';
// Explicit public allowlist: never return storage keys or protected resources.
export const publicBookSelect = {
  id: true,
  slug: true,
  title: true,
  description: true,
  price: true,
  currency: true,
  pageCount: true,
  createdAt: true,
  category: { select: { id: true, name: true, slug: true } },
} satisfies Prisma.BookSelect;
export const publicBookSummarySelect = {
  ...publicBookSelect,
  description: false,
} satisfies Prisma.BookSelect;
@Injectable()
export class CatalogService {
  constructor(private readonly db: PrismaService) {}
  categories() {
    return this.db.category.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }, { id: 'asc' }],
      select: { id: true, name: true, slug: true, description: true },
    });
  }
  async books(query: CatalogQueryDto) {
    const where: Prisma.BookWhereInput = {
      status: 'PUBLISHED',
      category: {
        isActive: true,
        ...(query.category ? { slug: query.category } : {}),
      },
      ...(query.search
        ? { title: { contains: query.search, mode: 'insensitive' } }
        : {}),
    };
    const orderBy: Prisma.BookOrderByWithRelationInput[] =
      query.sort === 'title'
        ? [{ title: 'asc' }, { id: 'asc' }]
        : query.sort === 'price-asc'
          ? [{ price: 'asc' }, { id: 'asc' }]
          : query.sort === 'price-desc'
            ? [{ price: 'desc' }, { id: 'asc' }]
            : [{ createdAt: 'desc' }, { id: 'asc' }];
    const [items, total] = await this.db.$transaction(
      [
        this.db.book.findMany({
          where,
          orderBy,
          skip: (query.page - 1) * query.pageSize,
          take: query.pageSize,
          select: publicBookSummarySelect,
        }),
        this.db.book.count({ where }),
      ],
      { isolationLevel: 'RepeatableRead' },
    );
    return {
      items,
      total,
      page: query.page,
      pageSize: query.pageSize,
      hasMore: query.page * query.pageSize < total,
    };
  }
  async book(slug: string) {
    const book = await this.db.book.findFirst({
      where: { slug, status: 'PUBLISHED', category: { isActive: true } },
      select: publicBookSelect,
    });
    if (!book) throw new NotFoundException();
    return book;
  }
}
