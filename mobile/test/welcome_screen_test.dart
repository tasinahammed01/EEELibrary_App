import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/onboarding/widgets/welcome_benefit_grid.dart';
import 'package:eeelibrary/features/onboarding/widgets/welcome_hero.dart';

void main() {
  testWidgets('Registered hero bundle decodes the supplied PNG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(manifest.listAssets(), contains(WelcomeHero.assetPath));
      final bytes = await rootBundle.load(WelcomeHero.assetPath);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, WelcomeHero.sourceWidth);
      expect(frame.image.height, WelcomeHero.sourceHeight);
      frame.image.dispose();
      codec.dispose();
    });
  });

  for (final size in [
    const Size(320, 480),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Welcome composition and reachable actions at $size, scale $scale',
        (tester) async {
          tester.view.physicalSize = size;
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
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 32, bottom: 24),
                ),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('EEELibrary'), findsOneWidget);
          expect(
            find.text('Buy EEE Books, Notes\n& Job Prep Resources'),
            findsOneWidget,
          );
          expect(find.text('Sign In'), findsOneWidget);
          expect(
            tester.getRect(find.text('Sign In')).top,
            greaterThanOrEqualTo(32),
          );
          expect(find.byType(WelcomeBenefitCard), findsNWidgets(4));
          for (final title in [
            'Wide Academic Collection',
            'Job Preparation',
            'Instant Access',
            'Secure Reading',
          ]) {
            expect(find.text(title), findsOneWidget);
          }
          final image = tester.widget<Image>(
            find.descendant(
              of: find.byType(WelcomeHero),
              matching: find.byType(Image),
            ),
          );
          expect(image.fit, BoxFit.contain);
          expect(image.excludeFromSemantics, isTrue);
          expect(image.image, isA<ResizeImage>());
          final provider = image.image as ResizeImage;
          expect(
            (provider.imageProvider as AssetImage).assetName,
            WelcomeHero.assetPath,
          );
          final heroRect = tester.getRect(
            find.descendant(
              of: find.byType(WelcomeHero),
              matching: find.byType(Image),
            ),
          );
          expect(heroRect.width / heroRect.height, closeTo(4 / 3, .001));
          expect(heroRect.width, lessThanOrEqualTo(360));
          final cards = find.byType(WelcomeBenefitCard);
          for (var index = 0; index < 4; index++) {
            final rect = tester.getRect(cards.at(index));
            expect(rect.left, greaterThanOrEqualTo(16));
            expect(rect.right, lessThanOrEqualTo(size.width - 16));
          }
          expect(
            tester.getRect(cards.at(0)).top,
            tester.getRect(cards.at(1)).top,
          );
          expect(
            tester.getRect(cards.at(2)).top,
            tester.getRect(cards.at(3)).top,
          );
          for (final label in ['Get Started', 'Browse as Guest']) {
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            expect(find.text(label).hitTestable(), findsOneWidget);
            expect(
              tester.getRect(find.text(label)).bottom,
              lessThanOrEqualTo(size.height - 24),
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
