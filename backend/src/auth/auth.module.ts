import { Module } from '@nestjs/common';
import { PrismaModule } from '../database/prisma.module';
import { FirebaseModule } from '../firebase/firebase.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { FirebaseAuthGuard } from './guards/firebase-auth.guard';
import { ActiveUserGuard } from './guards/active-user.guard';
import { BootstrapBodyPipe } from './pipes/bootstrap-body.pipe';

@Module({
  imports: [PrismaModule, FirebaseModule],
  controllers: [AuthController],
  providers: [
    AuthService,
    FirebaseAuthGuard,
    ActiveUserGuard,
    BootstrapBodyPipe,
  ],
  exports: [AuthService, FirebaseAuthGuard, ActiveUserGuard],
})
export class AuthModule {}
