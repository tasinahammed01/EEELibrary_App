import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard';
import { PurchaseNoStoreInterceptor } from '../purchases/purchase-no-store.interceptor';
import { AdminGuard, AdminRequest, Roles } from './admin.guard';
import { AdminService } from './admin.service';
import {
  AdminQuery,
  BookDto,
  BookPatch,
  CategoryDto,
  CategoryPatch,
  UserStatusDto,
} from './admin.dto';
@Controller('admin')
@UseGuards(FirebaseAuthGuard, AdminGuard)
@UseInterceptors(PurchaseNoStoreInterceptor)
export class AdminController {
  constructor(private readonly service: AdminService) {}
  @Get('me') me(@Req() req: AdminRequest) {
    return req.admin;
  }
  @Get('dashboard') dashboard(@Req() req: AdminRequest) {
    return this.service.dashboard(req.admin!.role);
  }
  @Get('books') @Roles('SUPER_ADMIN', 'CONTENT_MANAGER') books(
    @Query() q: AdminQuery,
  ) {
    return this.service.list('books', q);
  }
  @Get('books/:id') @Roles('SUPER_ADMIN', 'CONTENT_MANAGER') booksDetail(
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.service.detail('books', id);
  }
  @Post('books') @Roles('SUPER_ADMIN', 'CONTENT_MANAGER') createBook(
    @Req() req: AdminRequest,
    @Body() body: BookDto,
  ) {
    return this.service.mutate(req.admin!.id, 'books', undefined, body);
  }
  @Patch('books/:id') @Roles('SUPER_ADMIN', 'CONTENT_MANAGER') updateBook(
    @Req() req: AdminRequest,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: BookPatch,
  ) {
    return this.service.mutate(req.admin!.id, 'books', id, body);
  }
  @Get('categories') @Roles('SUPER_ADMIN', 'CONTENT_MANAGER') categories(
    @Query() q: AdminQuery,
  ) {
    return this.service.list('categories', q);
  }
  @Post('categories') @Roles('SUPER_ADMIN', 'CONTENT_MANAGER') createCategory(
    @Req() req: AdminRequest,
    @Body() body: CategoryDto,
  ) {
    return this.service.mutate(req.admin!.id, 'categories', undefined, body);
  }
  @Patch('categories/:id')
  @Roles('SUPER_ADMIN', 'CONTENT_MANAGER')
  updateCategory(
    @Req() req: AdminRequest,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: CategoryPatch,
  ) {
    return this.service.mutate(req.admin!.id, 'categories', id, body);
  }
  @Get('users') @Roles('SUPER_ADMIN') users(@Query() q: AdminQuery) {
    return this.service.list('users', q);
  }
  @Get('users/:id') @Roles('SUPER_ADMIN') usersDetail(
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.service.detail('users', id);
  }
  @Get('orders') @Roles('SUPER_ADMIN', 'PAYMENT_REVIEWER') orders(
    @Query() q: AdminQuery,
  ) {
    return this.service.list('orders', q);
  }
  @Get('orders/:id') @Roles('SUPER_ADMIN', 'PAYMENT_REVIEWER') ordersDetail(
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.service.detail('orders', id);
  }
  @Get('entitlements') @Roles('SUPER_ADMIN') entitlements(
    @Query() q: AdminQuery,
  ) {
    return this.service.list('entitlements', q);
  }
  @Get('entitlements/:id') @Roles('SUPER_ADMIN') entitlementsDetail(
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.service.detail('entitlements', id);
  }
  @Get('audit') @Roles('SUPER_ADMIN') audit(@Query() q: AdminQuery) {
    return this.service.list('audit', q);
  }
  @Patch('users/:id/status') @Roles('SUPER_ADMIN') userStatus(
    @Req() req: AdminRequest,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() body: UserStatusDto,
  ) {
    return this.service.mutate(req.admin!.id, 'users', id, body);
  }
}
