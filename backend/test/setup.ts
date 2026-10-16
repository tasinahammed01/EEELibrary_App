// Unit/HTTP suites cannot reach Firebase infrastructure; override this boundary explicitly.
jest.mock('firebase-admin/auth', () => ({
  getAuth: jest.fn(() => {
    throw new Error('Mock FirebaseService or getAuth in unit tests');
  }),
}));
delete process.env.FIREBASE_PROJECT_ID;
delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
Object.assign(process.env, {
  NODE_ENV: 'test',
  // Empty values block dotenv from importing real local Firebase config into unit tests.
  FIREBASE_PROJECT_ID: '',
  GOOGLE_APPLICATION_CREDENTIALS: '',
  FIREBASE_AUTH_EMULATOR_HOST: '',
  PORT: '3000',
  DATABASE_URL:
    'postgresql://test_user:test_fixture_password@127.0.0.1:5433/test_database',
  POSTGRES_DB: 'test_database',
  POSTGRES_USER: 'test_user',
  POSTGRES_PASSWORD: 'test_fixture_password',
  REDIS_HOST: '127.0.0.1',
  REDIS_PORT: '6380',
  CORS_ORIGINS: 'http://localhost:5173',
});
