import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:eeelibrary/app/app.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/auth/domain/auth_models.dart';
import 'package:eeelibrary/features/auth/presentation/auth_scope.dart';
import 'package:eeelibrary/features/auth/widgets/auth_widgets.dart';

import 'support/auth_fakes.dart';

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
  await tester.pumpAndSettle();
  return router;
}

String path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;
void main() {
  testWidgets(
    'invalid credentials are inline and accessible without a modal or navigation',
    (tester) async {
      final h = AuthHarness();
      final router = await mount(tester, h, '/login');
      h.gateway.loginFailure = const AuthFailure(
        AuthFailureKind.invalidCredentials,
      );
      for (final pair in [
        ('Email Address', 'reader@fixture.example'),
        ('Password', 'Learning123'),
      ]) {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == pair.$1,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, pair.$2);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(path(router), '/login');
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsWidgets,
      );
    },
  );
  testWidgets(
    'network failures use a non-blocking warning banner and retain Login',
    (tester) async {
      final h = AuthHarness();
      final router = await mount(tester, h, '/login');
      h.gateway.loginFailure = const AuthFailure(AuthFailureKind.network);
      await h.controller.login('reader@fixture.example', 'fixture-password');
      await tester.pumpAndSettle();
      expect(path(router), '/login');
      expect(
        tester.widget<AuthFeedback>(find.byType(AuthFeedback)).tone,
        AuthFeedbackTone.notice,
      );
      expect(
        find.text(
          "We couldn't connect to EEELibrary. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(h.controller.busy, isFalse);
    },
  );
  for (final action in ['login', 'verification', 'restore']) {
    testWidgets(
      'fresh $action unauthorized response never claims an expired established session',
      (tester) async {
        final h = AuthHarness();
        if (action != 'login') {
          h.gateway.identity = FirebaseIdentity(
            uid: 'fixture-uid',
            emailVerified: action == 'restore',
          );
        }
        if (action == 'restore') {
          h.transport.responses.addAll([
            const ApiResponse(401, ''),
            const ApiResponse(401, ''),
          ]);
        }
        final router = await mount(
          tester,
          h,
          action == 'verification' ? '/verify-email' : '/login',
        );
        if (action != 'restore') {
          h.transport.responses.addAll([
            const ApiResponse(401, ''),
            const ApiResponse(401, ''),
          ]);
          if (action == 'verification') {
            h.gateway.verifiedAfterReload = true;
            await h.controller.checkVerification();
          } else {
            await h.controller.login(
              'reader@fixture.example',
              'fixture-password',
            );
          }
          await tester.pumpAndSettle();
        }
        expect(path(router), '/login');
        expect(h.controller.sessionExpired, isFalse);
        expect(
          find.text('Your session expired. Please sign in again.'),
          findsNothing,
        );
        expect(
          find.text('We could not complete sign-in. Please try again.'),
          findsOneWidget,
        );
        expect(h.gateway.signOuts, 1);
        expect(h.transport.requests, hasLength(2));
      },
    );
  }
  for (final entry in [
    (403, 'Account access unavailable'),
    (409, 'Account sign-in needs attention'),
    (503, 'Temporarily unavailable'),
  ]) {
    testWidgets(
      'backend ${entry.$1} retains safe Account Access messaging and retry',
      (tester) async {
        final h = AuthHarness();
        final router = await mount(tester, h, '/login');
        h.transport.responses.add(
          ApiResponse(entry.$1, 'raw internal token and account details'),
        );
        await h.controller.login('reader@fixture.example', 'fixture-password');
        await tester.pumpAndSettle();
        expect(path(router), '/auth-status');
        expect(find.text(entry.$2), findsOneWidget);
        expect(find.text('Account access'), findsOneWidget);
        expect(find.textContaining('raw internal'), findsNothing);
        expect(find.text('Try again'), findsOneWidget);
        expect(h.controller.user, isNull);
        expect(h.gateway.signOuts, 0);
        if (entry.$1 == 503) {
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.tap(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(path(router), '/home');
          expect(h.transport.requests.last.uri.path, '/api/v1/auth/me');
        }
      },
    );
  }
  testWidgets('Firebase disabled account also uses dedicated safe account UI', (
    tester,
  ) async {
    final h = AuthHarness();
    final router = await mount(tester, h, '/login');
    h.gateway.loginFailure = const AuthFailure(AuthFailureKind.disabled);
    await h.controller.login('reader@fixture.example', 'fixture-password');
    await tester.pumpAndSettle();
    expect(path(router), '/auth-status');
    expect(find.text('Account access unavailable'), findsOneWidget);
    expect(h.controller.user, isNull);
  });
  for (final status in ['DISABLED', 'SUSPENDED']) {
    testWidgets('$status DTO remains denied with dedicated access UI', (
      tester,
    ) async {
      final h = AuthHarness();
      final router = await mount(tester, h, '/login');
      h.transport.responses.add(ApiResponse(200, userBody(status: status)));
      await h.controller.login('reader@fixture.example', 'fixture-password');
      await tester.pumpAndSettle();
      expect(path(router), '/auth-status');
      expect(find.text('Account access unavailable'), findsOneWidget);
      expect(h.controller.user, isNull);
    });
  }
  testWidgets('reset email uses a generic accessible success banner', (
    tester,
  ) async {
    final h = AuthHarness();
    final router = await mount(tester, h, '/login');
    h.gateway.resetFailure = const AuthFailure(
      AuthFailureKind.invalidCredentials,
    );
    await h.controller.resetPassword('reader@fixture.example');
    await tester.pumpAndSettle();
    expect(path(router), '/login');
    expect(
      tester.widget<AuthFeedback>(find.byType(AuthFeedback)).tone,
      AuthFeedbackTone.success,
    );
    expect(find.textContaining('If this email can receive'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
  });
  testWidgets(
    'verification send and resend show calm success feedback with cooldown',
    (tester) async {
      final h = AuthHarness();
      await mount(tester, h, '/register');
      await h.controller.register(
        'Reader',
        'reader@fixture.example',
        'Learning123',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AuthFeedback>(find.byType(AuthFeedback)).tone,
        AuthFeedbackTone.success,
      );
      expect(find.textContaining('Verification email sent.'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Resend verification email'));
      await tester.tap(find.text('Resend verification email'));
      await tester.pumpAndSettle();
      expect(h.gateway.verifications, 2);
      expect(h.controller.canResend, isFalse);
      expect(h.controller.feedbackTone, AuthFeedbackTone.success);
      expect(find.textContaining('Verification email sent.'), findsOneWidget);
      await h.controller.signOut();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('Google cancellation remains quiet without banners or dialogs', (
    tester,
  ) async {
    final h = AuthHarness();
    final router = await mount(tester, h, '/login');
    h.gateway.googleCancelled = true;
    await h.controller.googleLogin();
    await tester.pumpAndSettle();
    expect(path(router), '/login');
    expect(h.controller.message, isNull);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });
  testWidgets(
    'expired backend-confirmed session announces a non-blocking SnackBar with Sign In',
    (tester) async {
      final h = AuthHarness();
      try {
        await tester.pumpWidget(EEELibraryApp(auth: h.controller));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        await h.controller.login('reader@fixture.example', 'fixture-password');
        await tester.pumpAndSettle();
        h.transport.responses.addAll([
          const ApiResponse(401, ''),
          const ApiResponse(401, ''),
        ]);
        await h.controller.refreshSession();
        await tester.pumpAndSettle();
        expect(h.controller.sessionExpired, isTrue);
        expect(h.controller.status, AuthStatus.signedOut);
        expect(h.controller.user, isNull);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text('Your session expired. Please sign in again.'),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.text('Sign In'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Welcome Back!'), findsOneWidget);
        expect(
          find.text('Your session expired. Please sign in again.'),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await h.gateway.close();
      }
    },
  );
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scene in ['login', 'network', 'register', 'verify', 'status']) {
      testWidgets(
        '$scene banner at $width with 2x text and keyboard is overflow-free',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final h = AuthHarness();
          if (scene == 'verify') {
            h.gateway.identity = const FirebaseIdentity(
              uid: 'fixture-uid',
              emailVerified: false,
            );
          }
          await mount(
            tester,
            h,
            scene == 'verify'
                ? '/verify-email'
                : scene == 'register'
                ? '/register'
                : '/login',
            scale: 2,
          );
          if (scene == 'verify') {
            await h.controller.resendVerification();
          } else if (scene == 'status') {
            h.transport.responses.add(const ApiResponse(503, ''));
            await h.controller.login(
              'reader@fixture.example',
              'fixture-password',
            );
          } else {
            h.gateway.loginFailure = AuthFailure(
              scene == 'network'
                  ? AuthFailureKind.network
                  : AuthFailureKind.invalidCredentials,
            );
            await h.controller.login(
              'reader@fixture.example',
              'fixture-password',
            );
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scene == 'login' || scene == 'network' || scene == 'register') {
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(find.byType(AuthFeedback));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byType(FilledButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scene == 'verify') {
            await h.controller.signOut();
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }
  for (final brightness in Brightness.values) {
    for (final tone in AuthFeedbackTone.values) {
      testWidgets(
        '$tone feedback has contrast, live semantics and reduced motion in $brightness',
        (tester) async {
          final theme = brightness == Brightness.light
              ? AppTheme.light
              : ThemeData.dark(useMaterial3: true);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: const MediaQueryData(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 288,
                      child: AuthFeedback(
                        message: 'Clear account feedback.',
                        tone: tone,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final text = tester.widget<Text>(
            find.text('Clear account feedback.'),
          );
          final box = tester.widget<DecoratedBox>(
            find.descendant(
              of: find.byType(AuthFeedback),
              matching: find.byType(DecoratedBox),
            ),
          );
          final foreground = text.style!.color!.computeLuminance();
          final background = (box.decoration as BoxDecoration).color!
              .computeLuminance();
          final contrast = (foreground > background
              ? (foreground + .05) / (background + .05)
              : (background + .05) / (foreground + .05));
          expect(contrast, greaterThanOrEqualTo(4.5));
          expect(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.liveRegion == true,
            ),
            findsOneWidget,
          );
          expect(
            tester.widget<AnimatedSize>(find.byType(AnimatedSize)).duration,
            Duration.zero,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('Google credential failure never blames email or password', (
    tester,
  ) async {
    final h = AuthHarness();
    final router = await mount(tester, h, '/login');
    h.gateway.googleFailure = const AuthFailure(
      AuthFailureKind.invalidCredentials,
    );
    await h.controller.googleLogin();
    await tester.pumpAndSettle();
    expect(path(router), '/login');
    expect(
      find.text('We could not complete Google sign-in. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Email or password is incorrect.'), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });
}
