import { config as loadDotEnv } from 'dotenv';
import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../src/database/prisma.service';
import { Environment, validateEnvironment } from '../src/config/environment';
import { Prisma } from '../src/generated/prisma/client';

type Tx = Prisma.TransactionClient;
const local = loadDotEnv({ quiet: true });
if (local.error || !local.parsed)
  throw new Error('Local .env required for integration tests');
// Read only the explicitly configured local file, not Jest-injected NODE_ENV.
const config = validateEnvironment(local.parsed);
if (
  config.NODE_ENV !== 'development' ||
  new URL(config.DATABASE_URL).hostname !== '127.0.0.1'
) {
  throw new Error(
    'Integration tests require the loopback development database',
  );
}
const rollbackMarker = new Error('Rollback test fixtures');
const db = new PrismaService(new ConfigService<Environment, true>(config));
async function rollback(work: (tx: Tx) => Promise<void>): Promise<void> {
  try {
    await db.$transaction(async (tx) => {
      await work(tx);
      throw rollbackMarker;
    });
  } catch (error) {
    if (error !== rollbackMarker) throw error;
  }
}
async function fixture(tx: Tx) {
  const id = randomUUID();
  const user = await tx.user.create({
    data: {
      externalAuthId: id,
      email: id + '@fixture.example',
      displayName: 'Fixture',
    },
  });
  const other = await tx.user.create({
    data: {
      externalAuthId: randomUUID(),
      email: randomUUID() + '@fixture.example',
      displayName: 'Other',
    },
  });
  const category = await tx.category.create({
    data: { name: 'Fixture', slug: id },
  });
  const book = await tx.book.create({
    data: {
      title: 'Fixture',
      slug: id,
      description: 'Fixture',
      categoryId: category.id,
      price: 100,
      pageCount: 10,
      previewPageCount: 2,
    },
  });
  const order = await tx.order.create({
    data: { userId: user.id, bookId: book.id, amount: 100 },
  });
  return { user, other, category, book, order };
}

