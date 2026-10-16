import { ConfigModule, ConfigService } from '@nestjs/config';
import { Module } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaModule } from '../src/database/prisma.module';
import { PrismaService } from '../src/database/prisma.service';
import { PrismaClient } from '../src/generated/prisma/client';
import { Environment, validateEnvironment } from '../src/config/environment';

@Module({ imports: [PrismaModule], exports: [PrismaModule] })
class ConsumerModule {}

describe('Prisma singleton lifecycle', () => {
  it('reuses one provider across consumers and connects/disconnects exactly once', async () => {
    const connect = jest
      .spyOn(PrismaClient.prototype, '$connect')
      .mockResolvedValue(undefined);
    const query = jest
      .spyOn(PrismaClient.prototype, '$queryRaw')
      .mockResolvedValue([{ value: 1 }]);
    const disconnect = jest
      .spyOn(PrismaClient.prototype, '$disconnect')
      .mockResolvedValue(undefined);
    const module = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: validateEnvironment,
        }),
        PrismaModule,
        ConsumerModule,
      ],
    }).compile();
    try {
      await module.init();
      expect(module.get(PrismaService)).toBe(
        module.select(ConsumerModule).get(PrismaService),
      );
      expect(connect).toHaveBeenCalledTimes(1);
      expect(query).toHaveBeenCalledTimes(1);
      await module.close();
      expect(disconnect).toHaveBeenCalledTimes(1);
    } finally {
      jest.restoreAllMocks();
    }
  });

  it('releases the pool and sanitizes a startup query failure', async () => {
    jest.spyOn(PrismaClient.prototype, '$connect').mockResolvedValue(undefined);
    jest
      .spyOn(PrismaClient.prototype, '$queryRaw')
      .mockRejectedValue(new Error('postgresql://private:secret@host/db'));
    const disconnect = jest
      .spyOn(PrismaClient.prototype, '$disconnect')
      .mockResolvedValue(undefined);
    const service = new PrismaService(
      new ConfigService<Environment, true>(validateEnvironment(process.env)),
    );
    try {
      await expect(service.onModuleInit()).rejects.toThrow(
        'Database initialization failed',
      );
      expect(disconnect).toHaveBeenCalledTimes(1);
    } finally {
      jest.restoreAllMocks();
    }
  });
});
