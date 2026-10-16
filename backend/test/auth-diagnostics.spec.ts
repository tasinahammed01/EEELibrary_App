import { ConsoleLogger } from '@nestjs/common';
import {
  authDiagnosticsEnabled,
  recordAuthDiagnostic,
} from '../src/common/auth-diagnostics';

describe('safe opt-in authentication diagnostics', () => {
  const previousMode = process.env.NODE_ENV;
  const previousFlag = process.env.AUTH_DEBUG_DIAGNOSTICS;
  afterEach(() => {
    process.env.NODE_ENV = previousMode;
    if (previousFlag === undefined) delete process.env.AUTH_DEBUG_DIAGNOSTICS;
    else process.env.AUTH_DEBUG_DIAGNOSTICS = previousFlag;
    jest.restoreAllMocks();
  });
  it.each(['production', 'test'])(
    'never emits in %s even with the flag enabled',
    (mode) => {
      process.env.NODE_ENV = mode;
      process.env.AUTH_DEBUG_DIAGNOSTICS = 'true';
      const log = jest
        .spyOn(ConsoleLogger.prototype, 'log')
        .mockImplementation(() => undefined);
      recordAuthDiagnostic({
        event: 'verification-rejected',
        reason: 'issued-in-future',
      });
      expect(authDiagnosticsEnabled()).toBe(false);
      expect(log).not.toHaveBeenCalled();
    },
  );
  it('requires explicit opt-in and reconstructs only safe fields', () => {
    process.env.NODE_ENV = 'development';
    delete process.env.AUTH_DEBUG_DIAGNOSTICS;
    const log = jest
      .spyOn(ConsoleLogger.prototype, 'log')
      .mockImplementation(() => undefined);
    recordAuthDiagnostic({
      event: 'verification-rejected',
      reason: 'issued-in-future',
    });
    expect(log).not.toHaveBeenCalled();
    process.env.AUTH_DEBUG_DIAGNOSTICS = 'true';
    const extra = {
      event: 'http-response' as const,
      route: '/api/v1/auth/bootstrap' as const,
      status: 401,
      password: 'private-fixture-password',
      authorization: 'private-fixture-token',
    };
    recordAuthDiagnostic(extra);
    expect(log).toHaveBeenCalledWith(
      JSON.stringify({
        event: 'http-response',
        route: '/api/v1/auth/bootstrap',
        status: 401,
      }),
    );
  });
});
