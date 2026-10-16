import { config as loadDotEnv } from 'dotenv';
import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { Environment, validateEnvironment } from '../src/config/environment';
import { PrismaService } from '../src/database/prisma.service';
import { CatalogService } from '../src/catalog/catalog.service';
import { CatalogQueryDto } from '../src/catalog/catalog-query.dto';
const local = loadDotEnv({ quiet: true });
if (local.error || !local.parsed)
  throw new Error('Local integration configuration required');
const config = validateEnvironment(local.parsed);
if (
  config.NODE_ENV !== 'development' ||
  new URL(config.DATABASE_URL).hostname !== '127.0.0.1'
)
  throw new Error('Loopback development database required');
const db = new PrismaService(new ConfigService<Environment, true>(config));
const service = new CatalogService(db);
const tag = 'catalog-fixture-' + randomUUID();
let categoryId: string;
const query = (options: Partial<CatalogQueryDto> = {}) =>
  Object.assign(new CatalogQueryDto(), { category: tag }, options);
beforeAll(async () => {
  await db.onModuleInit();
  const category = await db.category.create({ data: { slug: tag, name: tag } });
  categoryId = category.id;
  await db.book.createMany({
    data: [
      {
        slug: tag + '-a',
        title: 'Alpha Circuit ' + tag,
        description: 'Fixture',
        categoryId,
        price: 10,
        status: 'PUBLISHED',
        coverObjectKey: 'private/never-expose.pdf',
      },
      {
        slug: tag + '-b',
        title: 'Beta Circuit ' + tag,
        description: 'Fixture',
        categoryId,
        price: 20,
        status: 'PUBLISHED',
      },
      {
        slug: tag + '-draft',
        title: 'Draft ' + tag,
        description: 'Fixture',
        categoryId,
        price: 1,
        status: 'DRAFT',
      },
      {
        slug: tag + '-archived',
        title: 'Archived ' + tag,
        description: 'Fixture',
        categoryId,
        price: 1,
        status: 'ARCHIVED',
      },
    ],
  });
});
afterAll(async () => {
  if (categoryId) {
    await db.book.deleteMany({
      where: { categoryId, slug: { startsWith: tag } },
    });
    await db.category.delete({ where: { id: categoryId } });
  }
  await db.onModuleDestroy();
});
it('lists only published books with matching count', async () => {
  const result = await service.books(query());
  expect(result.total).toBe(2);
  expect(result.items).toHaveLength(2);
  expect(result.hasMore).toBe(false);
});
it('pages without duplicates and reports more accurately', async () => {
  const first = await service.books(query({ pageSize: 1, sort: 'title' })),
    second = await service.books(
      query({ pageSize: 1, page: 2, sort: 'title' }),
    );
  expect(first.hasMore).toBe(true);
  expect(second.hasMore).toBe(false);
  expect(first.items[0]?.slug).not.toBe(second.items[0]?.slug);
});
it('searches title case-insensitively', async () => {
  expect(
    (await service.books(query({ search: 'alpha circuit' }))).items.map(
      (b) => b.slug,
    ),
  ).toEqual([tag + '-a']);
});
it('returns empty search and unknown category safely', async () => {
  expect(
    (await service.books(query({ search: 'unmatchedfixture' }))).total,
  ).toBe(0);
  expect(
    (await service.books(query({ category: tag + '-missing' }))).total,
  ).toBe(0);
});
it('sorts decimal prices numerically', async () => {
  expect(
    (await service.books(query({ sort: 'price-desc' }))).items.map((b) =>
      b.price.toString(),
    ),
  ).toEqual(['20', '10']);
});
it('serializes public details without storage keys or status', async () => {
  const book = await service.book(tag + '-a');
  const json = JSON.stringify(book);
  expect(json).not.toContain('private/');
  expect(json).not.toContain('coverObjectKey');
  expect(json).not.toContain('PUBLISHED');
  expect(book.price.toString()).toBe('10');
});
it.each(['draft', 'archived', 'missing'])(
  'does not disclose %s details',
  async (suffix) => {
    await expect(service.book(tag + '-' + suffix)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  },
);
it('hides inactive categories and all of their books', async () => {
  await db.category.update({
    where: { id: categoryId },
    data: { isActive: false },
  });
  try {
    expect((await service.categories()).some((c) => c.id === categoryId)).toBe(
      false,
    );
    expect((await service.books(query())).total).toBe(0);
    await expect(service.book(tag + '-a')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  } finally {
    await db.category.update({
      where: { id: categoryId },
      data: { isActive: true },
    });
  }
});
