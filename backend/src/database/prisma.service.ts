import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client';
import { Environment } from '../config/environment';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor(config: ConfigService<Environment, true>) {
    super({
      adapter: new PrismaPg({
        connectionString: config.get('DATABASE_URL', { infer: true }),
        max: 10,
        connectionTimeoutMillis: 5000,
        idleTimeoutMillis: 30000,
      }),
    });
  }
  async onModuleInit(): Promise<void> {
    try {
      await this.$connect();
      // Driver adapters can initialize lazily; verify connectivity once at startup.
      await this.$queryRaw`SELECT 1`;
    } catch {
      await this.$disconnect();
      throw new Error('Database initialization failed');
    }
  }
  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
