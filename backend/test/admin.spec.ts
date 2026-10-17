import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Server } from 'node:http';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/config/configure-app';
import { FirebaseService } from '../src/firebase/firebase.service';
import { PrismaService } from '../src/database/prisma.service';
import { AdminService, slugFor } from '../src/admin/admin.service';
import { AdminRole } from '../src/generated/prisma/enums';
import { BookDto, BookPatch, CategoryDto } from '../src/admin/admin.dto';
import { parseOperatorArgs } from '../src/admin/provision';
const id = randomUUID();
describe('admin HTTP security and validation', () => {
  let app: INestApplication, server: Server;
  const verify = jest.fn(),
    findAdmin = jest.fn();
  const service = {
    dashboard: jest.fn(),
    list: jest.fn(),
    detail: jest.fn(),
    mutate: jest.fn(),
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(FirebaseService)
      .useValue({ verifyIdToken: verify })
      .overrideProvider(PrismaService)
      .useValue({ adminUser: { findUnique: findAdmin } })
      .overrideProvider(AdminService)
      .useValue(service)
      .compile();
    app = module.createNestApplication({ bodyParser: false, logger: false });
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
  });
  afterAll(async () => {
    await app.close();
  });
  beforeEach(() => {
    verify.mockResolvedValue({
      firebaseUid: 'trusted',
      email: 'admin@example.test',
      displayName: 'Admin',
    });
    findAdmin.mockResolvedValue({
      id,
      role: 'SUPER_ADMIN',
      status: 'ACTIVE',
      displayName: 'Admin',
      email: 'admin@example.test',
    });
    for (const fn of Object.values(service))
      fn.mockReset().mockResolvedValue({
        items: [],
        page: 1,
        pageSize: 12,
        total: 0,
        hasMore: false,
      });
  });
  const routes = [
    'me',
    'dashboard',
    'books',
    'categories',
    'users',
    'orders',
    'entitlements',
    'audit',
  ];
  it.each(routes)('guest cannot access %s', async (route) => {
    await request(server)
      .get('/api/v1/admin/' + route)
      .expect(401)
      .expect('Cache-Control', 'no-store');
  });
  it.each([null, { id, role: 'SUPER_ADMIN', status: 'DISABLED' }])(
    'ordinary or inactive admin denied',
    async (admin) => {
      findAdmin.mockResolvedValue(admin);
      await request(server)
        .get('/api/v1/admin/me')
        .set('Authorization', 'Bearer fixture')
        .expect(403);
    },
  );
  it('ordinary user cannot forge an administrator role in browser headers or query', async () => {
    findAdmin.mockResolvedValue(null);
    await request(server)
      .get('/api/v1/admin/me?role=SUPER_ADMIN')
      .set('Authorization', 'Bearer fixture')
      .set('X-Admin', 'true')
      .set('X-Admin-Role', 'SUPER_ADMIN')
      .expect(403);
  });
  it('me projects persisted identity and ignores forged role header', async () => {
    const res = await request(server)
      .get('/api/v1/admin/me')
      .set('Authorization', 'Bearer fixture')
      .set('X-Admin', 'true')
      .expect(200);
    expect((res.body as { role: string }).role).toBe('SUPER_ADMIN');
    expect(findAdmin).toHaveBeenCalledWith(
      expect.objectContaining({ where: { externalAuthId: 'trusted' } }),
    );
  });
  const matrix: Record<AdminRole, string[]> = {
    SUPER_ADMIN: routes,
    CONTENT_MANAGER: ['me', 'dashboard', 'books', 'categories'],
    PAYMENT_REVIEWER: ['me', 'dashboard', 'orders'],
  };
  for (const role of Object.values(AdminRole))
    it.each(routes)(
      role + ' route %s is authorized by backend',
      async (route) => {
        findAdmin.mockResolvedValue({ id, role, status: 'ACTIVE' });
        await request(server)
          .get('/api/v1/admin/' + route)
          .set('Authorization', 'Bearer fixture')
          .expect(matrix[role].includes(route) ? 200 : 403);
      },
    );
  it.each([
    '?pageSize=41',
    '?page=0',
    '?page=-1',
    '?page=1.5',
    '?search[bad]=x',
    '?admin=true',
    '?status=BOGUS',
    '?pageSize=100000',
  ])('rejects unsafe query %s', async (query) => {
    await request(server)
      .get('/api/v1/admin/books' + query)
      .set('Authorization', 'Bearer fixture')
      .expect(400);
  });
  it.each(['books', 'users', 'orders', 'entitlements'])(
    'validates detail UUID %s',
    async (kind) => {
      await request(server)
        .get('/api/v1/admin/' + kind + '/not-an-id')
        .set('Authorization', 'Bearer fixture')
        .expect(400);
    },
  );
  it.each(['books', 'categories', 'users', 'orders', 'entitlements', 'audit'])(
    'returns no-store %s',
    async (kind) => {
      await request(server)
        .get('/api/v1/admin/' + kind)
        .set('Authorization', 'Bearer fixture')
        .expect(200)
        .expect('Cache-Control', 'no-store');
    },
  );
  const book = {
    title: 'Circuit Theory',
    description: 'A study guide',
    categoryId: id,
    price: '120.50',
    status: 'DRAFT',
  };
  it.each([
    'coverObjectKey',
    'previewPageCount',
    'adminActorId',
    'externalAuthId',
    'slug',
    'entitlements',
  ])('rejects book mass assignment %s', async (field) => {
    await request(server)
      .post('/api/v1/admin/books')
      .set('Authorization', 'Bearer fixture')
      .send({ ...book, [field]: 'private' })
      .expect(400);
  });
  it.each(['-1', '1e3', '1.234', 'NaN', '10000000000', '01', '1,000'])(
    'rejects invalid decimal %s',
    async (price) => {
      await request(server)
        .post('/api/v1/admin/books')
        .set('Authorization', 'Bearer fixture')
        .send({ ...book, price })
        .expect(400);
    },
  );
  it('accepts free book metadata and takes actor from guard', async () => {
    await request(server)
      .post('/api/v1/admin/books')
      .set('Authorization', 'Bearer fixture')
      .send({ ...book, price: '0' })
      .expect(201);
    expect(service.mutate).toHaveBeenCalledWith(
      id,
      'books',
      undefined,
      expect.objectContaining({ price: '0' }),
    );
  });
  it.each([
    { title: null },
    { price: 12 },
    { currency: 'USD' },
    { pageCount: 0 },
    { categoryId: 'bad' },
  ])('rejects unsafe book patch %j', async (body) => {
    await request(server)
      .patch('/api/v1/admin/books/' + id)
      .set('Authorization', 'Bearer fixture')
      .send(body)
      .expect(400);
  });
  it('permits partial metadata update', async () => {
    await request(server)
      .patch('/api/v1/admin/books/' + id)
      .set('Authorization', 'Bearer fixture')
      .send({ title: 'New title' })
      .expect(200);
  });
  it.each([
    { name: '' },
    { name: 'x', sortOrder: -1 },
    { name: 'x', isActive: 'true' },
    { name: 'x', slug: 'bad' },
    { name: null },
  ])('rejects category input %j', async (body) => {
    await request(server)
      .post('/api/v1/admin/categories')
      .set('Authorization', 'Bearer fixture')
      .send(body)
      .expect(400);
  });
  it.each([
    { status: 'ADMIN' },
    { status: 'DISABLED', externalAuthId: 'other' },
    { status: 'ACTIVE', role: 'SUPER_ADMIN' },
  ])('rejects user mass assignment %j', async (body) => {
    await request(server)
      .patch('/api/v1/admin/users/' + id + '/status')
      .set('Authorization', 'Bearer fixture')
      .send(body)
      .expect(400);
  });
  it('content managers cannot mutate users', async () => {
    findAdmin.mockResolvedValue({
      id,
      role: 'CONTENT_MANAGER',
      status: 'ACTIVE',
    });
    await request(server)
      .patch('/api/v1/admin/users/' + id + '/status')
      .set('Authorization', 'Bearer fixture')
      .send({ status: 'DISABLED' })
      .expect(403);
  });
  it('allows only configured browser CORS origin', async () => {
    await request(server)
      .get('/api/v1/admin/me')
      .set('Origin', 'http://localhost:5173')
      .set('Authorization', 'Bearer fixture')
      .expect('Access-Control-Allow-Origin', 'http://localhost:5173');
    const r = await request(server)
      .get('/api/v1/admin/me')
      .set('Origin', 'https://evil.example')
      .set('Authorization', 'Bearer fixture');
    expect(r.headers['access-control-allow-origin']).toBeUndefined();
  });
});
describe('admin DTO and operator validation', () => {
  it.each(['ACTIVE', 'INVALID', 'super_admin', ''])(
    'rejects invalid provisioning role %s',
    (role) => {
      expect(() =>
        parseOperatorArgs(['provision', '--uid', 'controlled-uid', role]),
      ).toThrow();
    },
  );
  it.each(['SUPER_ADMIN', 'CONTENT_MANAGER', 'PAYMENT_REVIEWER'])(
    'accepts explicit role %s',
    (role) => {
      expect(
        parseOperatorArgs(['provision', '--uid', 'controlled-uid', role]).value,
      ).toBe(role);
    },
  );
  it('requires explicit disable acknowledgement', () => {
    expect(() =>
      parseOperatorArgs(['disable', '--uid', 'controlled-uid', 'yes']),
    ).toThrow();
    expect(
      parseOperatorArgs(['disable', '--uid', 'controlled-uid', 'CONFIRM'])
        .action,
    ).toBe('disable');
  });
  it.each(
    [
      [],
      ['provision'],
      ['provision', '--uid', 'bad uid', 'SUPER_ADMIN'],
      ['provision', '--uid', 'uid', 'SUPER_ADMIN', 'extra'],
    ].map((args) => [args]),
  )('rejects malformed operator arguments %j', (args) => {
    expect(() => parseOperatorArgs(args)).toThrow();
  });
  it('generates safe stable slugs and rejects empty normalization', () => {
    expect(slugFor(' Electrical Machines! ')).toBe('electrical-machines');
    expect(() => slugFor('***')).toThrow();
  });
  it.each([BookDto, BookPatch, CategoryDto])(
    'does not accept null values',
    async (Dto) => {
      const body = plainToInstance(
        Dto as new () => object,
        Dto === CategoryDto ? { name: null } : { title: null },
      );
      expect((await validate(body)).length).toBeGreaterThan(0);
    },
  );
});
