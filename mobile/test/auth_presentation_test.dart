import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final route in ['/welcome', '/login', '/register']) {
        testWidgets('$route at width $width and text scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 700);
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
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final lastAction = find.text(
            route == '/welcome'
                ? 'Browse as Guest'
                : route == '/login'
                ? 'Create Account'
                : 'Sign In',
          );
          await tester.ensureVisible(lastAction);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          if (route != '/welcome') {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            addTearDown(tester.view.resetViewInsets);
            await tester.pumpAndSettle();
            final fields = find.byType(TextFormField);
            await tester.ensureVisible(fields.last);
            await tester.tap(fields.last);
            await tester.enterText(fields.last, 'Learning123!');
            await tester.pumpAndSettle();
            final fieldRect = tester.getRect(fields.last);
            expect(fieldRect.bottom, lessThanOrEqualTo(400));
            expect(fieldRect.top, greaterThanOrEqualTo(0));
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(lastAction);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
  testWidgets('Both registration password toggles retain their text', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/register');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    for (final label in ['Password', 'Confirm Password']) {
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Learning123!');
      await tester.pumpAndSettle();
      final toggle = find.byTooltip('Show ${label.toLowerCase()}');
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isFalse);
      expect(tester.widget<TextField>(field).controller!.text, 'Learning123!');
      await tester.ensureVisible(find.byTooltip('Hide ${label.toLowerCase()}'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide ${label.toLowerCase()}'));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, isTrue);
    }
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
