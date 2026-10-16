import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/auth/domain/auth_models.dart';

import 'support/auth_fakes.dart';

void main() {
  late AuthHarness h;
  setUp(() {
    h = AuthHarness();
  });
  tearDown(() => h.dispose());
  test(
    'startup stays initializing until Firebase reports the initial state',
    () {
      expect(h.controller.status, AuthStatus.initializing);
      expect(h.controller.user, isNull);
      expect(h.transport.requests, isEmpty);
    },
  );
  test('signed-out startup performs no backend request', () async {
    await h.start();
    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.transport.requests, isEmpty);
  });
  test(
    'existing verified Firebase user must pass me before authenticated state',
    () async {
      h.gateway.identity = const FirebaseIdentity(
        uid: 'existing',
        emailVerified: true,
      );
      h.transport.wait = Completer<ApiResponse>();
      h.controller.start();
      await h.settle();
      expect(h.controller.busy, isTrue);
      expect(h.controller.user, isNull);
      h.transport.wait!.complete(ApiResponse(200, userBody()));
      await h.settle();
      expect(h.controller.status, AuthStatus.authenticated);
      expect(h.transport.requests.single.uri.path, '/api/v1/auth/me');
    },
  );
  test('restore bootstraps only if me reports a missing local user', () async {
    h.gateway.identity = const FirebaseIdentity(
      uid: 'existing',
      emailVerified: true,
    );
    h.transport.responses.add(
      const ApiResponse(404, 'private response ignored'),
    );
    await h.start();
    expect(h.controller.status, AuthStatus.authenticated);
    expect(h.transport.requests.map((r) => r.method), ['GET', 'POST']);
  });
  test('login signs into Firebase then bootstraps exactly once', () async {
    await h.start();
    await h.controller.login(' reader@fixture.example ', 'fixture-password');
    expect(h.gateway.logins, 1);
    expect(h.gateway.lastEmail, 'reader@fixture.example');
    expect(h.transport.requests.single.method, 'POST');
    expect(h.transport.requests.single.uri.path, '/api/v1/auth/bootstrap');
    expect(h.controller.status, AuthStatus.authenticated);
    expect(h.controller.user!.id, 'application-user-id');
  });
  test(
    'failed Firebase login stays signed out and never reaches backend',
    () async {
      await h.start();
      h.gateway.loginFailure = const AuthFailure(
        AuthFailureKind.invalidCredentials,
      );
      await h.controller.login('reader@fixture.example', 'wrong');
      expect(h.controller.status, AuthStatus.signedOut);
      expect(h.controller.busy, isFalse);
      expect(h.transport.requests, isEmpty);
    },
  );
  test(
    'duplicate login submissions are serialized and inputs are not resent',
    () async {
      await h.start();
      h.gateway.loginWait = Completer<void>();
      final first = h.controller.login(
        'reader@fixture.example',
        'fixture-password',
      );
      await h.controller.login('reader@fixture.example', 'fixture-password');
      expect(h.gateway.logins, 1);
      h.gateway.loginWait!.complete();
      await first;
      expect(h.transport.requests, hasLength(1));
    },
  );
  test('one 401 refreshes once and retries once', () async {
    await h.start();
    h.transport.responses.add(const ApiResponse(401, 'sensitive body ignored'));
    await h.controller.login('reader@fixture.example', 'fixture-password');
    expect(h.gateway.refreshes, [false, true]);
    expect(h.transport.requests, hasLength(2));
    expect(h.controller.status, AuthStatus.authenticated);
  });
  test('second 401 cannot loop and clears local access/signs out', () async {
    await h.start();
    h.transport.responses.addAll([
      const ApiResponse(401, ''),
      const ApiResponse(401, ''),
    ]);
    await h.controller.login('reader@fixture.example', 'fixture-password');
    expect(h.gateway.refreshes, [false, true]);
    expect(h.gateway.signOuts, 1);
    expect(h.controller.user, isNull);
    expect(h.controller.status, AuthStatus.signedOut);
  });
  for (final status in [403, 409, 503]) {
    test(
      'backend $status denies app access without raw error disclosure',
      () async {
        await h.start();
        h.transport.responses.add(
          ApiResponse(status, 'private backend fixture-token'),
        );
        await h.controller.login('reader@fixture.example', 'fixture-password');
        expect(h.controller.status, AuthStatus.error);
        expect(h.controller.user, isNull);
        expect(h.controller.message, isNot(contains('private')));
        expect(h.controller.message, isNot(contains('fixture-token')));
        expect(h.controller.busy, isFalse);
      },
    );
  }
  for (final state in ['DISABLED', 'SUSPENDED']) {
    test('non-active server DTO $state never authenticates', () async {
      await h.start();
      h.transport.responses.add(ApiResponse(200, userBody(status: state)));
      await h.controller.login('reader@fixture.example', 'fixture-password');
      expect(h.controller.status, AuthStatus.error);
      expect(h.controller.user, isNull);
    });
  }
  test('registration sends verification but defers bootstrap until refreshed proof', () async {
    await h.start();
    await h.controller.register(
      ' Reader ',
      ' reader@fixture.example ',
      'fixture-password',
    );
    expect(h.gateway.registrations, 1);
    expect(h.gateway.verifications, 1);
    expect(h.controller.status, AuthStatus.verificationRequired);
    expect(h.transport.requests, isEmpty);
    expect(h.gateway.lastName, 'Reader');
    h.gateway.verifiedAfterReload = true;
    await h.controller.checkVerification();
    expect(h.gateway.reloads, 1);
    expect(h.gateway.refreshes.first, isTrue);
    expect(h.transport.requests.single.uri.path, '/api/v1/auth/bootstrap');
    expect(h.controller.status, AuthStatus.authenticated);
  });
  test('failed verification send keeps the actual created account in verification state', () async {
    await h.start();
    h.gateway.verificationFailure = const AuthFailure(AuthFailureKind.network);
    await h.controller.register(
      'Reader',
      'reader@fixture.example',
      'fixture-password',
    );
    expect(h.gateway.currentUser, isNotNull);
    expect(h.controller.status, AuthStatus.verificationRequired);
    expect(h.controller.canResend, isTrue);
    expect(h.transport.requests, isEmpty);
  });
  test(
    'unverified startup avoids backend calls and uses explicit reload checks',
    () async {
      h.gateway.identity = const FirebaseIdentity(
        uid: 'existing',
        emailVerified: false,
      );
      await h.start();
      await h.controller.checkVerification();
      expect(h.controller.status, AuthStatus.verificationRequired);
      expect(h.gateway.reloads, 1);
      expect(h.transport.requests, isEmpty);
    },
  );
  test(
    'resend is cooldown-limited and cannot repeatedly send on double taps',
    () async {
      await h.start();
      await h.controller.register(
        'Reader',
        'reader@fixture.example',
        'fixture-password',
      );
      await h.controller.resendVerification();
      expect(h.gateway.verifications, 1);
      expect(h.controller.canResend, isFalse);
    },
  );
  test('Google cancellation is quiet and cannot bootstrap', () async {
    await h.start();
    h.gateway.googleCancelled = true;
    await h.controller.googleLogin();
    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.message, isNull);
    expect(h.transport.requests, isEmpty);
  });
  test(
    'Google authentication establishes backend application identity',
    () async {
      await h.start();
      await h.controller.googleLogin();
      expect(h.gateway.googleLogins, 1);
      expect(h.transport.requests.single.method, 'POST');
      expect(h.controller.status, AuthStatus.authenticated);
    },
  );
  test(
    'logout clears application state without deleting any server data',
    () async {
      await h.start();
      await h.controller.login('reader@fixture.example', 'fixture-password');
      await h.controller.signOut();
      expect(h.controller.status, AuthStatus.signedOut);
      expect(h.controller.user, isNull);
      expect(h.gateway.currentUser, isNull);
      expect(h.transport.requests, hasLength(1));
    },
  );
  test(
    'password reset gives the same confirmation for an unknown account',
    () async {
      await h.start();
      h.gateway.resetFailure = const AuthFailure(
        AuthFailureKind.invalidCredentials,
      );
      await h.controller.resetPassword('reader@fixture.example');
      expect(h.gateway.resets, 1);
      expect(h.controller.message, contains('If this email'));
      expect(h.controller.status, AuthStatus.signedOut);
    },
  );
  test(
    'rebuilds cannot trigger me calls and explicit resume check runs only once',
    () async {
      await h.start();
      await h.controller.login('reader@fixture.example', 'fixture-password');
      h.transport.wait = Completer<ApiResponse>();
      final check = h.controller.refreshSession();
      await h.controller.refreshSession();
      expect(h.transport.requests, hasLength(2));
      h.transport.wait!.complete(ApiResponse(200, userBody()));
      await check;
    },
  );
  test('an account switch during a backend request cannot authenticate the wrong identity', () async {
    await h.start();
    h.transport.wait = Completer<ApiResponse>();
    final login = h.controller.login(
      'reader@fixture.example',
      'fixture-password',
    );
    await h.settle();
    h.gateway.identity = const FirebaseIdentity(
      uid: 'another',
      emailVerified: true,
    );
    h.transport.wait!.complete(ApiResponse(200, userBody()));
    await login;
    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.user, isNull);
  });
  test('Firebase stream failure during bootstrap cannot be overwritten by a late successful DTO', () async {
    final h = AuthHarness();
    await h.start();
    h.transport.wait = Completer<ApiResponse>();
    final pending = h.controller.login(
      'reader@fixture.example',
      'fixture-password',
    );
    await h.settle();
    h.gateway.events.addError(StateError('raw fixture error'));
    await h.settle();
    expect(h.controller.status, AuthStatus.error);
    expect(h.controller.user, isNull);
    h.transport.wait!.complete(ApiResponse(200, userBody()));
    await pending;
    expect(h.controller.status, AuthStatus.error);
    expect(h.controller.user, isNull);
    expect(h.controller.busy, isFalse);
    expect(h.controller.message, isNot(contains('raw fixture')));
    await h.dispose();
  });
}
