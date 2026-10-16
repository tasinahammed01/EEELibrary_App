// Match the unit harness: controlled identities never invoke the real Firebase SDK.
jest.mock('firebase-admin/auth', () => ({
  getAuth: () => {
    throw new Error('Real Firebase Auth is disabled in integration fixtures');
  },
}));
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { Server } from 'node:http';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/config/configure-app';
import { FirebaseService } from '../src/firebase/firebase.service';
import { config as loadDotEnv } from 'dotenv';
import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Environment, validateEnvironment } from '../src/config/environment';
import { PrismaService } from '../src/database/prisma.service';
import { Prisma } from '../src/generated/prisma/client';
import { PurchaseService } from '../src/purchases/purchase.service';
import { EntitlementService } from '../src/purchases/entitlement.service';
import { ManualPaymentOptions } from '../src/purchases/manual-payment-options';
import { PurchasePageDto } from '../src/purchases/purchase.dto';
const local = loadDotEnv({ quiet: true });
if (local.error || !local.parsed)
  throw new Error('Local test configuration required');
const config = validateEnvironment(local.parsed);
if (
  config.NODE_ENV !== 'development' ||
  new URL(config.DATABASE_URL).hostname !== '127.0.0.1'
)
  throw new Error('Loopback development database required');
const db = new PrismaService(new ConfigService<Environment, true>(config));
const options = new ManualPaymentOptions(
  new ConfigService<Environment, true>({
    ...config,
    MANUAL_PAYMENT_DEVELOPMENT_MODE: true,
  }),
);
const service = new PurchaseService(db, new EntitlementService(db), options);
const page = () => new PurchasePageDto();
const marker = new Error('Rollback isolated audit fixtures');
const tag = 'phase4-' + randomUUID();
let owner: string,
  other: string,
  admin: string,
  category: string,
  slug: string,
  freeSlug: string,
  bookId: string;
