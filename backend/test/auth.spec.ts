import {
  INestApplication,
  Logger,
  UnauthorizedException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/config/configure-app';
import { FirebaseService } from '../src/firebase/firebase.service';
import { PrismaService } from '../src/database/prisma.service';
import { Prisma } from '../src/generated/prisma/client';
import { SafeUser, VerifiedIdentity } from '../src/auth/auth.types';

const identity: VerifiedIdentity = {
  firebaseUid: 'verified-uid',
  email: 'reader@fixture.example',
  displayName: 'Reader',
};
const user = (): SafeUser => ({
  id: 'database-user-id',
  email: identity.email,
  displayName: identity.displayName,
  status: 'ACTIVE',
  createdAt: new Date('2026-01-01T00:00:00Z'),
});
const conflict = () =>
  new Prisma.PrismaClientKnownRequestError('private uniqueness details', {
    code: 'P2002',
    clientVersion: '7.10.0',
  });

describe('Firebase protected auth HTTP', () => {
  let app: INestApplication;
  let server: Server;
  const verifyIdToken = jest.fn<Promise<VerifiedIdentity>, [string]>();
  const upsert = jest.fn<Promise<SafeUser>, [unknown]>();
  const findUnique = jest.fn<Promise<SafeUser | null>, [unknown]>();
  let loggerError: jest.SpyInstance;
  beforeAll(async () => {
    loggerError = jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation(() => undefined);
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(FirebaseService)
      .useValue({ verifyIdToken })
      .overrideProvider(PrismaService)
      .useValue({ user: { upsert, findUnique } })
      .compile();
    app = module.createNestApplication({ bodyParser: false, logger: false });
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
  });
  beforeEach(() => {
    verifyIdToken.mockReset().mockResolvedValue(identity);
    upsert.mockReset().mockResolvedValue(user());
    findUnique.mockReset().mockResolvedValue(user());
  });
  afterAll(async () => {
    await app.close();
    jest.restoreAllMocks();
  });
  it.each(['/api/v1/auth/bootstrap', '/api/v1/auth/me'])(
    'rejects missing Authorization on %s',
    async (route) => {
      const call = route.endsWith('/me')
        ? request(server).get(route)
        : request(server).post(route);
      await call
        .expect(401)
        .expect({ statusCode: 401, message: 'Unauthorized' });
      expect(verifyIdToken).not.toHaveBeenCalled();
    },
  );
  it.each([
    'Basic abc',
    'Bearer',
    'Bearer ',
    'Bearer a b',
    'Bearer a,b',
    'Bearer  token',
    'Bearertoken',
  ])('rejects malformed Authorization %s', async (header) => {
    await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', header)
      .expect(401);
    expect(verifyIdToken).not.toHaveBeenCalled();
  });
  it('rejects duplicate Authorization headers', async () => {
    await request(server)
      .get('/api/v1/auth/me')
      .set({ Authorization: ['Bearer one', 'Bearer two'] })
      .expect(401);
    expect(verifyIdToken).not.toHaveBeenCalled();
  });
  it.each(['invalid-token', 'expired-token'])(
    'rejects %s without SDK error/token disclosure',
    async (token) => {
      verifyIdToken.mockRejectedValue(new UnauthorizedException());
      const response = await request(server)
        .get('/api/v1/auth/me')
        .set('Authorization', 'Bearer ' + token)
        .expect(401);
      expect(response.body).toEqual({
        statusCode: 401,
        message: 'Unauthorized',
      });
      expect(loggerError).not.toHaveBeenCalled();
      expect(findUnique).not.toHaveBeenCalled();
    },
  );
  it('creates a new local user solely from verified claims', async () => {
    await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'Bearer fixture-token')
      .expect(200)
      .expect({ ...user(), createdAt: user().createdAt.toISOString() });
    expect(upsert).toHaveBeenCalledWith({
      where: { externalAuthId: identity.firebaseUid },
      create: {
        externalAuthId: identity.firebaseUid,
        email: identity.email,
        displayName: identity.displayName,
      },
      update: {},
      select: {
        id: true,
        email: true,
        displayName: true,
        status: true,
        createdAt: true,
      },
    });
    expect(findUnique).not.toHaveBeenCalled();
  });
  it('accepts case-insensitive Bearer scheme', async () => {
    await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'bearer fixture-token')
      .expect(200);
  });
  it.each([
    { firebaseUid: 'attacker' },
    { externalAuthId: 'attacker' },
    { email: 'attacker@fixture.example' },
    { role: 'SUPER_ADMIN' },
    { status: 'ACTIVE' },
    ['attacker'],
  ])(
    'rejects spoofed bootstrap body without writing identity',
    async (body) => {
      await request(server)
        .post('/api/v1/auth/bootstrap')
        .set('Authorization', 'Bearer fixture-token')
        .send(body)
        .expect(400);
      expect(upsert).not.toHaveBeenCalled();
    },
  );
  it('repeated bootstrap preserves the same user without metadata/status updates', async () => {
    const first = await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'Bearer fixture-token')
      .send({})
      .expect(200);
    const second = await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'Bearer fixture-token')
      .expect(200);
    expect(second.body).toEqual(first.body);
    expect(upsert).toHaveBeenCalledTimes(2);
  });
  it('resolves a uniqueness race by verified UID only', async () => {
    upsert.mockRejectedValue(conflict());
    await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'Bearer fixture-token')
      .expect(200);
    expect(findUnique).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { externalAuthId: identity.firebaseUid },
      }),
    );
  });
  it('never relinks another UID with a colliding email', async () => {
    upsert.mockRejectedValue(conflict());
    findUnique.mockResolvedValue(null);
    await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'Bearer fixture-token')
      .expect(409)
      .expect({ statusCode: 409, message: 'Conflict' });
    expect(findUnique).toHaveBeenCalledTimes(1);
    expect(findUnique).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { externalAuthId: identity.firebaseUid },
      }),
    );
  });
  it('me returns exactly the safe DTO and performs one UID lookup', async () => {
    const response = await request(server)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer fixture-token')
      .expect(200);
    expect(Object.keys(response.body as object).sort()).toEqual(
      ['id', 'email', 'displayName', 'status', 'createdAt'].sort(),
    );
    expect(response.body).toEqual({
      ...user(),
      createdAt: user().createdAt.toISOString(),
    });
    expect(findUnique).toHaveBeenCalledTimes(1);
    expect(upsert).not.toHaveBeenCalled();
  });
  it('me requires an existing application user and does not create one on GET', async () => {
    findUnique.mockResolvedValue(null);
    await request(server)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer fixture-token')
      .expect(404);
    expect(upsert).not.toHaveBeenCalled();
  });
  it.each(['DISABLED', 'SUSPENDED'] as const)(
    'denies %s local accounts on both routes',
    async (status) => {
      upsert.mockResolvedValue({ ...user(), status });
      findUnique.mockResolvedValue({ ...user(), status });
      await request(server)
        .post('/api/v1/auth/bootstrap')
        .set('Authorization', 'Bearer fixture-token')
        .expect(403);
      await request(server)
        .get('/api/v1/auth/me')
        .set('Authorization', 'Bearer fixture-token')
        .expect(403);
    },
  );
  it('checks the status of a concurrent bootstrap winner', async () => {
    upsert.mockRejectedValue(conflict());
    findUnique.mockResolvedValue({ ...user(), status: 'SUSPENDED' });
    await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'Bearer fixture-token')
      .expect(403);
  });
  it('does not leak unexpected database errors or tokens to logs/responses', async () => {
    upsert.mockRejectedValue(new Error('private SQL fixture-token'));
    const response = await request(server)
      .post('/api/v1/auth/bootstrap')
      .set('Authorization', 'Bearer fixture-token')
      .expect(500);
    expect(response.body).toEqual({
      statusCode: 500,
      message: 'Internal Server Error',
    });
    expect(JSON.stringify(loggerError.mock.calls)).not.toContain(
      'fixture-token',
    );
    expect(JSON.stringify(loggerError.mock.calls)).not.toContain('private SQL');
  });
  it('keeps health public even with an invalid Authorization header', async () => {
    await request(server)
      .get('/api/v1/health')
      .set('Authorization', 'Basic invalid')
      .expect(200)
      .expect({ status: 'ok' });
    expect(verifyIdToken).not.toHaveBeenCalled();
  });

  it('sanitizes Firebase infrastructure errors without logging raw tokens', async () => {
    verifyIdToken.mockRejectedValue(
      new ServiceUnavailableException('private Firebase fixture-token'),
    );
    const response = await request(server)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer fixture-token')
      .expect(503);
    expect(response.body).toEqual({
      statusCode: 503,
      message: 'Service Unavailable',
    });
    expect(JSON.stringify(loggerError.mock.calls)).not.toContain(
      'fixture-token',
    );
    expect(JSON.stringify(loggerError.mock.calls)).not.toContain(
      'private Firebase',
    );
  });
});