describe('real PostgreSQL schema invariants (rolled back)', () => {
  beforeAll(async () => {
    await db.onModuleInit();
  });
  afterAll(async () => {
    await db.onModuleDestroy();
  });
  it('rejects case-variant duplicate email', async () =>
    rollback(async (tx) => {
      const { user } = await fixture(tx);
      await expect(
        tx.user.create({
          data: {
            externalAuthId: randomUUID(),
            email: user.email.toUpperCase(),
            displayName: 'Duplicate',
          },
        }),
      ).rejects.toMatchObject({ code: 'P2002' });
    }));
  it('rejects reused transaction references across owners/methods/case', async () =>
    rollback(async (tx) => {
      const { user, other, book, order } = await fixture(tx);
      const reference = randomUUID().replaceAll('-', '');
      await tx.payment.create({
        data: {
          orderId: order.id,
          userId: user.id,
          method: 'BKASH',
          transactionReference: reference,
          amount: 100,
        },
      });
      const otherOrder = await tx.order.create({
        data: { userId: other.id, bookId: book.id, amount: 100 },
      });
      await expect(
        tx.payment.create({
          data: {
            orderId: otherOrder.id,
            userId: other.id,
            method: 'NAGAD',
            transactionReference: reference.toUpperCase(),
            amount: 100,
          },
        }),
      ).rejects.toMatchObject({ code: 'P2002' });
    }));
  it('rejects payments assigned to another user order', async () =>
    rollback(async (tx) => {
      const { other, order } = await fixture(tx);
      await expect(
        tx.payment.create({
          data: {
            orderId: order.id,
            userId: other.id,
            method: 'BKASH',
            transactionReference: randomUUID().replaceAll('-', ''),
            amount: 100,
          },
        }),
      ).rejects.toMatchObject({ code: 'P2003' });
    }));
  it('permits only one entitlement per user/book', async () =>
    rollback(async (tx) => {
      const { user, book, order } = await fixture(tx);
      await tx.entitlement.create({
        data: { userId: user.id, bookId: book.id, orderId: order.id },
      });
      const secondOrder = await tx.order.create({
        data: { userId: user.id, bookId: book.id, amount: 100 },
      });
      await expect(
        tx.entitlement.create({
          data: { userId: user.id, bookId: book.id, orderId: secondOrder.id },
        }),
      ).rejects.toMatchObject({ code: 'P2002' });
    }));
  it('rejects entitlements for the wrong purchase owner', async () =>
    rollback(async (tx) => {
      const { other, book, order } = await fixture(tx);
      await expect(
        tx.entitlement.create({
          data: { userId: other.id, bookId: book.id, orderId: order.id },
        }),
      ).rejects.toMatchObject({ code: 'P2003' });
    }));
  it('rejects entitlements for the wrong purchase book', async () =>
    rollback(async (tx) => {
      const { user, category, order } = await fixture(tx);
      const differentBook = await tx.book.create({
        data: {
          title: 'Other',
          slug: randomUUID(),
          description: 'Other',
          categoryId: category.id,
          price: 100,
        },
      });
      await expect(
        tx.entitlement.create({
          data: {
            userId: user.id,
            bookId: differentBook.id,
            orderId: order.id,
          },
        }),
      ).rejects.toMatchObject({ code: 'P2003' });
    }));
  it('defaults new entitlements to inactive until explicitly activated', async () =>
    rollback(async (tx) => {
      const { user, book, order } = await fixture(tx);
      const access = await tx.entitlement.create({
        data: { userId: user.id, bookId: book.id, orderId: order.id },
      });
      expect(access.status).toBe('REVOKED');
    }));
  it('enforces user/book progress uniqueness', async () =>
    rollback(async (tx) => {
      const { user, book } = await fixture(tx);
      await tx.readingProgress.create({
        data: { userId: user.id, bookId: book.id, lastPage: 1 },
      });
      await expect(
        tx.readingProgress.create({
          data: { userId: user.id, bookId: book.id, lastPage: 2 },
        }),
      ).rejects.toMatchObject({ code: 'P2002' });
    }));
  it('rejects zero progress page', async () =>
    rollback(async (tx) => {
      const { user, book } = await fixture(tx);
      await expect(
        tx.readingProgress.create({
          data: { userId: user.id, bookId: book.id, lastPage: 0 },
        }),
      ).rejects.toThrow();
    }));
  it('enforces per-user device identifier uniqueness', async () =>
    rollback(async (tx) => {
      const { user } = await fixture(tx);
      const data = {
        userId: user.id,
        deviceIdentifier: randomUUID(),
        platform: 'ANDROID' as const,
      };
      await tx.device.create({ data });
      await expect(tx.device.create({ data })).rejects.toMatchObject({
        code: 'P2002',
      });
    }));
  it('rejects sessions on another user device', async () =>
    rollback(async (tx) => {
      const { user, other } = await fixture(tx);
      const device = await tx.device.create({
        data: {
          userId: user.id,
          deviceIdentifier: randomUUID(),
          platform: 'ANDROID',
        },
      });
      await expect(
        tx.session.create({
          data: {
            userId: other.id,
            deviceId: device.id,
            tokenHash: 'a'.repeat(64),
            expiresAt: new Date(Date.now() + 60000),
          },
        }),
      ).rejects.toMatchObject({ code: 'P2003' });
    }));
  it('rejects invalid preview page counts', async () =>
    rollback(async (tx) => {
      const { book } = await fixture(tx);
      await expect(
        tx.book.update({
          where: { id: book.id },
          data: { previewPageCount: 11 },
        }),
      ).rejects.toThrow();
    }));
  it('rejects negative book prices', async () =>
    rollback(async (tx) => {
      const { book } = await fixture(tx);
      await expect(
        tx.book.update({ where: { id: book.id }, data: { price: -1 } }),
      ).rejects.toThrow();
    }));
  it('allows at most one approved payment per order', async () =>
    rollback(async (tx) => {
      const { user, order } = await fixture(tx);
      const admin = await tx.adminUser.create({
        data: {
          externalAuthId: randomUUID(),
          email: randomUUID() + '@fixture.example',
          displayName: 'Reviewer',
          role: 'PAYMENT_REVIEWER',
        },
      });
      const data = {
        userId: user.id,
        orderId: order.id,
        method: 'BKASH' as const,
        status: 'APPROVED' as const,
        reviewedById: admin.id,
        reviewedAt: new Date(),
        amount: 100,
      };
      await tx.payment.create({
        data: {
          ...data,
          transactionReference: randomUUID().replaceAll('-', ''),
        },
      });
      await expect(
        tx.payment.create({
          data: {
            ...data,
            transactionReference: randomUUID().replaceAll('-', ''),
          },
        }),
      ).rejects.toMatchObject({ code: 'P2002' });
    }));
  it('rejects mutation of an audit event', async () =>
    rollback(async (tx) => {
      const admin = await tx.adminUser.create({
        data: {
          externalAuthId: randomUUID(),
          email: randomUUID() + '@fixture.example',
          displayName: 'Reviewer',
          role: 'PAYMENT_REVIEWER',
        },
      });
      const log = await tx.auditLog.create({
        data: {
          adminActorId: admin.id,
          action: 'TEST_EVENT',
          targetType: 'Fixture',
          targetId: randomUUID(),
        },
      });
      await expect(
        tx.auditLog.update({
          where: { id: log.id },
          data: { action: 'CHANGED' },
        }),
      ).rejects.toThrow();
    }));

  it('rejects previews when the total page count is unknown', async () =>
    rollback(async (tx) => {
      const { book } = await fixture(tx);
      await expect(
        tx.book.update({
          where: { id: book.id },
          data: { pageCount: null, previewPageCount: 1 },
        }),
      ).rejects.toThrow();
    }));
  it('requires an explicit rejection reason for reviewed payments', async () =>
    rollback(async (tx) => {
      const { user, order } = await fixture(tx);
      const admin = await tx.adminUser.create({
        data: {
          externalAuthId: randomUUID(),
          email: randomUUID() + '@fixture.example',
          displayName: 'Reviewer',
          role: 'PAYMENT_REVIEWER',
        },
      });
      await expect(
        tx.payment.create({
          data: {
            userId: user.id,
            orderId: order.id,
            method: 'BKASH',
            status: 'REJECTED',
            reviewedById: admin.id,
            reviewedAt: new Date(),
            transactionReference: randomUUID().replaceAll('-', ''),
            amount: 100,
          },
        }),
      ).rejects.toThrow();
    }));
});
