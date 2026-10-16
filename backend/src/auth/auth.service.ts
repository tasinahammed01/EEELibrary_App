import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../database/prisma.service';
import { SafeUser, VerifiedIdentity } from './auth.types';

export const safeUserSelect = {
  id: true,
  email: true,
  displayName: true,
  status: true,
  createdAt: true,
} satisfies Prisma.UserSelect;

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService) {}

  async bootstrap(identity: VerifiedIdentity): Promise<SafeUser> {
    try {
      const user = await this.prisma.user.upsert({
        where: { externalAuthId: identity.firebaseUid },
        create: {
          externalAuthId: identity.firebaseUid,
          email: identity.email,
          displayName: identity.displayName,
        },
        update: {},
        select: safeUserSelect,
      });
      return this.requireActive(user);
    } catch (error) {
      if (
        !(error instanceof Prisma.PrismaClientKnownRequestError) ||
        error.code !== 'P2002'
      )
        throw error;
      // A concurrent same-UID insert may win. Resolve only by UID, never by email.
      const winner = await this.prisma.user.findUnique({
        where: { externalAuthId: identity.firebaseUid },
        select: safeUserSelect,
      });
      if (winner) return this.requireActive(winner);
      // Another UID owns this email. No automatic relinking, enumeration or overwrite.
      throw new ConflictException();
    }
  }

  async getCurrentUser(identity: VerifiedIdentity): Promise<SafeUser> {
    const user = await this.prisma.user.findUnique({
      where: { externalAuthId: identity.firebaseUid },
      select: safeUserSelect,
    });
    if (!user) throw new NotFoundException();
    return this.requireActive(user);
  }

  private requireActive(user: SafeUser): SafeUser {
    if (user.status !== 'ACTIVE') throw new ForbiddenException();
    return user;
  }
}
