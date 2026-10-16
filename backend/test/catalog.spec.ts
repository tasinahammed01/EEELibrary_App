import { INestApplication, NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { Server } from 'node:http';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/config/configure-app';
import { PrismaService } from '../src/database/prisma.service';
import {
  CatalogService,
  publicBookSelect,
  publicBookSummarySelect,
} from '../src/catalog/catalog.service';
import { CatalogQueryDto } from '../src/catalog/catalog-query.dto';

describe('public catalog HTTP validation', () => {
  let app: INestApplication;
  let server: Server;
  const catalog = {
    categories: jest.fn().mockResolvedValue([]),
    books: jest.fn().mockResolvedValue({
      items: [],
      total: 0,
      page: 1,
      pageSize: 12,
      hasMore: false,
    }),
    book: jest.fn().mockRejectedValue(new NotFoundException()),
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({})
      .overrideProvider(CatalogService)
      .useValue(catalog)
      .compile();
    app = module.createNestApplication({ bodyParser: false, logger: false });
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
  });
  afterAll(async () => {
    await app.close();
  });
  it('categories are available without credentials', async () => {
    await request(server).get('/api/v1/categories').expect(200, []);
  });
  it('defaults to bounded pagination', async () => {
    await request(server).get('/api/v1/books').expect(200);
    expect(catalog.books).toHaveBeenLastCalledWith(
      expect.objectContaining({ page: 1, pageSize: 12, sort: 'newest' }),
    );
  });
  it('normalizes search and forwards category and sort', async () => {
    await request(server)
      .get('/api/v1/books')
      .query({
        page: '2',
        pageSize: '40',
        search: '  Circuit   Theory ',
        category: 'circuit-theory',
        sort: 'price-asc',
      })
      .expect(200);
    expect(catalog.books).toHaveBeenLastCalledWith(
      expect.objectContaining({
        page: 2,
        pageSize: 40,
        search: 'Circuit Theory',
        category: 'circuit-theory',
        sort: 'price-asc',
      }),
    );
  });
  it.each([
    { page: 0 },
    { page: -1 },
    { page: 10001 },
    { page: '1.5' },
    { page: 'abc' },
    { page: ['1', '2'] },
    { pageSize: 41 },
    { pageSize: 0 },
    { search: 'x'.repeat(121) },
    { category: 'bad/value' },
    { sort: 'featured' },
    { extra: 'private' },
  ])('rejects invalid queries %j', async (query) => {
    await request(server).get('/api/v1/books').query(query).expect(400);
  });
  it('missing books have a safe 404', async () => {
    await request(server)
      .get('/api/v1/books/missing-book')
      .expect(404, { statusCode: 404, message: 'Not Found' });
  });
  it('invalid slugs are rejected before database access', async () => {
    await request(server).get('/api/v1/books/Bad_Slug').expect(400);
  });
});
describe('catalog query construction', () => {
  const db = {
    category: { findMany: jest.fn().mockResolvedValue([]) },
    book: {
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      findFirst: jest.fn().mockResolvedValue(null),
    },
    $transaction: jest.fn(async (values: Promise<unknown>[]) =>
      Promise.all(values),
    ),
  };
  const service = new CatalogService(db as unknown as PrismaService);
  it('explicitly excludes all private fields', () => {
    expect(Object.keys(publicBookSelect).sort()).toEqual([
      'category',
      'createdAt',
      'currency',
      'description',
      'id',
      'pageCount',
      'price',
      'slug',
      'title',
    ]);
  });
  it('categories include only active metadata in stable order', async () => {
    await service.categories();
    expect(db.category.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }, { id: 'asc' }],
      }),
    );
  });
  it.each(['newest', 'title', 'price-asc', 'price-desc'] as const)(
    'published books only, bounded and stable: %s',
    async (sort) => {
      const q = Object.assign(new CatalogQueryDto(), {
        page: 2,
        pageSize: 10,
        category: 'circuit',
        search: 'Theory',
        sort,
      });
      await service.books(q);
      expect(db.book.findMany).toHaveBeenLastCalledWith(
        expect.objectContaining({
          skip: 10,
          take: 10,
          select: publicBookSummarySelect,
          where: {
            status: 'PUBLISHED',
            category: { isActive: true, slug: 'circuit' },
            title: { contains: 'Theory', mode: 'insensitive' },
          },
          orderBy:
            sort === 'title'
              ? [{ title: 'asc' }, { id: 'asc' }]
              : sort === 'price-asc'
                ? [{ price: 'asc' }, { id: 'asc' }]
                : sort === 'price-desc'
                  ? [{ price: 'desc' }, { id: 'asc' }]
                  : [{ createdAt: 'desc' }, { id: 'asc' }],
        }),
      );
    },
  );
  it('details fail closed for missing or hidden books', async () => {
    await expect(service.book('hidden')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(db.book.findFirst).toHaveBeenLastCalledWith({
      where: {
        slug: 'hidden',
        status: 'PUBLISHED',
        category: { isActive: true },
      },
      select: publicBookSelect,
    });
  });
});
