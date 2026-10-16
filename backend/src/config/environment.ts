import { accessSync, constants, readFileSync, statSync } from 'node:fs';
import { isAbsolute, relative, resolve, sep } from 'node:path';
const MAX_CREDENTIAL_FILE_BYTES = 64 * 1024;
const outsideDirectory = (path: string): boolean =>
  path === '..' || path.startsWith('..' + sep) || isAbsolute(path);

export interface Environment {
  NODE_ENV: 'development' | 'test' | 'production';
  PORT: number;
  DATABASE_URL: string;
  POSTGRES_DB: string;
  POSTGRES_USER: string;
  POSTGRES_PASSWORD: string;
  REDIS_HOST: string;
  REDIS_PORT: number;
  CORS_ORIGINS: string[];
  FIREBASE_PROJECT_ID: string | undefined;
  GOOGLE_APPLICATION_CREDENTIALS: string | undefined;
}

export function validateEnvironment(
  input: Record<string, unknown>,
): Environment {
  const errors = new Set<string>();
  const required = (key: string): string => {
    const value = input[key];
    if (typeof value !== 'string' || !value.trim()) {
      errors.add(key);
      return '';
    }
    return value;
  };
  const port = (key: string, fallback?: string): number => {
    const value = input[key] ?? fallback;
    if (
      typeof value !== 'string' ||
      !/^\d+$/.test(value) ||
      Number(value) < 1 ||
      Number(value) > 65535
    ) {
      errors.add(key);
      return 0;
    }
    return Number(value);
  };
  const mode = input.NODE_ENV ?? 'development';
  if (
    typeof mode !== 'string' ||
    !['development', 'test', 'production'].includes(mode)
  )
    errors.add('NODE_ENV');
  const databaseUrl = required('DATABASE_URL');
  try {
    const url = new URL(databaseUrl);
    if (
      !['postgresql:', 'postgres:'].includes(url.protocol) ||
      !url.hostname ||
      !url.username ||
      !url.password ||
      url.pathname.length < 2
    )
      errors.add('DATABASE_URL');
  } catch {
    errors.add('DATABASE_URL');
  }
  const originsValue = input.CORS_ORIGINS ?? '';
  if (typeof originsValue !== 'string') errors.add('CORS_ORIGINS');
  const origins =
    typeof originsValue === 'string'
      ? originsValue
          .split(',')
          .map((value) => value.trim())
          .filter(Boolean)
      : [];
  for (const origin of origins) {
    try {
      const url = new URL(origin);
      if (
        !['http:', 'https:'].includes(url.protocol) ||
        url.origin !== origin ||
        url.username ||
        url.password ||
        (mode === 'production' && url.protocol !== 'https:')
      )
        errors.add('CORS_ORIGINS');
    } catch {
      errors.add('CORS_ORIGINS');
    }
  }
  const project = input.FIREBASE_PROJECT_ID;
  const projectId =
    project === undefined || project === ''
      ? undefined
      : typeof project === 'string'
        ? project
        : undefined;
  if (
    project !== undefined &&
    project !== '' &&
    (typeof project !== 'string' ||
      !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project))
  )
    errors.add('FIREBASE_PROJECT_ID');
  // The Admin SDK emulator accepts unsigned tokens; this API never enables it.
  if (input.FIREBASE_AUTH_EMULATOR_HOST)
    errors.add('FIREBASE_AUTH_EMULATOR_HOST');
  const credential = input.GOOGLE_APPLICATION_CREDENTIALS;
  const credentialPath =
    credential === undefined || credential === ''
      ? undefined
      : typeof credential === 'string'
        ? credential
        : undefined;
  if (credential !== undefined && credential !== '') {
    try {
      if (
        !credentialPath ||
        !isAbsolute(credentialPath) ||
        !projectId ||
        !statSync(credentialPath).isFile()
      )
        throw new Error();
      if (statSync(credentialPath).size > MAX_CREDENTIAL_FILE_BYTES)
        throw new Error();
      accessSync(credentialPath, constants.R_OK);
      const credentialFile: unknown = JSON.parse(
        readFileSync(credentialPath, 'utf8'),
      );
      if (
        typeof credentialFile !== 'object' ||
        credentialFile === null ||
        Array.isArray(credentialFile)
      )
        throw new Error();
      const repositoryRoot = resolve(__dirname, '../../..');
      const relativeToRepo = relative(repositoryRoot, credentialPath);
      const inRepository = !outsideDirectory(relativeToRepo);
      const relativeToSecrets = relative(
        resolve(repositoryRoot, 'backend/.credentials'),
        credentialPath,
      );
      if (inRepository && outsideDirectory(relativeToSecrets))
        throw new Error();
    } catch {
      errors.add('GOOGLE_APPLICATION_CREDENTIALS');
    }
  }
  const result: Environment = {
    FIREBASE_PROJECT_ID: projectId,
    GOOGLE_APPLICATION_CREDENTIALS: credentialPath,
    NODE_ENV: mode as Environment['NODE_ENV'],
    PORT: port('PORT', '3000'),
    DATABASE_URL: databaseUrl,
    POSTGRES_DB: required('POSTGRES_DB'),
    POSTGRES_USER: required('POSTGRES_USER'),
    POSTGRES_PASSWORD: required('POSTGRES_PASSWORD'),
    REDIS_HOST: required('REDIS_HOST'),
    REDIS_PORT: port('REDIS_PORT'),
    CORS_ORIGINS: [...new Set(origins)],
  };
  if (
    result.POSTGRES_PASSWORD === 'replace-with-local-password' ||
    databaseUrl.includes('replace-with-local-password')
  )
    errors.add('POSTGRES_PASSWORD');
  if (!/^[a-zA-Z0-9_.-]+$/.test(result.REDIS_HOST)) errors.add('REDIS_HOST');
  if (errors.size)
    throw new Error(
      'Invalid environment configuration: ' + [...errors].sort().join(', '),
    );
  return result;
}
