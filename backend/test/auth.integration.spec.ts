import { config as loadDotEnv } from 'dotenv';
import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { AuthService } from '../src/auth/auth.service';
import { VerifiedIdentity } from '../src/auth/auth.types';
import { Environment, validateEnvironment } from '../src/config/environment';
import { PrismaService } from '../src/database/prisma.service';

const local = loadDotEnv({ quiet: true });
if (local.error || !local.parsed)
  throw new Error('Local .env required for integration tests');
const config = validateEnvironment(local.parsed);
if (
  config.NODE_ENV !== 'development' ||
  new URL(config.DATABASE_URL).hostname !== '127.0.0.1'
)
  throw new Error(
    'Integration tests require the loopback development database',
  );
const db = new PrismaService(new ConfigService<Environment, true>(config));
const auth = new AuthService(db);
const fixtureUids = new Set<string>();
function identity(email?: string): VerifiedIdentity {
  const firebaseUid = 'phase2-test-' + randomUUID();
  fixtureUids.add(firebaseUid);
  return {
    firebaseUid,
    email: email ?? firebaseUid + '@fixture.example',
    displayName: 'Fixture Reader',
  };
}

describe('auth bootstrap with real PostgreSQL concurrency', () => {
  beforeAll(async () => {
    await db.onModuleInit();
  });
  afterEach(async () => {
    // Delete ONLY UUID-tagged users created by this suite; never reset/truncate.
    await db.user.deleteMany({
      where: { externalAuthId: { in: [...fixtureUids] } },
    });
    fixtureUids.clear();
  });
  afterAll(async () => {
    await db.onModuleDestroy();
  });
  it('deduplicates eight truly concurrent requests across pooled connections', async () => {
    const verified = identity();
    const users = await Promise.all(
      Array.from({ length: 8 }, () => auth.bootstrap(verified)),
    );
    expect(new Set(users.map((user) => user.id)).size).toBe(1);
    expect(
      await db.user.count({ where: { externalAuthId: verified.firebaseUid } }),
    ).toBe(1);
  });
  it('reuses the UID link without overwriting existing identity metadata', async () => {
    const verified = identity();
    const first = await auth.bootstrap(verified);
    const changed = await db.user.update({
      where: { id: first.id },
      data: { displayName: 'Existing Profile' },
    });
    const second = await auth.bootstrap({
      ...verified,
      displayName: 'Stale Claim',
      email: identity().email,
    });
    expect(second).toEqual({
      id: changed.id,
      email: changed.email,
      displayName: changed.displayName,
      status: changed.status,
      createdAt: changed.createdAt,
    });
  });
  it('rejects an email collision without relinking the original account', async () => {
    const original = identity();
    const user = await auth.bootstrap(original);
    const different = identity(original.email.toUpperCase());
    await expect(auth.bootstrap(different)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(
      await db.user.findUnique({
        where: { externalAuthId: different.firebaseUid },
      }),
    ).toBeNull();
    expect(
      (await db.user.findUniqueOrThrow({ where: { id: user.id } }))
        .externalAuthId,
    ).toBe(original.firebaseUid);
  });
  it.each(['DISABLED', 'SUSPENDED'] as const)(
    'cannot reactivate %s users on either path',
    async (status) => {
      const verified = identity();
      const user = await auth.bootstrap(verified);
      await db.user.update({ where: { id: user.id }, data: { status } });
      await expect(auth.bootstrap(verified)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      await expect(auth.getCurrentUser(verified)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      expect(
        (await db.user.findUniqueOrThrow({ where: { id: user.id } })).status,
      ).toBe(status);
    },
  );
  it('requires explicit bootstrap before me and never creates on lookup', async () => {
    const verified = identity();
    await expect(auth.getCurrentUser(verified)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(
      await db.user.count({ where: { externalAuthId: verified.firebaseUid } }),
    ).toBe(0);
  });
});
