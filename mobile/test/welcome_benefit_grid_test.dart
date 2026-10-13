import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/features/onboarding/widgets/welcome_benefit_grid.dart';

void main() {
  Future<void> pumpGrid(WidgetTester tester, double width, double scale) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const WelcomeBenefitGrid(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [
    0.0,
    1.0,
    7.0,
    48.0,
    200.0,
    240.0,
    320.0,
    360.0,
    390.0,
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('grid at width $width, text scale $scale', (tester) async {
        await pumpGrid(tester, width, scale);
        expect(tester.takeException(), isNull);
        final cards = find.byType(WelcomeBenefitCard);
        if (width < 48) {
          expect(cards, findsNothing);
        } else {
          expect(cards, findsNWidgets(4));
          final first = tester.getRect(cards.at(0));
          final second = tester.getRect(cards.at(1));
          if (width <= 240) {
            expect(second.top, greaterThan(first.bottom));
            expect(second.left, first.left);
            expect(first.width, width);
          } else {
            expect(second.top, first.top);
            expect(second.left, greaterThan(first.right));
            expect(first.width, closeTo(second.width, .001));
          }
          for (var index = 0; index < 4; index++) {
            final rect = tester.getRect(cards.at(index));
            expect(rect.width.isFinite, isTrue);
            expect(rect.width, greaterThanOrEqualTo(0));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
          }
          await tester.ensureVisible(cards.last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        for (final box in tester.renderObjectList<RenderBox>(
          find.byType(SizedBox),
        )) {
          expect(box.constraints.isNormalized, isTrue);
          expect(box.constraints.minWidth, greaterThanOrEqualTo(0));
        }
      });
    }
  }

  testWidgets(
    'grid recovers when width changes from zero to narrow to two columns',
    (tester) async {
      for (final width in [0.0, 200.0, 360.0, 0.0, 240.0, 390.0]) {
        await pumpGrid(tester, width, 1);
        expect(tester.takeException(), isNull);
        expect(
          find.byType(WelcomeBenefitCard),
          width == 0 ? findsNothing : findsNWidgets(4),
        );
      }
    },
  );

  testWidgets('unbounded horizontal parent receives a finite grid width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: WelcomeBenefitGrid(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeBenefitCard), findsNWidgets(4));
    expect(
      tester.getSize(find.byType(WelcomeBenefitGrid)).width.isFinite,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [200.0, 240.0]) {
    testWidgets(
      'Welcome at width $width, short viewport and enlarged text remains scrollable',
      (tester) async {
        tester.view.physicalSize = Size(width, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = createAppRouter(initialLocation: '/welcome');
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WelcomeBenefitCard), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        for (final label in ['Get Started', 'Browse as Guest']) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text(label).hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
