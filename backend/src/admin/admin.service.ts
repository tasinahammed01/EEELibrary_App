import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { Prisma } from '../generated/prisma/client';
import {
  AdminRole,
  EntitlementStatus,
  OrderStatus,
  PublicationStatus,
  UserStatus,
} from '../generated/prisma/enums';
import {
  AdminQuery,
  BookDto,
  BookPatch,
  CategoryDto,
  CategoryPatch,
  UserStatusDto,
} from './admin.dto';
export const categorySelect = {
  id: true,
  name: true,
  slug: true,
  description: true,
  isActive: true,
  sortOrder: true,
  createdAt: true,
} satisfies Prisma.CategorySelect;
export const bookSelect = {
  id: true,
  title: true,
  slug: true,
  description: true,
  categoryId: true,
  price: true,
  currency: true,
  status: true,
  pageCount: true,
  createdAt: true,
  category: { select: { id: true, name: true } },
} satisfies Prisma.BookSelect;
export const userSelect = {
  id: true,
  displayName: true,
  email: true,
  status: true,
  createdAt: true,
} satisfies Prisma.UserSelect;
const orderSelect = {
  id: true,
  amount: true,
  currency: true,
  status: true,
  createdAt: true,
  updatedAt: true,
  user: { select: { id: true, displayName: true } },
  book: { select: { id: true, title: true } },
  payments: {
    select: { id: true, status: true, method: true },
    orderBy: { createdAt: 'desc' as const },
    take: 1,
  },
} satisfies Prisma.OrderSelect;
const entitlementSelect = {
  id: true,
  status: true,
  createdAt: true,
  revokedAt: true,
  orderId: true,
  user: { select: { id: true, displayName: true } },
  book: { select: { id: true, title: true } },
} satisfies Prisma.EntitlementSelect;
export function slugFor(value: string): string {
  const result = value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
  if (!result) throw new BadRequestException();
  return result;
}
@Injectable()
export class AdminService {
  constructor(private readonly db: PrismaService) {}
  async dashboard(role: AdminRole) {
    const [
      publishedBooks,
      activeUsers,
      pendingPayments,
      completedOrders,
      activeEntitlements,
    ] = await this.db.$transaction(
      [
        this.db.book.count({
          where: { status: 'PUBLISHED', category: { isActive: true } },
        }),
        this.db.user.count({ where: { status: 'ACTIVE' } }),
        this.db.payment.count({ where: { status: 'PENDING' } }),
        this.db.order.count({ where: { status: 'COMPLETED' } }),
        this.db.entitlement.count({
          where: {
            status: 'ACTIVE',
            revokedAt: null,
            order: { status: 'COMPLETED' },
            user: { status: 'ACTIVE' },
            book: { status: 'PUBLISHED', category: { isActive: true } },
          },
        }),
      ],
      { isolationLevel: 'RepeatableRead' },
    );
    return role === 'CONTENT_MANAGER'
      ? { publishedBooks }
      : role === 'PAYMENT_REVIEWER'
        ? { pendingPayments, completedOrders }
        : {
            publishedBooks,
            activeUsers,
            pendingPayments,
            completedOrders,
            activeEntitlements,
          };
  }
  async list(
    kind:
      'books' | 'categories' | 'users' | 'orders' | 'entitlements' | 'audit',
    q: AdminQuery,
  ) {
    const paging = {
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
      orderBy: [{ createdAt: 'desc' as const }, { id: 'desc' as const }],
    };
    let items: unknown[], total: number;
    const status = (allowed: readonly string[]) => {
      if (q.status && !allowed.includes(q.status))
        throw new BadRequestException();
      return q.status;
    };
    if (kind === 'books') {
      const where: Prisma.BookWhereInput = {
        ...(q.search
          ? { title: { contains: q.search, mode: 'insensitive' } }
          : {}),
        ...(status(Object.values(PublicationStatus))
          ? { status: q.status as PublicationStatus }
          : {}),
      };
      [items, total] = await this.db.$transaction([
        this.db.book.findMany({ ...paging, where, select: bookSelect }),
        this.db.book.count({ where }),
      ]);
    } else if (kind === 'categories') {
      if (q.status) throw new BadRequestException();
      const where: Prisma.CategoryWhereInput = q.search
        ? { name: { contains: q.search, mode: 'insensitive' } }
        : {};
      [items, total] = await this.db.$transaction([
        this.db.category.findMany({ ...paging, where, select: categorySelect }),
        this.db.category.count({ where }),
      ]);
    } else if (kind === 'users') {
      const where: Prisma.UserWhereInput = {
        ...(q.search
          ? { displayName: { contains: q.search, mode: 'insensitive' } }
          : {}),
        ...(status(Object.values(UserStatus))
          ? { status: q.status as UserStatus }
          : {}),
      };
      [items, total] = await this.db.$transaction([
        this.db.user.findMany({ ...paging, where, select: userSelect }),
        this.db.user.count({ where }),
      ]);
    } else if (kind === 'orders') {
      const where: Prisma.OrderWhereInput = status(Object.values(OrderStatus))
        ? { status: q.status as OrderStatus }
        : {};
      if (q.search) throw new BadRequestException();
      [items, total] = await this.db.$transaction([
        this.db.order.findMany({ ...paging, where, select: orderSelect }),
        this.db.order.count({ where }),
      ]);
    } else if (kind === 'entitlements') {
      const where: Prisma.EntitlementWhereInput = status(
        Object.values(EntitlementStatus),
      )
        ? { status: q.status as EntitlementStatus }
        : {};
      if (q.search) throw new BadRequestException();
      [items, total] = await this.db.$transaction([
        this.db.entitlement.findMany({
          ...paging,
          where,
          select: entitlementSelect,
        }),
        this.db.entitlement.count({ where }),
      ]);
    } else {
      if (q.status || q.search) throw new BadRequestException();
      [items, total] = await this.db.$transaction([
        this.db.auditLog.findMany({
          ...paging,
          select: {
            id: true,
            action: true,
            targetType: true,
            targetId: true,
            createdAt: true,
            adminActor: { select: { id: true, displayName: true } },
          },
        }),
        this.db.auditLog.count(),
      ]);
    }
    return {
      items,
      total,
      page: q.page,
      pageSize: q.pageSize,
      hasMore: q.page * q.pageSize < total,
    };
  }
  async detail(
    kind: 'books' | 'users' | 'orders' | 'entitlements',
    id: string,
  ) {
    const value =
      kind === 'books'
        ? await this.db.book.findUnique({ where: { id }, select: bookSelect })
        : kind === 'users'
          ? await this.db.user.findUnique({ where: { id }, select: userSelect })
          : kind === 'orders'
            ? await this.db.order.findUnique({
                where: { id },
                select: orderSelect,
              })
            : await this.db.entitlement.findUnique({
                where: { id },
                select: entitlementSelect,
              });
    if (!value) throw new NotFoundException();
    return value;
  }
  async mutate(
    actorId: string,
    kind: 'books' | 'categories' | 'users',
    id: string | undefined,
    body: BookDto | BookPatch | CategoryDto | CategoryPatch | UserStatusDto,
  ) {
    try {
      return await this.db.$transaction(
        async (tx) => {
          // User-status writers share purchase lock order: owner before admin. Catalog writes never lock owner.
          if (kind === 'users' && id)
            await tx.$queryRaw`SELECT id FROM "User" WHERE id=${id}::uuid FOR UPDATE`;
          await tx.$queryRaw`SELECT id FROM "AdminUser" WHERE id=${actorId}::uuid FOR SHARE`;
          const actor = await tx.adminUser.findUnique({
            where: { id: actorId },
            select: { status: true, role: true },
          });
          if (
            !actor ||
            actor.status !== 'ACTIVE' ||
            !(
              kind === 'users'
                ? ['SUPER_ADMIN']
                : ['SUPER_ADMIN', 'CONTENT_MANAGER']
            ).includes(actor.role)
          )
            throw new ForbiddenException();
          let result: { id: string };
          if (kind === 'users') {
            if (!id) throw new BadRequestException();
            const data = body as UserStatusDto;
            const previous = await tx.user.findUnique({
              where: { id },
              select: { status: true },
            });
            if (!previous) throw new NotFoundException();
            if (previous.status === data.status)
              return tx.user.findUniqueOrThrow({
                where: { id },
                select: userSelect,
              });
            result = await tx.user.update({
              where: { id },
              data: { status: data.status },
              select: userSelect,
            });
            await tx.auditLog.create({
              data: {
                adminActorId: actorId,
                action: 'USER_STATUS_CHANGED',
                targetType: 'User',
                targetId: id,
                metadata: { from: previous.status, to: data.status },
              },
            });
            return result;
          }
          if (kind === 'categories') {
            const data = body as CategoryDto;
            result = id
              ? await tx.category.update({
                  where: { id },
                  data,
                  select: categorySelect,
                })
              : await tx.category.create({
                  data: { ...data, slug: slugFor(data.name) },
                  select: categorySelect,
                });
          } else {
            const data = body as BookDto;
            if (
              data.categoryId &&
              !(await tx.category.findUnique({
                where: { id: data.categoryId },
                select: { id: true },
              }))
            )
              throw new BadRequestException();
            const previous = id
              ? await tx.book.findUnique({
                  where: { id },
                  select: { previewPageCount: true },
                })
              : null;
            if (
              data.pageCount !== undefined &&
              previous &&
              data.pageCount < previous.previewPageCount
            )
              throw new BadRequestException();
            result = id
              ? await tx.book.update({
                  where: { id },
                  data,
                  select: bookSelect,
                })
              : await tx.book.create({
                  data: { ...data, slug: slugFor(data.title) },
                  select: bookSelect,
                });
          }
          await tx.auditLog.create({
            data: {
              adminActorId: actorId,
              action:
                (kind === 'books' ? 'BOOK_' : 'CATEGORY_') +
                (id ? 'UPDATED' : 'CREATED'),
              targetType: kind === 'books' ? 'Book' : 'Category',
              targetId: result.id,
            },
          });
          return result;
        },
        { maxWait: 10000, timeout: 10000 },
      );
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (['P2002', 'P2034'].includes(error.code))
          throw new ConflictException();
        if (error.code === 'P2025') throw new NotFoundException();
        if (['P2003', 'P2004'].includes(error.code))
          throw new BadRequestException();
      }
      throw error;
    }
  }
}
