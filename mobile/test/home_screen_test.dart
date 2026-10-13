import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/home/data/mock_home_data.dart';
import 'package:eeelibrary/features/home/widgets/book_card.dart';
import 'package:eeelibrary/features/home/widgets/category_card.dart';
import 'package:eeelibrary/features/home/widgets/compact_book_card.dart';
import 'package:eeelibrary/features/home/widgets/home_header.dart';
import 'package:eeelibrary/features/home/widgets/home_search_bar.dart';
import 'package:eeelibrary/features/home/widgets/promo_banner.dart';
import 'package:eeelibrary/features/home/widgets/quick_access_item.dart';

void main() {
  Future<GoRouter> start(
    WidgetTester tester, {
    String route = '/home',
    double scale = 1,
  }) async {
    final router = createAppRouter(initialLocation: route);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 50,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home header, search and promotion are discoverable', (
    tester,
  ) async {
    await start(tester);
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(find.text('EEELibrary'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Open profile'), findsOneWidget);
    expect(find.byType(HomeSearchBar), findsOneWidget);
    expect(find.text('Search books, notes, MCQ, jobs...'), findsOneWidget);
    await reveal(tester, find.byType(PromoBanner));
    expect(find.text('Get Up to 50% OFF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Complete home at $size, text scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await start(tester, scale: scale);
        expect(tester.takeException(), isNull);
        for (final section in [
          'Categories',
          'Featured Books',
          'Recommended for You',
          'Quick Access',
        ]) {
          await reveal(tester, find.text(section));
          expect(find.text(section), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (section == 'Categories') {
            await reveal(tester, find.text('PDF Notes'));
            expect(find.byType(CategoryCard), findsNWidgets(8));
            for (final category in MockHomeData.categories) {
              expect(find.text(category.title), findsOneWidget);
            }
          } else if (section == 'Featured Books') {
            await reveal(tester, find.text(MockHomeData.featured.first.title));
            expect(find.byType(BookCard), findsNWidgets(4));
            expect(find.text('\u09F3320'), findsOneWidget);
            await tester.ensureVisible(
              find.text(MockHomeData.featured.last.title),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          } else if (section == 'Recommended for You') {
            await reveal(
              tester,
              find.text(MockHomeData.recommended.first.title),
            );
            expect(find.byType(CompactBookCard), findsNWidgets(4));
            await tester.ensureVisible(
              find.text(MockHomeData.recommended.last.title),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          } else {
            await reveal(tester, find.text('Downloads'));
            expect(find.byType(QuickAccessItem), findsNWidgets(6));
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  for (final entry in [
    ('Explore', '/explore'),
    ('Library', '/library'),
    ('Profile', '/profile'),
  ]) {
    testWidgets('Home tab to ${entry.$1} and back to home', (tester) async {
      final router = await start(tester);
      await tester.tap(find.text(entry.$1).last);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        entry.$2,
      );
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
      expect(find.byType(HomeHeader), findsOneWidget);
    });
  }
  testWidgets('Promo and category actions use existing explore route', (
    tester,
  ) async {
    final router = await start(tester);
    await reveal(tester, find.text('Explore Now'));
    await tester.tap(find.text('Explore Now'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/explore',
    );
    router.go('/home');
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Academic'));
    await tester.tap(find.text('Academic'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/explore',
    );
  });
  testWidgets(
    'Search and wishlist placeholders never change navigation or access',
    (tester) async {
      final router = await start(tester);
      await tester.tap(find.text('Search books, notes, MCQ, jobs...'));
      await tester.pumpAndSettle();
      expect(find.text('Search will be available soon.'), findsOneWidget);
      await reveal(
        tester,
        find.byTooltip('Save Electrical Circuit Analysis to wishlist'),
      );
      await tester.tap(
        find.byTooltip('Save Electrical Circuit Analysis to wishlist'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wishlist will be available soon.'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Profile push and system back retain home; auth back remains welcome',
    (tester) async {
      final router = await start(tester);
      router.push('/profile');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/home',
      );
      router.go('/welcome');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/welcome',
      );
    },
  );
}
