import {
  INestApplication,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import request from 'supertest';
import { Server } from 'node:http';
import { randomUUID } from 'node:crypto';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/config/configure-app';
import { validateEnvironment } from '../src/config/environment';
import { FirebaseService } from '../src/firebase/firebase.service';
import { PrismaService } from '../src/database/prisma.service';
import { PurchaseService } from '../src/purchases/purchase.service';
import { EntitlementService } from '../src/purchases/entitlement.service';
import { ManualPaymentOptions } from '../src/purchases/manual-payment-options';
const id = randomUUID();
const userId = randomUUID();
const adminId = randomUUID();
describe('protected purchase HTTP boundaries', () => {
  let app: INestApplication;
  let server: Server;
  const verifyIdToken = jest.fn();
  const user = jest.fn();
  const admin = jest.fn();
  const purchases = {
    create: jest.fn(),
    submit: jest.fn(),
    get: jest.fn(),
    list: jest.fn(),
    access: jest.fn(),
    reviews: jest.fn(),
    reviewDetail: jest.fn(),
    review: jest.fn(),
  };
  const library = jest.fn();
  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(FirebaseService)
      .useValue({ verifyIdToken })
      .overrideProvider(PrismaService)
      .useValue({
        user: { findUnique: user },
        adminUser: { findUnique: admin },
      })
      .overrideProvider(PurchaseService)
      .useValue(purchases)
      .overrideProvider(EntitlementService)
      .useValue({ library })
      .compile();
    app = module.createNestApplication({ bodyParser: false, logger: false });
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
  });
  beforeEach(() => {
    verifyIdToken.mockReset().mockResolvedValue({
      firebaseUid: 'trusted-fixture-uid',
      email: 'fixture@example.test',
      displayName: 'Reader',
    });
    user.mockReset().mockResolvedValue({
      id: userId,
      email: 'fixture@example.test',
      displayName: 'Reader',
      status: 'ACTIVE',
      createdAt: new Date(),
    });
    admin.mockReset().mockResolvedValue(null);
    for (const method of Object.values(purchases))
      method.mockReset().mockResolvedValue({ id });
    library.mockReset().mockResolvedValue({ items: [], total: 0 });
  });
  afterAll(async () => {
    await app.close();
  });
  it.each([
    '/orders',
    '/orders/' + id,
    '/orders/payment-options',
    '/books/sample/access',
    '/library',
    '/admin/payments',
    '/admin/payments/' + id,
  ])('rejects guest GET %s', async (path) => {
    await request(server)
      .get('/api/v1' + path)
      .expect(401);
  });
  it.each([
    '/orders',
    '/orders/' + id + '/payment',
    '/admin/payments/' + id + '/approve',
    '/admin/payments/' + id + '/reject',
  ])('rejects guest mutation %s', async (path) => {
    await request(server)
      .post('/api/v1' + path)
      .send({})
      .expect(401);
  });
  it('marks authenticated order responses no-store', async () => {
    await request(server)
      .get('/api/v1/orders')
      .set('Authorization', 'Bearer fixture-token')
      .expect(200)
      .expect('Cache-Control', 'no-store');
  });
  it('takes local user identity from verified guard only', async () => {
    await request(server)
      .post('/api/v1/orders')
      .set('Authorization', 'Bearer fixture-token')
      .send({ bookSlug: 'sample-book' })
      .expect(200);
    expect(purchases.create).toHaveBeenCalledWith(userId, 'sample-book');
  });
  it.each([
    'userId',
    'amount',
    'price',
    'currency',
    'status',
    'owned',
    'adminId',
  ])('rejects mass assignment: %s', async (field) => {
    await request(server)
      .post('/api/v1/orders')
      .set('Authorization', 'Bearer fixture-token')
      .send({ bookSlug: 'sample-book', [field]: 'forged' })
      .expect(400);
    expect(purchases.create).not.toHaveBeenCalled();
  });
  it.each([
    { method: 'STRIPE', reference: 'ABC' },
    { method: 'BKASH', reference: 'x' },
    { method: 'NAGAD', reference: 'a b c' },
    { method: 'BKASH', reference: 'A'.repeat(101) },
    { method: 'BKASH', reference: 'ABC', status: 'APPROVED' },
  ])('rejects unsafe payment intent %j', async (body) => {
    await request(server)
      .post('/api/v1/orders/' + id + '/payment')
      .set('Authorization', 'Bearer fixture-token')
      .send(body)
      .expect(400);
  });
  it('canonicalizes a safe reference and never accepts client amount', async () => {
    await request(server)
      .post('/api/v1/orders/' + id + '/payment')
      .set('Authorization', 'Bearer fixture-token')
      .send({ method: 'BKASH', reference: '  abc123  ' })
      .expect(200);
    expect(purchases.submit).toHaveBeenCalledWith(userId, id, {
      method: 'BKASH',
      reference: 'ABC123',
    });
  });
  it.each([
    '/orders?pageSize=41',
    '/orders?page=0',
    '/library?pageSize=100',
    '/orders?userId=forged',
    '/books/Bad_Slug/access',
  ])('rejects invalid query or slug %s', async (path) => {
    await request(server)
      .get('/api/v1' + path)
      .set('Authorization', 'Bearer fixture-token')
      .expect(400);
  });
  it('denies inactive local accounts', async () => {
    user.mockResolvedValue({ id: userId, status: 'SUSPENDED' });
    await request(server)
      .post('/api/v1/orders')
      .set('Authorization', 'Bearer fixture-token')
      .send({ bookSlug: 'sample' })
      .expect(403);
  });
  it.each(['get', 'post'] as const)(
    'normal user cannot review payments with %s',
    async (method) => {
      const path =
        '/api/v1/admin/payments' +
        (method === 'post' ? '/' + id + '/approve' : '');
      await request(server)
        [method](path)
        .set('Authorization', 'Bearer fixture-token')
        .set('X-Admin', 'true')
        .send({})
        .expect(403);
    },
  );
  it.each([
    { status: 'DISABLED', role: 'SUPER_ADMIN' },
    { status: 'ACTIVE', role: 'CONTENT_MANAGER' },
  ])('denies untrusted reviewer state %j', async (state) => {
    admin.mockResolvedValue({ id: adminId, ...state });
    await request(server)
      .get('/api/v1/admin/payments')
      .set('Authorization', 'Bearer fixture-token')
      .expect(403);
  });
  it('authorizes persisted review role without requiring a normal User row', async () => {
    admin.mockResolvedValue({
      id: adminId,
      status: 'ACTIVE',
      role: 'PAYMENT_REVIEWER',
    });
    user.mockResolvedValue(null);
    await request(server)
      .post('/api/v1/admin/payments/' + id + '/approve')
      .set('Authorization', 'Bearer fixture-token')
      .send({})
      .expect(200);
    expect(purchases.review).toHaveBeenCalledWith(adminId, id, 'APPROVED');
  });
  it('rejects forged approval state and arbitrary rejection notes', async () => {
    admin.mockResolvedValue({
      id: adminId,
      status: 'ACTIVE',
      role: 'SUPER_ADMIN',
    });
    await request(server)
      .post('/api/v1/admin/payments/' + id + '/approve')
      .set('Authorization', 'Bearer fixture-token')
      .send({ adminId, status: 'APPROVED' })
      .expect(400);
    await request(server)
      .post('/api/v1/admin/payments/' + id + '/reject')
      .set('Authorization', 'Bearer fixture-token')
      .send({ reason: 'private arbitrary note' })
      .expect(400);
  });
  it('accepts an allowlisted public rejection reason', async () => {
    admin.mockResolvedValue({
      id: adminId,
      status: 'ACTIVE',
      role: 'SUPER_ADMIN',
    });
    await request(server)
      .post('/api/v1/admin/payments/' + id + '/reject')
      .set('Authorization', 'Bearer fixture-token')
      .send({ reason: 'AMOUNT_MISMATCH' })
      .expect(200);
    expect(purchases.review).toHaveBeenCalledWith(
      adminId,
      id,
      'REJECTED',
      'AMOUNT_MISMATCH',
    );
  });
  it('validates review status/pagination', async () => {
    admin.mockResolvedValue({
      id: adminId,
      status: 'ACTIVE',
      role: 'SUPER_ADMIN',
    });
    await request(server)
      .get('/api/v1/admin/payments?status=private&pageSize=41')
      .set('Authorization', 'Bearer fixture-token')
      .expect(400);
  });
  it.each([
    new UnauthorizedException(),
    new ForbiddenException(),
    new NotFoundException(),
    new ServiceUnavailableException(),
  ])('sanitizes purchase error response', async (exception) => {
    purchases.create.mockRejectedValue(exception);
    const response = await request(server)
      .post('/api/v1/orders')
      .set('Authorization', 'Bearer fixture-token')
      .send({ bookSlug: 'sample' })
      .expect(exception.getStatus());
    expect(response.text).not.toContain('fixture-token');
    expect(response.text).not.toContain('stack');
  });
});
describe('manual receiving instruction configuration', () => {
  it('is disabled without explicit configuration', () => {
    const options = new ManualPaymentOptions(
      new ConfigService({
        NODE_ENV: 'production',
        MANUAL_PAYMENT_DEVELOPMENT_MODE: false,
      }),
    );
    expect(options.list()).toEqual([]);
    expect(() => options.require()).toThrow(ServiceUnavailableException);
  });
  it('provides clearly labeled development instructions without invented account numbers', () => {
    const options = new ManualPaymentOptions(
      new ConfigService({
        NODE_ENV: 'development',
        MANUAL_PAYMENT_DEVELOPMENT_MODE: true,
      }),
    );
    expect(options.list()).toHaveLength(2);
    expect(
      options
        .list()
        .every(
          (o) =>
            o.development && o.instructions.includes('Do not transfer money'),
        ),
    ).toBe(true);
  });
  it('serves only configured supported methods', () => {
    const options = new ManualPaymentOptions(
      new ConfigService({
        NODE_ENV: 'production',
        MANUAL_PAYMENT_BKASH_INSTRUCTIONS:
          'Configured public receiving instructions',
      }),
    );
    expect(options.list().map((o) => o.method)).toEqual(['BKASH']);
    expect(() => options.require('NAGAD')).toThrow(ServiceUnavailableException);
  });
  it('rejects development payment mode outside development', () => {
    expect(() =>
      validateEnvironment({
        ...process.env,
        NODE_ENV: 'production',
        CORS_ORIGINS: '',
        MANUAL_PAYMENT_DEVELOPMENT_MODE: 'true',
      }),
    ).toThrow('MANUAL_PAYMENT_DEVELOPMENT_MODE');
  });
  it('rejects unsafe or oversized instruction text', () => {
    expect(() =>
      validateEnvironment({
        ...process.env,
        MANUAL_PAYMENT_BKASH_INSTRUCTIONS: 'x\ny',
      }),
    ).toThrow('MANUAL_PAYMENT_BKASH_INSTRUCTIONS');
    expect(() =>
      validateEnvironment({
        ...process.env,
        MANUAL_PAYMENT_NAGAD_INSTRUCTIONS: 'x'.repeat(401),
      }),
    ).toThrow('MANUAL_PAYMENT_NAGAD_INSTRUCTIONS');
  });
});
