import 'dotenv/config';
import { ConfigService } from '@nestjs/config';
import {
  applicationDefault,
  deleteApp,
  initializeApp,
} from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { validateEnvironment, Environment } from '../config/environment';
import { PrismaService } from '../database/prisma.service';
import { AdminRole } from '../generated/prisma/enums';
export function parseOperatorArgs(args: string[]) {
  if (
    args.length !== 4 ||
    !['provision', 'disable'].includes(args[0] ?? '') ||
    args[1] !== '--uid' ||
    !args[2] ||
    !/^[^\s\p{Cc}]{1,128}$/u.test(args[2]) ||
    !args[3]
  )
    throw new Error(
      'Usage: admin:operator -- provision|disable --uid UID ROLE|CONFIRM',
    );
  const [action, , uid, value] = args;
  if (
    action === 'provision' &&
    !Object.values(AdminRole).includes(value as AdminRole)
  )
    throw new Error('Invalid role');
  if (action === 'disable' && value !== 'CONFIRM')
    throw new Error('Explicit CONFIRM required');
  return { action, uid, value };
}
export async function runOperator(args: string[]) {
  const input = parseOperatorArgs(args);
  const env = validateEnvironment(process.env);
  if (!env.FIREBASE_PROJECT_ID) throw new Error('Firebase project required');
  const app = initializeApp(
    { projectId: env.FIREBASE_PROJECT_ID, credential: applicationDefault() },
    'eeelibrary-operator',
  );
  const db = new PrismaService(new ConfigService<Environment, true>(env));
  try {
    await db.onModuleInit();
    if (input.action === 'disable') {
      await db.adminUser.update({
        where: { externalAuthId: input.uid },
        data: { status: 'DISABLED' },
      });
    } else {
      const identity = await getAuth(app).getUser(input.uid);
      if (identity.disabled || !identity.emailVerified || !identity.email)
        throw new Error(
          'An enabled verified-email Firebase identity is required',
        );
      // Explicit operator-only target and role. No ordinary User writes, no browser endpoint.
      await db.adminUser.upsert({
        where: { externalAuthId: input.uid },
        create: {
          externalAuthId: input.uid,
          email: identity.email.toLowerCase(),
          displayName: (
            identity.displayName || 'EEELibrary administrator'
          ).slice(0, 120),
          role: input.value as AdminRole,
          status: 'ACTIVE',
        },
        update: {
          role: input.value as AdminRole,
          status: 'ACTIVE',
          email: identity.email.toLowerCase(),
        },
      });
    }
    console.log('Explicit admin operator action completed.');
  } finally {
    await db.onModuleDestroy();
    await deleteApp(app);
  }
}
if (require.main === module)
  void runOperator(process.argv.slice(2)).catch(() => {
    console.error(
      'Admin operator action failed. Verify arguments, Firebase identity, configuration and database availability.',
    );
    process.exitCode = 1;
  });
