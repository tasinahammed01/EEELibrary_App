import { mkdtempSync, writeFileSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { validateEnvironment } from '../src/config/environment';

const valid = (): Record<string, unknown> => ({ ...process.env });
describe('environment validation', () => {
  it('accepts valid test configuration and returns typed ports/origins', () => {
    expect(validateEnvironment(valid())).toMatchObject({
      NODE_ENV: 'test',
      PORT: 3000,
      REDIS_PORT: 6380,
      CORS_ORIGINS: ['http://localhost:5173'],
    });
  });
  it.each([
    'DATABASE_URL',
    'POSTGRES_DB',
    'POSTGRES_USER',
    'POSTGRES_PASSWORD',
    'REDIS_HOST',
    'REDIS_PORT',
  ])('rejects missing %s', (key) => {
    const env = valid();
    delete env[key];
    expect(() => validateEnvironment(env)).toThrow(key);
  });
  it.each(['0', '-1', '65536', '3000extra', 'NaN'])(
    'rejects invalid port %s',
    (value) => {
      expect(() => validateEnvironment({ ...valid(), PORT: value })).toThrow(
        'PORT',
      );
    },
  );
  it.each([
    '*',
    'https://example.com/path',
    'https://user:secret@example.com',
    'javascript:alert(1)',
  ])('rejects unsafe origin %s', (value) => {
    expect(() =>
      validateEnvironment({ ...valid(), CORS_ORIGINS: value }),
    ).toThrow('CORS_ORIGINS');
  });
  it('rejects non-string origins', () => {
    expect(() => validateEnvironment({ ...valid(), CORS_ORIGINS: [] })).toThrow(
      'CORS_ORIGINS',
    );
  });
  it('requires HTTPS browser origins in production', () => {
    expect(() =>
      validateEnvironment({ ...valid(), NODE_ENV: 'production' }),
    ).toThrow('CORS_ORIGINS');
    expect(
      validateEnvironment({
        ...valid(),
        NODE_ENV: 'production',
        CORS_ORIGINS: 'https://eeelibrary.example',
      }).NODE_ENV,
    ).toBe('production');
  });
  it('denies cross-origin browser access by default', () => {
    expect(
      validateEnvironment({ ...valid(), CORS_ORIGINS: '' }).CORS_ORIGINS,
    ).toEqual([]);
  });
  it('rejects placeholder passwords', () => {
    expect(() =>
      validateEnvironment({
        ...valid(),
        POSTGRES_PASSWORD: 'replace-with-local-password',
      }),
    ).toThrow('POSTGRES_PASSWORD');
  });
  it.each([
    'https://private:secret@example.com/db',
    'postgresql://localhost/db',
    'not-a-url',
  ])('rejects invalid database URL without exposing it', (DATABASE_URL) => {
    expect(() => validateEnvironment({ ...valid(), DATABASE_URL })).toThrow(
      'Invalid environment configuration: DATABASE_URL',
    );
  });
  it('rejects unknown runtime modes', () => {
    expect(() =>
      validateEnvironment({ ...valid(), NODE_ENV: 'unsafe' }),
    ).toThrow('NODE_ENV');
  });

  it('allows the infrastructure to boot with authentication unconfigured', () => {
    expect(
      validateEnvironment({ ...valid(), FIREBASE_PROJECT_ID: '' })
        .FIREBASE_PROJECT_ID,
    ).toBeUndefined();
  });
  it('accepts an explicit valid Firebase project ID', () => {
    expect(
      validateEnvironment({
        ...valid(),
        FIREBASE_PROJECT_ID: 'eeelibrary-production',
      }).FIREBASE_PROJECT_ID,
    ).toBe('eeelibrary-production');
  });
  it.each(['Invalid Project', 'short', '-invalid-project', 'project/', 123])(
    'rejects invalid Firebase project configuration',
    (FIREBASE_PROJECT_ID) => {
      expect(() =>
        validateEnvironment({ ...valid(), FIREBASE_PROJECT_ID }),
      ).toThrow('FIREBASE_PROJECT_ID');
    },
  );
  it('rejects the unsigned-token emulator configuration even in development', () => {
    expect(() =>
      validateEnvironment({
        ...valid(),
        FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
      }),
    ).toThrow('FIREBASE_AUTH_EMULATOR_HOST');
  });
  it.each([
    'relative-private-file.json',
    'C:/nonexistent/private-service-account.json',
  ])(
    'rejects unsafe ADC paths without disclosing them',
    (GOOGLE_APPLICATION_CREDENTIALS) => {
      expect(() =>
        validateEnvironment({
          ...valid(),
          FIREBASE_PROJECT_ID: 'eeelibrary-test',
          GOOGLE_APPLICATION_CREDENTIALS,
        }),
      ).toThrow(
        'Invalid environment configuration: GOOGLE_APPLICATION_CREDENTIALS',
      );
    },
  );

  it('accepts accessible ADC JSON outside the repository and rejects malformed contents safely', () => {
    const folder = mkdtempSync(join(tmpdir(), 'eeelibrary-config-'));
    const path = join(folder, 'adc-fixture.json');
    try {
      writeFileSync(path, JSON.stringify({ type: 'external_account' }));
      expect(
        validateEnvironment({
          ...valid(),
          FIREBASE_PROJECT_ID: 'eeelibrary-test',
          GOOGLE_APPLICATION_CREDENTIALS: path,
        }).GOOGLE_APPLICATION_CREDENTIALS,
      ).toBe(path);
      writeFileSync(path, 'invalid-private-fixture');
      expect(() =>
        validateEnvironment({
          ...valid(),
          FIREBASE_PROJECT_ID: 'eeelibrary-test',
          GOOGLE_APPLICATION_CREDENTIALS: path,
        }),
      ).toThrow(
        'Invalid environment configuration: GOOGLE_APPLICATION_CREDENTIALS',
      );
    } finally {
      unlinkSync(path);
      rmdirSync(folder);
    }
  });
  it('rejects an ADC credential file outside the repository secret directory', () => {
    const path = resolve('unsafe-credential-fixture.json');
    try {
      writeFileSync(path, JSON.stringify({ type: 'external_account' }));
      expect(() =>
        validateEnvironment({
          ...valid(),
          FIREBASE_PROJECT_ID: 'eeelibrary-test',
          GOOGLE_APPLICATION_CREDENTIALS: path,
        }),
      ).toThrow('GOOGLE_APPLICATION_CREDENTIALS');
    } finally {
      unlinkSync(path);
    }
  });

  it('does not treat a repository filename starting with two dots as outside the repository', () => {
    const path = resolve('..', '..unsafe-credential-fixture.json');
    try {
      writeFileSync(path, JSON.stringify({ type: 'external_account' }));
      expect(() =>
        validateEnvironment({
          ...valid(),
          FIREBASE_PROJECT_ID: 'eeelibrary-test',
          GOOGLE_APPLICATION_CREDENTIALS: path,
        }),
      ).toThrow('GOOGLE_APPLICATION_CREDENTIALS');
    } finally {
      unlinkSync(path);
    }
  });
});
