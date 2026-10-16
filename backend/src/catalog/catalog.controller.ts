import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Query,
} from '@nestjs/common';
import { CatalogService } from './catalog.service';
import { CatalogQueryDto } from './catalog-query.dto';
@Controller()
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}
  @Get('categories') categories() {
    return this.catalog.categories();
  }
  @Get('books') books(@Query() query: CatalogQueryDto) {
    return this.catalog.books(query);
  }
  @Get('books/:slug') book(@Param('slug') slug: string) {
    if (slug.length > 280 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug))
      throw new BadRequestException();
    return this.catalog.book(slug);
  }
}