const ref = () => randomUUID().replaceAll('-', '').toUpperCase();
// Join an outer rollback transaction for real audit-write tests. Immutable audit
// records must never be disabled/deleted just to clean up integration fixtures.
function inTransaction(tx: Prisma.TransactionClient): PrismaService {
  return new Proxy(db, {
    get(_target, key) {
      if (key === 'onModuleInit' || key === 'onModuleDestroy') return undefined;
      if (key === '$transaction')
        return (
          action:
            | ((inner: Prisma.TransactionClient) => Promise<unknown>)
            | Promise<unknown>[],
        ) => (Array.isArray(action) ? Promise.all(action) : action(tx));
      const value: unknown = Reflect.get(tx, key);
      return value;
    },
  });
}
async function rollback(
  action: (
    purchases: PurchaseService,
    tx: Prisma.TransactionClient,
  ) => Promise<void>,
) {
  try {
    await db.$transaction(
      async (tx) => {
        const joined = inTransaction(tx);
        await action(
          new PurchaseService(joined, new EntitlementService(joined), options),
          tx,
        );
        throw marker;
      },
      { timeout: 15000 },
    );
  } catch (error) {
    if (error !== marker) throw error;
  }
}
async function submitted() {
  const order = await service.create(owner, slug);
  await service.submit(owner, order.id, { method: 'BKASH', reference: ref() });
  return {
    order,
    payment: await db.payment.findFirstOrThrow({
      where: { orderId: order.id, status: 'PENDING' },
    }),
  };
}
beforeAll(async () => {
  await db.onModuleInit();
});
beforeEach(async () => {
  const suffix = randomUUID();
  slug = tag + '-' + suffix;
  freeSlug = slug + '-free';
  const first = await db.user.create({
    data: {
      externalAuthId: slug,
      email: slug + '@fixture.example',
      displayName: 'Phase4 Fixture',
    },
  });
  owner = first.id;
  other = (
    await db.user.create({
      data: {
        externalAuthId: slug + '-other',
        email: slug + '-other@fixture.example',
        displayName: 'Other Fixture',
      },
    })
  ).id;
  admin = (
    await db.adminUser.create({
      data: {
        externalAuthId: slug + '-admin',
        email: slug + '-admin@fixture.example',
        displayName: 'Review Fixture',
        role: 'PAYMENT_REVIEWER',
      },
    })
  ).id;
  category = (
    await db.category.create({ data: { slug, name: 'Phase4 fixture' } })
  ).id;
  bookId = (
    await db.book.create({
      data: {
        slug,
        title: 'Paid fixture',
        description: 'Fixture',
        price: 125,
        categoryId: category,
        status: 'PUBLISHED',
        coverObjectKey: 'private/never-return.pdf',
      },
    })
  ).id;
  await db.book.create({
    data: {
      slug: freeSlug,
      title: 'Free fixture',
      description: 'Fixture',
      price: 0,
      categoryId: category,
      status: 'PUBLISHED',
    },
  });
});
afterEach(async () => {
  if (owner && other) {
    await db.entitlement.deleteMany({
      where: { userId: { in: [owner, other] } },
    });
    await db.payment.deleteMany({ where: { userId: { in: [owner, other] } } });
    await db.order.deleteMany({ where: { userId: { in: [owner, other] } } });
    await db.user.deleteMany({
      where: {
        id: { in: [owner, other] },
        externalAuthId: { startsWith: tag },
      },
    });
  }
  if (category) {
    await db.book.deleteMany({
      where: { categoryId: category, slug: { startsWith: tag } },
    });
    await db.category.deleteMany({
      where: { id: category, slug: { startsWith: tag } },
    });
  }
  if (admin)
    await db.adminUser.deleteMany({
      where: { id: admin, externalAuthId: { startsWith: tag } },
    });
});
afterAll(async () => {
  await db.onModuleDestroy();
});
it('creates a server-priced order and returns only safe metadata', async () => {
  const order = await service.create(owner, slug);
  expect(order.amount.toString()).toBe('125');
  expect(order.status).toBe('PENDING_PAYMENT');
  for (const key of [
    'userId',
    'bookId',
    'externalAuthId',
    'coverObjectKey',
    'reviewedById',
  ])
    expect(JSON.stringify(order)).not.toContain(key);
});
it('keeps the original snapshot after book price changes', async () => {
  const first = await service.create(owner, slug);
  await db.book.update({ where: { id: bookId }, data: { price: 999 } });
  const next = await service.create(owner, slug);
  expect(next.id).toBe(first.id);
  expect(next.amount.toString()).toBe('125');
  await service.submit(owner, next.id, { method: 'BKASH', reference: ref() });
  expect(
    (
      await db.payment.findFirstOrThrow({ where: { orderId: next.id } })
    ).amount.toString(),
  ).toBe('125');
});
it('serializes eight concurrent create requests to one pending order', async () => {
  const orders = await Promise.all(
    Array.from({ length: 8 }, () => service.create(owner, slug)),
  );
  expect(new Set(orders.map((o) => o.id)).size).toBe(1);
  expect(await db.order.count({ where: { userId: owner } })).toBe(1);
});
it.each(['DRAFT', 'ARCHIVED'] as const)(
  'rejects %s catalog content',
  async (status) => {
    await db.book.update({ where: { id: bookId }, data: { status } });
    await expect(service.create(owner, slug)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  },
);
it('rejects inactive category and missing book', async () => {
  await db.category.update({
    where: { id: category },
    data: { isActive: false },
  });
  await expect(service.create(owner, slug)).rejects.toBeInstanceOf(
    NotFoundException,
  );
  await expect(service.create(owner, slug + '-missing')).rejects.toBeInstanceOf(
    NotFoundException,
  );
});
it('revalidates ACTIVE owners inside mutations', async () => {
  await db.user.update({ where: { id: owner }, data: { status: 'SUSPENDED' } });
  await expect(service.create(owner, slug)).rejects.toBeInstanceOf(
    ForbiddenException,
  );
});
it('fails paid creation closed without configured methods but permits free', async () => {
  const unavailable = new PurchaseService(
    db,
    new EntitlementService(db),
    new ManualPaymentOptions(
      new ConfigService<Environment, true>({
        ...config,
        MANUAL_PAYMENT_DEVELOPMENT_MODE: false,
        MANUAL_PAYMENT_BKASH_INSTRUCTIONS: undefined,
        MANUAL_PAYMENT_NAGAD_INSTRUCTIONS: undefined,
      }),
    ),
  );
  await expect(unavailable.create(owner, slug)).rejects.toMatchObject({
    status: 503,
  });
  expect((await unavailable.create(owner, freeSlug)).status).toBe('COMPLETED');
});
it('acquires free resources concurrently without payments or duplicates', async () => {
  const orders = await Promise.all(
    Array.from({ length: 8 }, () => service.create(owner, freeSlug)),
  );
  expect(new Set(orders.map((o) => o.id)).size).toBe(1);
  expect(await db.entitlement.count({ where: { userId: owner } })).toBe(1);
  expect(await db.payment.count({ where: { userId: owner } })).toBe(0);
  expect((await service.access(owner, freeSlug)).owned).toBe(true);
});
it('returns the existing owned order instead of making another payable order', async () => {
  const free = await service.create(owner, freeSlug);
  expect((await service.create(owner, freeSlug)).id).toBe(free.id);
});
it('does not bypass a revoked entitlement with repeat free acquisition', async () => {
  await service.create(owner, freeSlug);
  await db.entitlement.updateMany({
    where: { userId: owner },
    data: { status: 'REVOKED', revokedAt: new Date() },
  });
  await expect(service.create(owner, freeSlug)).rejects.toBeInstanceOf(
    ForbiddenException,
  );
  expect((await service.access(owner, freeSlug)).owned).toBe(false);
});
it('submits once under concurrent retries and does not grant access', async () => {
  const order = await service.create(owner, slug);
  const input = { method: 'BKASH' as const, reference: ref() };
  await Promise.all(
    Array.from({ length: 6 }, () => service.submit(owner, order.id, input)),
  );
  expect(await db.payment.count({ where: { orderId: order.id } })).toBe(1);
  expect((await service.get(owner, order.id)).status).toBe('PAYMENT_SUBMITTED');
  expect((await service.access(owner, slug)).owned).toBe(false);
  expect(
    (await new EntitlementService(db).library(owner, page())).items,
  ).toHaveLength(0);
});
it('rejects a second different pending reference', async () => {
  const { order } = await submitted();
  await expect(
    service.submit(owner, order.id, { method: 'BKASH', reference: ref() }),
  ).rejects.toBeInstanceOf(ConflictException);
});
it('rejects globally reused references across owners, methods and case', async () => {
  const first = await service.create(owner, slug);
  const reference = ref();
  await service.submit(owner, first.id, { method: 'BKASH', reference });
  const second = await service.create(other, slug);
  await expect(
    service.submit(other, second.id, {
      method: 'NAGAD',
      reference: reference.toLowerCase(),
    }),
  ).rejects.toBeInstanceOf(ConflictException);
});
it('scopes order reads/submissions/listing to the authenticated owner', async () => {
  const order = await service.create(owner, slug);
  await expect(service.get(other, order.id)).rejects.toBeInstanceOf(
    NotFoundException,
  );
  await expect(
    service.submit(other, order.id, { method: 'BKASH', reference: ref() }),
  ).rejects.toBeInstanceOf(NotFoundException);
  expect((await service.list(other, page())).items).toHaveLength(0);
});
it('rejects payment after cancellation without changing its price', async () => {
  const order = await service.create(owner, slug);
  await db.order.update({
    where: { id: order.id },
    data: { status: 'CANCELLED' },
  });
  await expect(
    service.submit(owner, order.id, { method: 'BKASH', reference: ref() }),
  ).rejects.toBeInstanceOf(ConflictException);
});
it('approves atomically, creates entitlement once and writes two real audit records', async () => {
  const { order, payment } = await submitted();
  await rollback(async (purchases, tx) => {
    await purchases.review(admin, payment.id, 'APPROVED');
    await purchases.review(admin, payment.id, 'APPROVED');
    expect(
      (await tx.order.findUniqueOrThrow({ where: { id: order.id } })).status,
    ).toBe('COMPLETED');
    expect(
      await tx.entitlement.count({
        where: { orderId: order.id, status: 'ACTIVE' },
      }),
    ).toBe(1);
    const audits = await tx.auditLog.findMany({
      where: { adminActorId: admin },
    });
    expect(audits.map((a) => a.action).sort()).toEqual([
      'ENTITLEMENT_GRANTED',
      'PAYMENT_APPROVED',
    ]);
    expect(JSON.stringify(audits)).not.toContain(payment.transactionReference);
  });
  expect(await db.entitlement.count({ where: { orderId: order.id } })).toBe(0);
});
it('rejects safely, permits a new reference on the same snapshot and audits once', async () => {
  const { order, payment } = await submitted();
  await rollback(async (purchases, tx) => {
    await purchases.review(
      admin,
      payment.id,
      'REJECTED',
      'REFERENCE_NOT_FOUND',
    );
    await purchases.review(
      admin,
      payment.id,
      'REJECTED',
      'REFERENCE_NOT_FOUND',
    );
    expect((await purchases.get(owner, order.id)).status).toBe(
      'PENDING_PAYMENT',
    );
    expect(await tx.entitlement.count({ where: { userId: owner } })).toBe(0);
    expect(
      await tx.auditLog.count({
        where: { adminActorId: admin, action: 'PAYMENT_REJECTED' },
      }),
    ).toBe(1);
    await expect(
      purchases.submit(owner, order.id, {
        method: 'BKASH',
        reference: payment.transactionReference,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    await purchases.submit(owner, order.id, {
      method: 'NAGAD',
      reference: ref(),
    });
    expect(await tx.payment.count({ where: { orderId: order.id } })).toBe(2);
  });
});
it('denies disabled and content-only reviewers inside approval', async () => {
  const { payment } = await submitted();
  await db.adminUser.update({
    where: { id: admin },
    data: { status: 'DISABLED' },
  });
  await expect(
    service.review(admin, payment.id, 'APPROVED'),
  ).rejects.toBeInstanceOf(ForbiddenException);
  await db.adminUser.update({
    where: { id: admin },
    data: { status: 'ACTIVE', role: 'CONTENT_MANAGER' },
  });
  await expect(
    service.review(admin, payment.id, 'APPROVED'),
  ).rejects.toBeInstanceOf(ForbiddenException);
});
it('cannot approve after an existing conflicting entitlement', async () => {
  const { order, payment } = await submitted();
  const another = await db.order.create({
    data: { userId: owner, bookId, amount: 125, status: 'COMPLETED' },
  });
  await db.entitlement.create({
    data: { userId: owner, bookId, orderId: another.id, status: 'ACTIVE' },
  });
  await expect(
    service.review(admin, payment.id, 'APPROVED'),
  ).rejects.toBeInstanceOf(ConflictException);
  expect((await service.get(owner, order.id)).status).toBe('PAYMENT_SUBMITTED');
});
it('library is entitlement-backed, bounded and private-field free', async () => {
  await service.create(owner, freeSlug);
  await service.create(owner, slug);
  const library = await new EntitlementService(db).library(owner, page());
  expect(library.items.map((b) => b.slug)).toEqual([freeSlug]);
  expect(JSON.stringify(library)).not.toMatch(
    /orderId|userId|coverObjectKey|externalAuthId/,
  );
  expect(
    (await new EntitlementService(db).library(other, page())).items,
  ).toHaveLength(0);
});
it('serializes real concurrent approvals; immutable audit sink separately tested with rollback', async () => {
  const { order, payment } = await submitted();
  const writes: unknown[] = [];
  // Only the audit sink is replaced for this committed concurrency scenario.
  // Real audit writes/atomicity are tested above in rollback transactions.
  const proxy = new Proxy(db, {
    get(target, key) {
      if (key === '$transaction')
        return (action: (tx: Prisma.TransactionClient) => Promise<unknown>) =>
          target.$transaction(
            (tx) =>
              action(
                new Proxy(tx, {
                  get(inner, property) {
                    if (property === 'auditLog')
                      return {
                        create: (input: unknown) => {
                          writes.push(input);
                          return Promise.resolve({});
                        },
                      };
                    const value: unknown = Reflect.get(inner, property);
                    return value;
                  },
                }),
              ),
            { maxWait: 10000, timeout: 10000 },
          );
      const value: unknown = Reflect.get(target, key);
      return value;
    },
  });
  const concurrent = new PurchaseService(
    proxy,
    new EntitlementService(proxy),
    options,
  );
  await Promise.all(
    Array.from({ length: 6 }, () =>
      concurrent.review(admin, payment.id, 'APPROVED'),
    ),
  );
  expect(await db.entitlement.count({ where: { orderId: order.id } })).toBe(1);
  expect(writes).toHaveLength(2);
});
it('rolls every approval mutation back when the audit writer fails', async () => {
  const { order, payment } = await submitted();
  const failing = new Proxy(db, {
    get(target, key) {
      if (key === '$transaction')
        return (action: (tx: Prisma.TransactionClient) => Promise<unknown>) =>
          target.$transaction((tx) =>
            action(
              new Proxy(tx, {
                get(inner, property) {
                  if (property === 'auditLog')
                    return {
                      create: () =>
                        Promise.reject(new Error('Controlled audit failure')),
                    };
                  const value: unknown = Reflect.get(inner, property);
                  return value;
                },
              }),
            ),
          );
      const value: unknown = Reflect.get(target, key);
      return value;
    },
  });
  await expect(
    new PurchaseService(
      failing,
      new EntitlementService(failing),
      options,
    ).review(admin, payment.id, 'APPROVED'),
  ).rejects.toThrow('Controlled audit failure');
  expect((await service.get(owner, order.id)).status).toBe('PAYMENT_SUBMITTED');
  expect(
    (await db.payment.findUniqueOrThrow({ where: { id: payment.id } })).status,
  ).toBe('PENDING');
  expect(await db.entitlement.count({ where: { orderId: order.id } })).toBe(0);
});
it('a concurrent reference collision commits only one payment and returns safe conflict', async () => {
  const first = await service.create(owner, slug),
    second = await service.create(other, slug);
  const reference = ref();
  const results = await Promise.allSettled([
    service.submit(owner, first.id, { method: 'BKASH', reference }),
    service.submit(other, second.id, { method: 'NAGAD', reference }),
  ]);
  expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
  const failed = results.find((r) => r.status === 'rejected');
  if (failed?.status === 'rejected')
    expect(failed.reason).toBeInstanceOf(ConflictException);
  expect(
    await db.payment.count({ where: { transactionReference: reference } }),
  ).toBe(1);
});
it('does not treat an inconsistent ACTIVE entitlement on an unpaid order as valid access', async () => {
  const order = await service.create(owner, slug);
  await db.entitlement.create({
    data: { userId: owner, bookId, orderId: order.id, status: 'ACTIVE' },
  });
  expect((await service.access(owner, slug)).owned).toBe(false);
  expect(
    (await new EntitlementService(db).library(owner, page())).items,
  ).toHaveLength(0);
  await expect(service.create(owner, slug)).rejects.toBeInstanceOf(
    ForbiddenException,
  );
});
it('paid ownership remains idempotent after approval', async () => {
  const { order, payment } = await submitted();
  await rollback(async (purchases, tx) => {
    await purchases.review(admin, payment.id, 'APPROVED');
    expect((await purchases.create(owner, slug)).id).toBe(order.id);
    expect((await purchases.access(owner, slug)).owned).toBe(true);
    expect(await tx.order.count({ where: { userId: owner } })).toBe(1);
  });
});
it('controlled HTTP smoke exercises guards, reference review and Library with a full rollback', async () => {
  await rollback(async (_purchases, tx) => {
    const joined = inTransaction(tx);
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(joined)
      .overrideProvider(ManualPaymentOptions)
      .useValue(options)
      .overrideProvider(FirebaseService)
      .useValue({
        verifyIdToken: (token: string) =>
          Promise.resolve({
            firebaseUid: token === 'fixture-admin' ? slug + '-admin' : slug,
            email: 'fixture@fixture.example',
            displayName: 'Fixture',
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
        .post('/api/v1/orders')
        .send({ bookSlug: slug })
        .expect(401);
      const created = await request(server)
        .post('/api/v1/orders')
        .set('Authorization', 'Bearer fixture-owner')
        .send({ bookSlug: slug })
        .expect(200);
      const order = created.body as { id: string };
      await request(server)
        .post('/api/v1/orders/' + order.id + '/payment')
        .set('Authorization', 'Bearer fixture-owner')
        .send({ method: 'BKASH', reference: ref() })
        .expect(200);
      await request(server)
        .get('/api/v1/admin/payments')
        .set('Authorization', 'Bearer fixture-owner')
        .expect(403);
      const payment = await tx.payment.findFirstOrThrow({
        where: { orderId: order.id },
      });
      await request(server)
        .post('/api/v1/admin/payments/' + payment.id + '/approve')
        .set('Authorization', 'Bearer fixture-admin')
        .send({})
        .expect(200);
      const library = await request(server)
        .get('/api/v1/library')
        .set('Authorization', 'Bearer fixture-owner')
        .expect(200);
      const data = library.body as { items: { slug: string }[] };
      expect(data.items.map((b) => b.slug)).toEqual([slug]);
      expect(await tx.auditLog.count({ where: { adminActorId: admin } })).toBe(
        2,
      );
    } finally {
      await app.close();
    }
  });
});
it('does not leak arbitrary legacy rejection notes through user-facing endpoints', async () => {
  const { order, payment } = await submitted();
  await db.payment.update({
    where: { id: payment.id },
    data: {
      status: 'REJECTED',
      reviewedAt: new Date(),
      reviewedById: admin,
      rejectionReason: 'private internal reviewer note',
    },
  });
  await db.order.update({
    where: { id: order.id },
    data: { status: 'PENDING_PAYMENT' },
  });
  const result = [
    await service.get(owner, order.id),
    await service.list(owner, page()),
    await service.access(owner, slug),
  ];
  expect(JSON.stringify(result)).not.toContain(
    'private internal reviewer note',
  );
});
it('a now-free book replaces an unpaid quote without mutating its price or making a payment', async () => {
  const old = await service.create(owner, slug);
  await db.book.update({ where: { id: bookId }, data: { price: 0 } });
  const acquired = await service.create(owner, slug);
  expect(acquired.status).toBe('COMPLETED');
  expect(acquired.amount.toString()).toBe('0');
  expect(acquired.id).not.toBe(old.id);
  const quote = await service.get(owner, old.id);
  expect(quote.status).toBe('CANCELLED');
  expect(quote.amount.toString()).toBe('125');
  expect(await db.payment.count({ where: { userId: owner } })).toBe(0);
  expect((await service.access(owner, slug)).owned).toBe(true);
});
it('submitted paid quotes are preserved for review when catalog pricing changes to free', async () => {
  const { order } = await submitted();
  await db.book.update({ where: { id: bookId }, data: { price: 0 } });
  const result = await service.create(owner, slug);
  expect(result.id).toBe(order.id);
  expect(result.status).toBe('PAYMENT_SUBMITTED');
  expect((await service.access(owner, slug)).owned).toBe(false);
});
