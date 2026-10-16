import { Module } from '@nestjs/common';
import { PrismaModule } from '../database/prisma.module';
import { CatalogService } from './catalog.service';
import { CatalogController } from './catalog.controller';
@Module({
  imports: [PrismaModule],
  controllers: [CatalogController],
  providers: [CatalogService],
})
export class CatalogModule {}
