import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { json, urlencoded, Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import { Environment } from './environment';
import { SafeExceptionFilter } from '../common/filters/safe-exception.filter';
import {
  authDiagnosticsEnabled,
  recordAuthDiagnostic,
} from '../common/auth-diagnostics';

export function configureApp(app: INestApplication): void {
  const config = app.get(ConfigService<Environment, true>);
  const origins = new Set(config.get('CORS_ORIGINS', { infer: true }));
  app.setGlobalPrefix('api/v1');
  if (authDiagnosticsEnabled()) {
    app.use((request: Request, response: Response, next: NextFunction) => {
      const route = request.path;
      if (route === '/api/v1/auth/bootstrap' || route === '/api/v1/auth/me') {
        response.once('finish', () =>
          recordAuthDiagnostic({
            event: 'http-response',
            route,
            status: response.statusCode,
          }),
        );
      }
      next();
    });
  }
  app.use((request: Request, response: Response, next: NextFunction) => {
    if (
      request.path === '/api/v1/admin' ||
      request.path.startsWith('/api/v1/admin/')
    )
      response.setHeader('Cache-Control', 'no-store');
    next();
  });
  app.use(helmet());
  app.use(json({ limit: '16kb' }));
  app.use(urlencoded({ limit: '16kb', extended: false }));
  app.enableCors({
    origin: (
      origin: string | undefined,
      callback: (error: Error | null, allowed: boolean) => void,
    ) => callback(null, !origin || origins.has(origin)),
    credentials: false,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
    }),
  );
  app.useGlobalFilters(new SafeExceptionFilter());
  app.enableShutdownHooks();
}
