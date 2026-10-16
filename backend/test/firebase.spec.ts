import { ConfigService } from '@nestjs/config';
import {
  applicationDefault,
  deleteApp,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import { Auth, DecodedIdToken, getAuth } from 'firebase-admin/auth';
import {
  ForbiddenException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { FirebaseService } from '../src/firebase/firebase.service';
import { Environment, validateEnvironment } from '../src/config/environment';
import { recordAuthDiagnostic } from '../src/common/auth-diagnostics';
jest.mock('../src/common/auth-diagnostics', () => ({
  recordAuthDiagnostic: jest.fn(),
}));

jest.mock('firebase-admin/app', () => ({
  applicationDefault: jest.fn(() => ({})),
  getApps: jest.fn(() => []),
  initializeApp: jest.fn((options: unknown, name: string) => ({
    options,
    name,
  })),
  deleteApp: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('firebase-admin/auth', () => ({ getAuth: jest.fn() }));

const claims = (): DecodedIdToken => {
  const now = Math.floor(Date.now() / 1000);
  return {
    uid: 'verified-uid',
    sub: 'verified-uid',
    aud: 'eeelibrary-test',
    iss: 'https://securetoken.google.com/eeelibrary-test',
    exp: now + 3600,
    iat: now - 30,
    auth_time: now - 60,
    email: 'Reader@fixture.example',
    email_verified: true,
    name: ' Reader ',
    firebase: { identities: {}, sign_in_provider: 'password' },
    admin: true,
  };
};
const config = (project = 'eeelibrary-test') =>
  new ConfigService<Environment, true>(
    validateEnvironment({ ...process.env, FIREBASE_PROJECT_ID: project }),
  );

describe('Firebase SDK boundary and verified identity', () => {
  const verify = jest.fn<Promise<DecodedIdToken>, [string, boolean?]>();
  let service: FirebaseService;
  beforeEach(() => {
    jest.mocked(getApps).mockReturnValue([]);
    jest
      .mocked(getAuth)
      .mockReturnValue({ verifyIdToken: verify } as unknown as Auth);
    verify.mockReset().mockResolvedValue(claims());
    service = new FirebaseService(config());
  });
  afterEach(async () => {
    await service.onModuleDestroy();
  });
  it('initializes once, uses ADC and reuses the SDK across requests', async () => {
    await service.verifyIdToken('fixture-token-one');
    await service.verifyIdToken('fixture-token-two');
    expect(initializeApp).toHaveBeenCalledTimes(1);
    expect(applicationDefault).toHaveBeenCalledTimes(1);
    expect(verify).toHaveBeenNthCalledWith(1, 'fixture-token-one', true);
    expect(verify).toHaveBeenNthCalledWith(2, 'fixture-token-two', true);
  });
  it('returns only controlled fields and ignores admin/token custom claims', async () => {
    const identity = await service.verifyIdToken('fixture-token');
    expect(identity).toEqual({
      firebaseUid: 'verified-uid',
      email: 'reader@fixture.example',
      displayName: 'Reader',
    });
    expect(Object.isFrozen(identity)).toBe(true);
  });
  it.each([
    'auth/invalid-id-token',
    'auth/id-token-expired',
    'auth/id-token-revoked',
    'auth/user-disabled',
    'auth/argument-error',
  ])('sanitizes %s as 401', async (code) => {
    verify.mockRejectedValue(
      Object.assign(new Error('private SDK token fixture-token'), { code }),
    );
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    await expect(service.verifyIdToken('fixture-token')).rejects.toThrow(
      'Unauthorized',
    );
  });
  it('sanitizes credential/network errors as unavailable, not bad identity', async () => {
    verify.mockRejectedValue(
      new Error('private credential path/token fixture-token'),
    );
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
  it.each(['uid', 'sub', 'aud', 'iss', 'exp', 'iat', 'auth_time'])(
    'rejects missing required %s claim',
    async (field) => {
      const decoded: Record<string, unknown> = { ...claims() };
      delete decoded[field];
      verify.mockResolvedValue(decoded as unknown as DecodedIdToken);
      await expect(
        service.verifyIdToken('fixture-token'),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    },
  );
  it.each([
    ['uid', ''],
    ['uid', 'x'.repeat(129)],
    ['sub', 'different-uid'],
    ['aud', 'another-project'],
    ['iss', 'https://securetoken.google.com/another-project'],
    ['exp', 0],
    ['exp', '9999999999'],
    ['iat', 9999999999],
    ['auth_time', 9999999999],
  ])('rejects invalid %s identity claim', async (field, value) => {
    verify.mockResolvedValue({ ...claims(), [field]: value });
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
  it.each([
    { email_verified: false },
    { email_verified: 'true' },
    { email: undefined },
    { email: 'not-an-email' },
    { email: ' reader@fixture.example ' },
  ])('requires a valid explicitly verified email', async (invalid) => {
    verify.mockResolvedValue({ ...claims(), ...invalid } as DecodedIdToken);
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('rejects tenant-scoped identities because UID alone is not tenant-safe', async () => {
    verify.mockResolvedValue({
      ...claims(),
      firebase: { ...claims().firebase, tenant: 'unsupported-tenant' },
    });
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
  it('rejects a malformed decoded payload rather than leaking a runtime error', async () => {
    verify.mockResolvedValue(null as unknown as DecodedIdToken);
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
  it('uses a safe fallback name and bounds identity metadata', async () => {
    verify.mockResolvedValue({ ...claims(), name: null });
    expect((await service.verifyIdToken('fixture-token')).displayName).toBe(
      'EEELibrary Reader',
    );
    verify.mockResolvedValue({ ...claims(), name: 'x'.repeat(200) });
    expect(
      (await service.verifyIdToken('fixture-token')).displayName,
    ).toHaveLength(120);
  });

  it('bounds names by Unicode characters without splitting surrogate pairs', async () => {
    const symbol = String.fromCodePoint(0x1f4da);
    verify.mockResolvedValue({ ...claims(), name: symbol.repeat(121) });
    expect((await service.verifyIdToken('fixture-token')).displayName).toBe(
      symbol.repeat(120),
    );
  });
  it('fails closed when Firebase is unconfigured without initializing an app', async () => {
    const before = jest.mocked(initializeApp).mock.calls.length;
    const inactive = new FirebaseService(config(''));
    await expect(
      inactive.verifyIdToken('fixture-token'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(initializeApp).toHaveBeenCalledTimes(before);
  });
  it('reuses only the same-project named app and does not delete a borrowed app', async () => {
    const existing = initializeApp(
      { projectId: 'eeelibrary-test' },
      'eeelibrary-backend',
    );
    jest.mocked(getApps).mockReturnValue([existing]);
    const reused = new FirebaseService(config());
    const before = jest.mocked(deleteApp).mock.calls.length;
    await reused.onModuleDestroy();
    expect(deleteApp).toHaveBeenCalledTimes(before);
    jest
      .mocked(getApps)
      .mockReturnValue([
        { ...existing, options: { projectId: 'wrong-project' } },
      ]);
    expect(() => new FirebaseService(config())).toThrow(
      'Firebase initialization failed',
    );
  });
  it('identifies the measured 118-second clock skew without accepting future-issued claims', async () => {
    const issuedAtGoogle = Math.floor(Date.now() / 1000) + 118;
    const fresh = {
      ...claims(),
      iat: issuedAtGoogle,
      auth_time: issuedAtGoogle,
      exp: issuedAtGoogle + 3600,
    };
    verify.mockResolvedValue(fresh);
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(recordAuthDiagnostic).toHaveBeenLastCalledWith({
      event: 'verification-rejected',
      reason: 'issued-in-future',
    });
    const actualNow = Date.now();
    const time = jest.spyOn(Date, 'now').mockReturnValue(actualNow + 120_000);
    try {
      await expect(
        service.verifyIdToken('fixture-token'),
      ).resolves.toMatchObject({ firebaseUid: 'verified-uid' });
    } finally {
      time.mockRestore();
    }
    expect(verify).toHaveBeenLastCalledWith('fixture-token', true);
  });
  it('separately identifies future authentication time and missing Admin permission', async () => {
    verify.mockResolvedValue({
      ...claims(),
      auth_time: Math.floor(Date.now() / 1000) + 118,
    });
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(recordAuthDiagnostic).toHaveBeenLastCalledWith({
      event: 'verification-rejected',
      reason: 'authenticated-in-future',
    });
    verify.mockRejectedValue(
      Object.assign(new Error('raw credential fixture'), {
        code: 'auth/insufficient-permission',
      }),
    );
    await expect(service.verifyIdToken('fixture-token')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(recordAuthDiagnostic).toHaveBeenLastCalledWith({
      event: 'verification-rejected',
      reason: 'admin-permission-denied',
    });
  });
});
