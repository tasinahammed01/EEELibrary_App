import { AdminModule } from './admin/admin.module';
import { PurchaseModule } from './purchases/purchase.module';
import { CatalogModule } from './catalog/catalog.module';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { validateEnvironment } from './config/environment';
import { PrismaModule } from './database/prisma.module';
import { AuthModule } from './auth/auth.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnvironment,
    }),
    PrismaModule,
    HealthModule,
    AuthModule,
    PurchaseModule,
    CatalogModule,
    AdminModule,
  ],
})
export class AppModule {}
