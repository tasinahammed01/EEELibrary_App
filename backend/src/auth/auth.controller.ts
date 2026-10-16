import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { SafeUser, VerifiedIdentity } from './auth.types';
import {
  CurrentUser,
  VerifiedFirebaseIdentity,
} from './decorators/current-user.decorator';
import { FirebaseAuthGuard } from './guards/firebase-auth.guard';
import { ActiveUserGuard } from './guards/active-user.guard';
import { BootstrapBodyPipe } from './pipes/bootstrap-body.pipe';

@Controller('auth')
@UseGuards(FirebaseAuthGuard)
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Post('bootstrap')
  @HttpCode(200)
  bootstrap(
    @VerifiedFirebaseIdentity() identity: VerifiedIdentity,
    @Body(BootstrapBodyPipe) _body: undefined,
  ): Promise<SafeUser> {
    return this.auth.bootstrap(identity);
  }
  @Get('me')
  @UseGuards(ActiveUserGuard)
  me(@CurrentUser() user: SafeUser): SafeUser {
    return user;
  }
}
