import 'reflect-metadata';
import { ConsoleLogger, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './config/configure-app';
import { Environment } from './config/environment';

async function bootstrap(): Promise<void> {
  // Disable the default parsers so the explicit body limits run first.
  // Disable bootstrap error logging: driver/config errors can contain secrets.
  const app = await NestFactory.create(AppModule, {
    bodyParser: false,
    abortOnError: false,
    logger: false,
  });
  try {
    configureApp(app);
    const config = app.get(ConfigService<Environment, true>);
    await app.listen(config.get('PORT', { infer: true }), '127.0.0.1');
  } catch {
    await app.close();
    throw new Error('Application startup failed');
  }
  app.useLogger(['error', 'warn', 'log']);
  new Logger('Bootstrap').log('EEELibrary backend ready');
}
void bootstrap().catch(() => {
  // Use an independent logger for the fixed diagnostic; raw bootstrap logging stays suppressed.
  new ConsoleLogger('Bootstrap', { logLevels: ['error'] }).error(
    'Backend startup failed. Check configuration and database availability.',
  );
  process.exitCode = 1;
});
