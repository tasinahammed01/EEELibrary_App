import {
  Body,
  Controller,
  Get,
  INestApplication,
  InternalServerErrorException,
  Logger,
  Post,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { IsString, MinLength } from 'class-validator';
import request from 'supertest';
import { Server } from 'node:http';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/config/configure-app';
import { PrismaService } from '../src/database/prisma.service';

class ProbeDto {
  @IsString() @MinLength(2) name!: string;
}
// Test-only probes verify middleware without introducing application endpoints.
@Controller('test-probe')
class ProbeController {
  @Get('failure') failure(): never {
    throw new Error('postgresql://private:secret@host/db C:/private/path');
  }
  @Get('http-failure') httpFailure(): never {
    throw new InternalServerErrorException('private database details');
  }
  @Post() echo(@Body() body: ProbeDto): ProbeDto {
    return body;
  }
}

describe('AppModule HTTP foundation', () => {
  let app: INestApplication;
  let server: Server;
  let initializationCount = 0;
  const database = {
    onModuleInit: () => {
      initializationCount += 1;
    },
    onModuleDestroy: jest.fn(),
  };
  beforeAll(async () => {
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    const module = await Test.createTestingModule({
      imports: [AppModule],
      controllers: [ProbeController],
    })
      .overrideProvider(PrismaService)
      .useValue(database)
      .compile();
    app = module.createNestApplication({ bodyParser: false, logger: false });
    configureApp(app);
    await app.init();
    server = app.getHttpServer() as Server;
  });
  afterAll(async () => {
    await app.close();
    jest.restoreAllMocks();
  });
  it('boots AppModule and invokes the single injected database lifecycle', () => {
    expect(initializationCount).toBe(1);
    expect(app.get(PrismaService)).toBe(database);
  });
  it('returns only the public health contract', async () => {
    await request(server)
      .get('/api/v1/health')
      .expect(200)
      .expect({ status: 'ok' });
  });
  it('does not expose an unversioned health route', async () => {
    await request(server)
      .get('/health')
      .expect(404)
      .expect({ statusCode: 404, message: 'Not Found' });
  });
  it('adds security headers and omits technology disclosure', async () => {
    const response = await request(server).get('/api/v1/health');
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-powered-by']).toBeUndefined();
  });
  it('allows only an explicitly configured browser origin', async () => {
    const allowed = await request(server)
      .get('/api/v1/health')
      .set('Origin', 'http://localhost:5173');
    expect(allowed.headers['access-control-allow-origin']).toBe(
      'http://localhost:5173',
    );
    const denied = await request(server)
      .get('/api/v1/health')
      .set('Origin', 'https://untrusted.example');
    expect(denied.headers['access-control-allow-origin']).toBeUndefined();
  });
  it.each(['failure', 'http-failure'])('sanitizes %s errors', async (route) => {
    await request(server)
      .get('/api/v1/test-probe/' + route)
      .expect(500)
      .expect({ statusCode: 500, message: 'Internal Server Error' });
  });
  it('rejects unknown fields', async () => {
    await request(server)
      .post('/api/v1/test-probe')
      .send({ name: 'Valid', admin: true })
      .expect(400);
  });
  it('does not implicitly coerce invalid field types', async () => {
    await request(server)
      .post('/api/v1/test-probe')
      .send({ name: 123 })
      .expect(400);
  });
  it('accepts an explicitly validated DTO', async () => {
    await request(server)
      .post('/api/v1/test-probe')
      .send({ name: 'Valid' })
      .expect(201)
      .expect({ name: 'Valid' });
  });
  it('enforces a 16 KiB body limit', async () => {
    await request(server)
      .post('/api/v1/test-probe')
      .send({ name: 'x'.repeat(17000) })
      .expect(413)
      .expect({ statusCode: 413, message: 'Payload Too Large' });
  });
  it('handles malformed JSON without exposing parser internals', async () => {
    await request(server)
      .post('/api/v1/test-probe')
      .set('Content-Type', 'application/json')
      .send('{invalid')
      .expect(400)
      .expect({ statusCode: 400, message: 'Bad Request' });
  });
});
