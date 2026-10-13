import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/routing/app_routes.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/onboarding/welcome_screen.dart';
import 'package:eeelibrary/features/splash/splash_screen.dart';

void main() {
  Future<GoRouter> start(WidgetTester tester, String route) async {
    final router = createAppRouter(initialLocation: route);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pump();
    return router;
  }

  testWidgets('Splash transitions after two seconds', (tester) async {
    await start(tester, '/');
    expect(find.text('Learn ? Prepare ? Grow'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
  testWidgets('Disposed splash cancels timer', (tester) async {
    await start(tester, '/');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  for (final entry in [
    ('Get Started', '/register'),
    ('Sign In', '/login'),
    ('Browse as Guest', '/home'),
  ]) {
    testWidgets('Welcome action ${entry.$1}', (tester) async {
      final router = await start(tester, '/welcome');
      await tester.ensureVisible(find.text(entry.$1));
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        entry.$2,
      );
    });
  }
  testWidgets('Password visibility is interactive and auth is unavailable', (
    tester,
  ) async {
    await start(tester, '/login');
    final hidden = find.byWidgetPredicate(
      (w) => w is TextField && w.obscureText,
    );
    expect(hidden, findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(hidden, findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
  testWidgets('Terms checkbox changes without granting access', (tester) async {
    await start(tester, '/register');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
  testWidgets('Shared tabs navigate', (tester) async {
    final router = await start(tester, AppRoutes.home);
    for (final entry in [
      ('Explore', '/explore'),
      ('Library', '/library'),
      ('Profile', '/profile'),
      ('Home', '/home'),
    ]) {
      await tester.tap(find.text(entry.$1).last);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        entry.$2,
      );
    }
  });
  for (final route in [
    '/welcome',
    '/login',
    '/register',
    '/home',
    '/explore',
    '/library',
    '/profile',
    '/reader',
  ]) {
    testWidgets('$route fits small screens with enlarged text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = createAppRouter(initialLocation: route);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
