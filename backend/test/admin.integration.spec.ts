jest.setTimeout(30000);
jest.mock('firebase-admin/auth', () => ({
  getAuth: () => {
    throw new Error(
      'Real Firebase disabled in controlled integration fixtures',
    );
  },
}));
import { config as loadDotEnv } from 'dotenv';
import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import {
  ForbiddenException,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { Server } from 'node:http';
import { PrismaService } from '../src/database/prisma.service';
import { Prisma } from '../src/generated/prisma/client';
import { Environment, validateEnvironment } from '../src/config/environment';
import { AdminService } from '../src/admin/admin.service';
import { AdminQuery } from '../src/admin/admin.dto';
import { AppModule } from '../src/app.module';
import { FirebaseService } from '../src/firebase/firebase.service';
import { configureApp } from '../src/config/configure-app';
import { CatalogService } from '../src/catalog/catalog.service';
const local = loadDotEnv({ quiet: true });
if (local.error || !local.parsed)
  throw new Error('Local test configuration required');
const env = validateEnvironment(local.parsed);
if (
  env.NODE_ENV !== 'development' ||
  new URL(env.DATABASE_URL).hostname !== '127.0.0.1'
)
  throw new Error('Loopback development database required');
const db = new PrismaService(new ConfigService<Environment, true>(env));
const marker = new Error('Rollback phase5 isolated fixtures');
function joined(tx: Prisma.TransactionClient): PrismaService {
  return new Proxy(db, {
    get(_target, key) {
      if (key === 'onModuleInit' || key === 'onModuleDestroy') return undefined;
      if (key === '$transaction')
        return (
          action:
            | ((inner: Prisma.TransactionClient) => Promise<unknown>)
            | Promise<unknown>[],
        ) => (Array.isArray(action) ? Promise.all(action) : action(tx));
      return Reflect.get(tx, key) as unknown;
    },
  });
}
async function isolated(
  run: (
    service: AdminService,
    tx: Prisma.TransactionClient,
    ids: {
      admin: string;
      user: string;
      category: string;
      book: string;
      order: string;
      entitlement: string;
      uid: string;
    },
  ) => Promise<void>,
) {
  try {
    await db.$transaction(
      async (tx) => {
        const uid = 'phase5-' + randomUUID();
        const admin = await tx.adminUser.create({
          data: {
            externalAuthId: uid + 'admin',
            email: uid + 'admin@example.test',
            displayName: 'Controlled operator',
            role: 'SUPER_ADMIN',
          },
        });
        const user = await tx.user.create({
          data: {
            externalAuthId: uid,
            email: uid + '@example.test',
            displayName: 'Controlled reader',
          },
        });
        const category = await tx.category.create({
          data: { name: 'Controlled category', slug: uid },
        });
        const book = await tx.book.create({
          data: {
            title: 'Controlled book',
            slug: uid,
            description: 'Controlled metadata',
            categoryId: category.id,
            price: '120',
            status: 'PUBLISHED',
            coverObjectKey: 'private-never-expose',
            pageCount: 20,
          },
        });
        const order = await tx.order.create({
          data: {
            userId: user.id,
            bookId: book.id,
            amount: '0',
            status: 'COMPLETED',
          },
        });
        const entitlement = await tx.entitlement.create({
          data: {
            userId: user.id,
            bookId: book.id,
            orderId: order.id,
            status: 'ACTIVE',
          },
        });
        await run(new AdminService(joined(tx)), tx, {
          admin: admin.id,
          user: user.id,
          category: category.id,
          book: book.id,
          order: order.id,
          entitlement: entitlement.id,
          uid,
        });
        throw marker;
      },
      { timeout: 20000 },
    );
  } catch (error) {
    if (error !== marker) throw error;
  }
}
beforeAll(async () => {
  await db.onModuleInit();
});
afterAll(async () => {
  await db.onModuleDestroy();
});
describe('admin PostgreSQL rollback-only integration', () => {
  it('dashboard uses real counts and limits role projection', async () =>
    isolated(async (s, _tx, _ids) => {
      const all = await s.dashboard('SUPER_ADMIN');
      expect(all).toEqual(
        expect.objectContaining({
          publishedBooks: expect.any(Number) as unknown,
          activeUsers: expect.any(Number) as unknown,
          pendingPayments: expect.any(Number) as unknown,
          completedOrders: expect.any(Number) as unknown,
          activeEntitlements: expect.any(Number) as unknown,
        }),
      );
      expect(Object.keys(await s.dashboard('CONTENT_MANAGER'))).toEqual([
        'publishedBooks',
      ]);
      expect(Object.keys(await s.dashboard('PAYMENT_REVIEWER'))).toEqual([
        'pendingPayments',
        'completedOrders',
      ]);
    }));
  it.each([
    'books',
    'categories',
    'users',
    'orders',
    'entitlements',
    'audit',
  ] as const)('bounded %s list with safe projection', async (kind) =>
    isolated(async (s, _tx, _ids) => {
      const q = new AdminQuery();
      q.pageSize = 1;
      const result = await s.list(kind, q);
      expect(result.items.length).toBeLessThanOrEqual(1);
      expect(result.pageSize).toBe(1);
      const serialized = JSON.stringify(result);
      expect(serialized).not.toContain('private-never-expose');
      expect(serialized).not.toContain('externalAuthId');
      for (const item of result.items)
        expect(item).not.toHaveProperty('metadata');
    }),
  );
  it.each(['books', 'users', 'orders', 'entitlements'] as const)(
    'safe %s detail and unknown UUID denial',
    async (kind) =>
      isolated(async (s, _tx, ids) => {
        const key = {
          books: 'book',
          users: 'user',
          orders: 'order',
          entitlements: 'entitlement',
        } as const;
        const result = await s.detail(kind, ids[key[kind]]);
        expect(result).toHaveProperty('id', ids[key[kind]]);
        expect(JSON.stringify(result)).not.toContain('private-never-expose');
        expect(result).not.toHaveProperty('externalAuthId');
        await expect(s.detail(kind, randomUUID())).rejects.toBeInstanceOf(
          NotFoundException,
        );
      }),
  );
  it('creates and updates category, stable slug and immutable audit events', async () =>
    isolated(async (s, tx, ids) => {
      const result = await s.mutate(ids.admin, 'categories', undefined, {
        name: 'Controlled New ' + randomUUID(),
        sortOrder: 2,
      });
      const cat = result as { id: string; slug: string };
      const updated = await s.mutate(ids.admin, 'categories', cat.id, {
        name: 'Renamed',
        isActive: false,
      });
      expect(updated).toMatchObject({ slug: cat.slug, isActive: false });
      expect(await tx.auditLog.count({ where: { targetId: cat.id } })).toBe(2);
    }));
  it('creates a draft free book then updates/publishes metadata without private fields', async () =>
    isolated(async (s, tx, ids) => {
      const result = await s.mutate(ids.admin, 'books', undefined, {
        title: 'New controlled ' + randomUUID(),
        description: 'Description',
        categoryId: ids.category,
        price: '0',
      });
      expect(result).toMatchObject({
        status: 'DRAFT',
        price: new Prisma.Decimal(0),
      });
      expect(result).not.toHaveProperty('coverObjectKey');
      const updated = await s.mutate(ids.admin, 'books', result.id, {
        price: '199.50',
        status: 'PUBLISHED',
      });
      expect(updated).toMatchObject({
        status: 'PUBLISHED',
        price: new Prisma.Decimal('199.50'),
      });
      expect(await tx.auditLog.count({ where: { targetId: result.id } })).toBe(
        2,
      );
    }));
  it('suspended user status and audit are atomic and idempotent', async () =>
    isolated(async (s, tx, ids) => {
      await s.mutate(ids.admin, 'users', ids.user, { status: 'SUSPENDED' });
      await s.mutate(ids.admin, 'users', ids.user, { status: 'SUSPENDED' });
      expect(
        await tx.user.findUnique({ where: { id: ids.user } }),
      ).toMatchObject({ status: 'SUSPENDED' });
      const audit = await tx.auditLog.findMany({
        where: { targetId: ids.user },
      });
      expect(audit).toHaveLength(1);
      expect(audit[0]).toMatchObject({
        action: 'USER_STATUS_CHANGED',
        metadata: { from: 'ACTIVE', to: 'SUSPENDED' },
        adminActorId: ids.admin,
      });
    }));
  it('revalidates admin status inside transaction', async () =>
    isolated(async (s, tx, ids) => {
      await tx.adminUser.update({
        where: { id: ids.admin },
        data: { status: 'DISABLED' },
      });
      await expect(
        s.mutate(ids.admin, 'users', ids.user, { status: 'DISABLED' }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(
        await tx.user.findUnique({ where: { id: ids.user } }),
      ).toMatchObject({ status: 'ACTIVE' });
    }));
  it('content manager cannot change user status but can edit metadata', async () =>
    isolated(async (s, tx, ids) => {
      await tx.adminUser.update({
        where: { id: ids.admin },
        data: { role: 'CONTENT_MANAGER' },
      });
      await expect(
        s.mutate(ids.admin, 'users', ids.user, { status: 'DISABLED' }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(
        await s.mutate(ids.admin, 'books', ids.book, { title: 'Changed' }),
      ).toMatchObject({ title: 'Changed' });
    }));
  it('rejects invalid category relation safely', async () =>
    isolated(async (s, _tx, ids) => {
      await expect(
        s.mutate(ids.admin, 'books', ids.book, { categoryId: randomUUID() }),
      ).rejects.toBeInstanceOf(BadRequestException);
    }));
  it('preserves page preview invariant', async () =>
    isolated(async (s, tx, ids) => {
      await tx.book.update({
        where: { id: ids.book },
        data: { previewPageCount: 10 },
      });
      await expect(
        s.mutate(ids.admin, 'books', ids.book, { pageCount: 5 }),
      ).rejects.toBeInstanceOf(BadRequestException);
    }));
  it('inactive category and unpublished book remain excluded from public catalog', async () =>
    isolated(async (s, tx, ids) => {
      const catalog = new CatalogService(joined(tx));
      const book = await tx.book.findUniqueOrThrow({ where: { id: ids.book } });
      await s.mutate(ids.admin, 'books', ids.book, { status: 'DRAFT' });
      await expect(catalog.book(book.slug)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      await s.mutate(ids.admin, 'books', ids.book, { status: 'PUBLISHED' });
      await s.mutate(ids.admin, 'categories', ids.category, {
        isActive: false,
      });
      await expect(catalog.book(book.slug)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    }));
  it('rejects irrelevant status filter', async () =>
    isolated(async (s) => {
      await expect(
        s.list('books', Object.assign(new AdminQuery(), { status: 'ACTIVE' })),
      ).rejects.toBeInstanceOf(BadRequestException);
    }));
  it('duplicate slug maps to safe conflict', async () =>
    isolated(async (s, tx, ids) => {
      const category = await tx.category.findUniqueOrThrow({
        where: { id: ids.category },
      });
      await expect(
        s.mutate(ids.admin, 'categories', undefined, { name: category.slug }),
      ).rejects.toBeInstanceOf(ConflictException);
    }));
  it('HTTP user status mutation immediately affects existing user guard', async () =>
    isolated(async (_s, tx, ids) => {
      const module = await Test.createTestingModule({ imports: [AppModule] })
        .overrideProvider(PrismaService)
        .useValue(joined(tx))
        .overrideProvider(FirebaseService)
        .useValue({
          verifyIdToken: (token: string) =>
            Promise.resolve({
              firebaseUid:
                token === 'controlled-admin' ? ids.uid + 'admin' : ids.uid,
              email: ids.uid + '@example.test',
              displayName: 'Controlled',
            }),
        })
        .compile();
      const app = module.createNestApplication({
        bodyParser: false,
        logger: false,
      });
      configureApp(app);
      await app.init();
      try {
        const server = app.getHttpServer() as Server;
        await request(server)
          .get('/api/v1/admin/me')
          .set('Authorization', 'Bearer controlled-user')
          .expect(403);
        await request(server)
          .get('/api/v1/admin/me')
          .set('Authorization', 'Bearer controlled-admin')
          .expect(200);
        await request(server)
          .patch('/api/v1/admin/users/' + ids.user + '/status')
          .set('Authorization', 'Bearer controlled-admin')
          .send({ status: 'DISABLED' })
          .expect(200);
        await request(server)
          .get('/api/v1/auth/me')
          .set('Authorization', 'Bearer controlled-user')
          .expect(403);
      } finally {
        await app.close();
      }
    }));
});

describe('admin atomic failure rollback', () => {
  it('does not persist a user status change when audit insertion fails', async () => {
    const uid = 'phase5-rollback-' + randomUUID();
    const admin = await db.adminUser.create({
      data: {
        externalAuthId: uid + 'admin',
        email: uid + 'admin@example.test',
        displayName: 'Rollback fixture',
        role: 'SUPER_ADMIN',
      },
    });
    const user = await db.user.create({
      data: {
        externalAuthId: uid,
        email: uid + '@example.test',
        displayName: 'Rollback fixture',
      },
    });
    try {
      const failing = new Proxy(db, {
        get(target, key) {
          if (key === '$transaction')
            return (
              action: (tx: Prisma.TransactionClient) => Promise<unknown>,
            ) =>
              target.$transaction(async (tx) =>
                action(
                  new Proxy(tx, {
                    get(inner, field) {
                      if (field === 'auditLog')
                        return {
                          ...inner.auditLog,
                          create: () =>
                            Promise.reject(
                              new Error('Controlled audit sink failure'),
                            ),
                        };
                      return Reflect.get(inner, field) as unknown;
                    },
                  }),
                ),
              );
          return Reflect.get(target, key) as unknown;
        },
      });
      await expect(
        new AdminService(failing).mutate(admin.id, 'users', user.id, {
          status: 'DISABLED',
        }),
      ).rejects.toThrow('Controlled audit sink failure');
      expect(
        await db.user.findUnique({
          where: { id: user.id },
          select: { status: true },
        }),
      ).toEqual({ status: 'ACTIVE' });
      expect(await db.auditLog.count({ where: { targetId: user.id } })).toBe(0);
    } finally {
      await db.user.delete({ where: { id: user.id } });
      await db.adminUser.delete({ where: { id: admin.id } });
    }
  });
});
