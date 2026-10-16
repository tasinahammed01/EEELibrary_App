import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/auth/domain/auth_models.dart';

import 'support/auth_fakes.dart';

const signedIn = FirebaseIdentity(uid: 'fixture-uid', emailVerified: true);
void main() {
  late AuthHarness h;
  setUp(() {
    h = AuthHarness();
  });
  tearDown(() => h.dispose());
  test(
    'signed-in event during interactive login does not restore concurrently',
    () async {
      await h.start();
      h.gateway.loginWait = Completer<void>();
      final login = h.controller.login(
        'reader@fixture.example',
        'fixture-password',
      );
      h.gateway.identity = signedIn;
      h.gateway.events.add(signedIn);
      await h.settle();
      expect(h.controller.busy, isTrue);
      expect(h.transport.requests, isEmpty);
      h.gateway.loginWait!.complete();
      await login;
      await h.settle();
      expect(h.controller.status, AuthStatus.authenticated);
      expect(h.gateway.signOuts, 0);
      expect(h.transport.requests.map((r) => r.uri.path), [
        '/api/v1/auth/bootstrap',
      ]);
    },
  );
  test('late signed-in notification cannot duplicate restoration', () async {
    await h.start();
    await h.controller.login('reader@fixture.example', 'fixture-password');
    h.gateway.events.add(h.gateway.identity);
    await h.settle();
    expect(h.controller.status, AuthStatus.authenticated);
    expect(h.transport.requests, hasLength(1));
  });
  test('stale null snapshot cannot overwrite successful bootstrap with a live Firebase session', () async {
    await h.start();
    await h.controller.login('reader@fixture.example', 'fixture-password');
    h.gateway.events.add(null);
    await h.settle();
    expect(h.controller.status, AuthStatus.authenticated);
    expect(h.controller.user, isNotNull);
    expect(h.gateway.signOuts, 0);
    expect(h.transport.requests, hasLength(1));
  });
  test(
    'verification events around refresh produce exactly one bootstrap',
    () async {
      h.gateway.identity = const FirebaseIdentity(
        uid: 'fixture-uid',
        emailVerified: false,
      );
      await h.start();
      h.gateway.verifiedAfterReload = true;
      final check = h.controller.checkVerification();
      h.gateway.events.add(h.gateway.identity);
      await check;
      h.gateway.events.add(h.gateway.identity);
      await h.settle();
      expect(h.controller.status, AuthStatus.authenticated);
      expect(h.gateway.refreshes.first, isTrue);
      expect(h.transport.requests.map((r) => r.uri.path), [
        '/api/v1/auth/bootstrap',
      ]);
      expect(h.gateway.signOuts, 0);
    },
  );
  test(
    'late null after persistent 401 preserves the visible failure',
    () async {
      await h.start();
      h.transport.responses.addAll([
        const ApiResponse(401, ''),
        const ApiResponse(401, ''),
      ]);
      await h.controller.login('reader@fixture.example', 'fixture-password');
      final message = h.controller.message;
      expect(message, isNotNull);
      h.gateway.events.add(null);
      await h.settle();
      expect(h.controller.status, AuthStatus.signedOut);
      expect(h.controller.message, message);
      expect(h.gateway.signOuts, 1);
      expect(h.gateway.refreshes, [false, true]);
    },
  );
  for (final status in [403, 409, 503]) {
    test(
      'late same-user event after $status cannot silently retry denied bootstrap',
      () async {
        await h.start();
        h.transport.responses.add(ApiResponse(status, ''));
        await h.controller.login('reader@fixture.example', 'fixture-password');
        final message = h.controller.message;
        h.gateway.events.add(h.gateway.identity);
        await h.settle();
        expect(h.controller.status, AuthStatus.error);
        expect(h.controller.message, message);
        expect(h.transport.requests, hasLength(1));
        expect(h.gateway.signOuts, 0);
      },
    );
  }
  test('genuine Firebase loss clears the established session', () async {
    await h.start();
    await h.controller.login('reader@fixture.example', 'fixture-password');
    h.gateway.identity = null;
    h.gateway.events.add(null);
    await h.settle();
    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.user, isNull);
  });
  test('delayed old-user event after logout cannot restore', () async {
    await h.start();
    await h.controller.login('reader@fixture.example', 'fixture-password');
    await h.controller.signOut();
    h.gateway.events.add(signedIn);
    await h.settle();
    expect(h.controller.status, AuthStatus.signedOut);
    expect(h.controller.user, isNull);
    expect(h.transport.requests, hasLength(1));
    expect(h.gateway.signOuts, 1);
  });
  test(
    'verification cannot bootstrap a different UID that appears during reload',
    () async {
      h.gateway.identity = const FirebaseIdentity(
        uid: 'fixture-uid',
        emailVerified: false,
      );
      await h.start();
      h.gateway.verifiedAfterReload = true;
      final check = h.controller.checkVerification();
      h.gateway.identity = const FirebaseIdentity(
        uid: 'another-user',
        emailVerified: true,
      );
      h.gateway.events.add(h.gateway.identity);
      await check;
      expect(h.controller.status, AuthStatus.signedOut);
      expect(h.controller.user, isNull);
      expect(h.gateway.signOuts, 1);
      expect(h.transport.requests, isEmpty);
    },
  );
  test('idle UID switch closes old application access until the new backend identity is confirmed', () async {
    await h.start();
    await h.controller.login('reader@fixture.example', 'fixture-password');
    h.transport.wait = Completer<ApiResponse>();
    h.gateway.identity = const FirebaseIdentity(
      uid: 'another-user',
      emailVerified: true,
    );
    h.gateway.events.add(h.gateway.identity);
    await h.settle();
    expect(h.controller.status, AuthStatus.initializing);
    expect(h.controller.user, isNull);
    h.transport.wait!.complete(ApiResponse(200, userBody()));
    await h.settle();
    expect(h.controller.status, AuthStatus.authenticated);
  });
}
