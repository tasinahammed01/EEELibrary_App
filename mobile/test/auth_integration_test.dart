import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:eeelibrary/app/initialization_failure_app.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/auth/domain/auth_models.dart';
import 'package:eeelibrary/features/auth/presentation/auth_scope.dart';
import 'package:eeelibrary/features/auth/widgets/auth_widgets.dart';

import 'support/auth_fakes.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.pumpAndSettle();
  await tester.enterText(field(label), value);
  await tester.pumpAndSettle();
}

Future<GoRouter> mount(
  WidgetTester tester,
  AuthHarness h,
  String path, {
  double scale = 1,
}) async {
  h.controller.start();
  await tester.pump();
  await tester.pump();
  final router = createAppRouter(initialLocation: path, auth: h.controller);
  addTearDown(h.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AuthScope(
      controller: h.controller,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  if (path == '/') {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return router;
}

String location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;
Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('initialization failure is deliberate, safe, and retryable', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(InitializationFailureApp(onRetry: () => retries++));
    expect(
      find.textContaining('could not start sign-in safely'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'invalid login blocks calls; valid submit calls Firebase and bootstrap once then Home',
    (tester) async {
      final h = AuthHarness();
      final router = await mount(tester, h, '/login');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await fill(tester, 'Email Address', 'broken');
      await fill(tester, 'Password', 'Learning123');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(h.gateway.logins, 0);
      await fill(tester, 'Email Address', 'reader@fixture.example');
      await press(tester, find.byType(FilledButton));
      expect(h.gateway.logins, 1);
      expect(h.transport.requests.length, 1);
      expect(location(router), '/home');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending login disables edits, social, account switch and back; failure restores controls and input',
    (tester) async {
      final h = AuthHarness();
      h.gateway.loginWait = Completer<void>();
      h.gateway.loginFailure = const AuthFailure(AuthFailureKind.network);
      final router = await mount(tester, h, '/login');
      await fill(tester, 'Email Address', 'reader@fixture.example');
      await fill(tester, 'Password', 'Learning123');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(h.gateway.logins, 1);
      expect(tester.widget<TextField>(field('Email Address')).enabled, isFalse);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Back',
              ),
            )
            .onPressed,
        isNull,
      );
      final switchButton = find.descendant(
        of: find.byType(AuthAccountSwitch),
        matching: find.byType(TextButton),
      );
      expect(tester.widget<TextButton>(switchButton).onPressed, isNull);
      h.gateway.loginWait!.complete();
      await tester.pumpAndSettle();
      expect(location(router), '/login');
      expect(
        tester.widget<TextField>(field('Password')).controller!.text,
        'Learning123',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(
        find.text(const AuthFailure(AuthFailureKind.network).message),
        findsOneWidget,
      );
    },
  );
  for (final code in [403, 409, 503]) {
    testWidgets(
      'backend $code routes to safe access screen and cannot reach Home',
      (tester) async {
        final h = AuthHarness();
        h.transport.responses.add(
          ApiResponse(code, 'raw confidential backend error'),
        );
        final router = await mount(tester, h, '/login');
        await fill(tester, 'Email Address', 'reader@fixture.example');
        await fill(tester, 'Password', 'Learning123');
        await press(tester, find.byType(FilledButton));
        expect(location(router), '/auth-status');
        router.go('/home');
        await tester.pumpAndSettle();
        expect(location(router), '/auth-status');
        expect(find.textContaining('confidential'), findsNothing);
        await press(tester, find.text('Sign out'));
        expect(location(router), '/welcome');
      },
    );
  }
  testWidgets(
    'registration requires matching passwords and terms, verifies before bootstrap, then Home',
    (tester) async {
      final h = AuthHarness();
      final router = await mount(tester, h, '/register');
      await fill(tester, 'Full Name', 'Reader');
      await fill(tester, 'Email Address', 'reader@fixture.example');
      await fill(tester, 'Password', 'Learning123');
      await fill(tester, 'Confirm Password', 'Different123');
      await press(tester, find.byType(CheckboxListTile));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await fill(tester, 'Confirm Password', 'Learning123');
      await press(tester, find.byType(CheckboxListTile));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await press(tester, find.byType(CheckboxListTile));
      await press(tester, find.byType(FilledButton));
      expect(location(router), '/verify-email');
      expect(h.gateway.registrations, 1);
      expect(h.gateway.verifications, 1);
      expect(h.transport.requests, isEmpty);
      expect(find.textContaining('Check your inbox'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      h.gateway.verifiedAfterReload = true;
      await press(tester, find.byType(FilledButton));
      expect(h.gateway.reloads, 1);
      expect(h.transport.requests.single.uri.path, '/api/v1/auth/bootstrap');
      expect(location(router), '/home');
    },
  );
  testWidgets(
    'Google cancellation remains usable; success reaches Home and Profile logout returns Welcome',
    (tester) async {
      final h = AuthHarness();
      h.gateway.googleCancelled = true;
      final router = await mount(tester, h, '/login');
      await press(tester, find.byType(OutlinedButton));
      expect(location(router), '/login');
      expect(h.controller.message, isNull);
      expect(h.transport.requests, isEmpty);
      h.gateway.googleCancelled = false;
      await press(tester, find.byType(OutlinedButton));
      expect(location(router), '/home');
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Reader'), findsOneWidget);
      await press(tester, find.text('Sign Out'));
      expect(h.gateway.signOuts, 1);
      expect(h.controller.user, isNull);
      expect(location(router), '/welcome');
    },
  );
  testWidgets(
    'password reset validates email and shows generic success without login',
    (tester) async {
      final h = AuthHarness();
      final router = await mount(tester, h, '/login');
      await press(tester, find.text('Forgot Password?'));
      expect(h.gateway.resets, 0);
      await fill(tester, 'Email Address', 'reader@fixture.example');
      await press(tester, find.text('Forgot Password?'));
      expect(h.gateway.resets, 1);
      expect(h.gateway.logins, 0);
      expect(location(router), '/login');
      expect(find.textContaining('If this email can receive'), findsOneWidget);
    },
  );
  testWidgets('signed-out guests retain Home while reader redirects to login', (
    tester,
  ) async {
    final h = AuthHarness();
    final router = await mount(tester, h, '/welcome');
    await press(tester, find.text('Browse as Guest'));
    expect(location(router), '/home');
    expect(h.transport.requests, isEmpty);
    for (final path in ['/explore', '/library', '/profile']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(location(router), path);
    }
    router.go('/reader');
    await tester.pumpAndSettle();
    expect(location(router), '/login');
  });
  for (final verified in [false, true]) {
    testWidgets(
      'existing Firebase session startup verified=$verified honors splash and backend state',
      (tester) async {
        final h = AuthHarness();
        h.gateway.identity = FirebaseIdentity(
          uid: 'existing',
          emailVerified: verified,
          email: 'reader@fixture.example',
        );
        final router = await mount(tester, h, '/');
        expect(location(router), '/');
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(location(router), verified ? '/home' : '/verify-email');
        expect(h.transport.requests.length, verified ? 1 : 0);
      },
    );
  }
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final path in [
        '/login',
        '/register',
        '/verify-email',
        '/auth-status',
      ]) {
        testWidgets(
          'live auth $path width=$width scale=$scale is scrollable and keyboard safe',
          (tester) async {
            tester.view.physicalSize = Size(width, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetViewInsets);
            final h = AuthHarness();
            if (path == '/verify-email') {
              h.gateway.identity = const FirebaseIdentity(
                uid: 'existing',
                emailVerified: false,
                email: 'reader@fixture.example',
              );
            }
            if (path == '/auth-status') {
              h.gateway.identity = const FirebaseIdentity(
                uid: 'existing',
                emailVerified: true,
              );
              h.transport.responses.add(const ApiResponse(503, 'ignored'));
            }
            await mount(tester, h, path, scale: scale);
            expect(tester.takeException(), isNull);
            if (path == '/login' || path == '/register') {
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              await tester.pumpAndSettle();
              final lastField = find.byType(TextFormField).last;
              await tester.ensureVisible(lastField);
              await tester.tap(lastField);
              await tester.enterText(lastField, 'Learning123');
              await tester.pumpAndSettle();
              expect(tester.getRect(lastField).bottom, lessThanOrEqualTo(360));
            }
            await tester.ensureVisible(find.byType(FilledButton));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'verification rejected twice routes to Login with accessible persistent feedback',
    (tester) async {
      final h = AuthHarness();
      h.gateway.identity = const FirebaseIdentity(
        uid: 'fixture-uid',
        emailVerified: false,
      );
      h.gateway.verifiedAfterReload = true;
      h.transport.responses.addAll([
        const ApiResponse(401, 'private'),
        const ApiResponse(401, 'private'),
      ]);
      final router = await mount(tester, h, '/verify-email');
      await press(tester, find.byType(FilledButton));
      expect(location(router), '/login');
      expect(h.gateway.signOuts, 1);
      h.gateway.events.add(null);
      await tester.pumpAndSettle();
      expect(location(router), '/login');
      expect(h.controller.message, isNotNull);
      expect(find.text(h.controller.message!), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsWidgets,
      );
    },
  );
  testWidgets(
    'late signed-out event cannot hide failed login; successful retry clears the error and reaches Home',
    (tester) async {
      final h = AuthHarness();
      h.gateway.loginFailure = const AuthFailure(
        AuthFailureKind.invalidCredentials,
      );
      final router = await mount(tester, h, '/login');
      await fill(tester, 'Email Address', 'reader@fixture.example');
      await fill(tester, 'Password', 'Learning123');
      await press(tester, find.byType(FilledButton));
      h.gateway.events.add(null);
      await tester.pumpAndSettle();
      expect(location(router), '/login');
      expect(find.text(h.controller.message!), findsOneWidget);
      h.gateway.loginFailure = null;
      await press(tester, find.byType(FilledButton));
      h.gateway.events.add(h.gateway.identity);
      await tester.pumpAndSettle();
      expect(location(router), '/home');
      expect(h.controller.message, isNull);
      expect(h.transport.requests, hasLength(1));
    },
  );
}
