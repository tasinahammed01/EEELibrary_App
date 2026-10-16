import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/home/widgets/home_book_shelf.dart';
import 'package:eeelibrary/features/home/widgets/home_header.dart';
import 'package:eeelibrary/features/home/widgets/home_search_bar.dart';
import 'package:eeelibrary/features/home/widgets/promo_banner.dart';

import 'support/catalog_fakes.dart';

void main() {
  Future<GoRouter> start(
    WidgetTester tester, {
    String route = '/home',
    double scale = 1,
  }) async {
    final router = createAppRouter(
      initialLocation: route,
      catalog: FakeCatalog(),
    );
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
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home header, search and honest promotion are discoverable', (
    tester,
  ) async {
    await start(tester);
    expect(find.byType(HomeHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeHeader),
        matching: find.text('EEELibrary'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.byTooltip('Open profile'), findsOneWidget);
    expect(find.byType(HomeSearchBar), findsOneWidget);
    await reveal(tester, find.byType(PromoBanner));
    expect(find.text('Build your EEE bookshelf'), findsOneWidget);
    expect(find.textContaining('50%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Complete real-data home at $size, text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await start(tester, scale: scale);
        await reveal(tester, find.text('Categories'));
        for (final category in fixtureCategories) {
          await reveal(
            tester,
            find.byKey(ValueKey('catalog-category-${category.slug}')),
          );
          expect(find.text(category.name), findsWidgets);
        }
        await reveal(tester, find.text('Latest books'));
        await reveal(
          tester,
          find.byKey(const ValueKey('catalog-book-study-guide-0')),
        );
        expect(find.byType(HomeBookCover), findsWidgets);
        expect(find.text('Free'), findsOneWidget);
        await reveal(
          tester,
          find.byKey(const ValueKey('catalog-book-study-guide-3')),
        );
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('Quick Access'));
        await reveal(tester, find.text('Downloads'));
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final entry in [
    ('Explore', '/explore'),
    ('Library', '/library'),
    ('Profile', '/profile'),
  ]) {
    testWidgets('Home tab to ${entry.$1} and back', (tester) async {
      final router = await start(tester);
      await tester.tap(find.text(entry.$1).last);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, entry.$2);
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(HomeHeader), findsOneWidget);
    });
  }
  testWidgets('Promo and category actions open real Explore filters', (
    tester,
  ) async {
    final router = await start(tester);
    await reveal(tester, find.text('Explore Now'));
    await tester.tap(find.text('Explore Now'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/explore');
    router.go('/home');
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('catalog-category-circuit')),
    );
    await tester.tap(find.byKey(const ValueKey('catalog-category-circuit')));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.queryParameters['category'],
      'circuit',
    );
  });
  testWidgets(
    'Search opens Explore and card opens details without granting access',
    (tester) async {
      final router = await start(tester);
      await tester.tap(find.text('Search books, notes, MCQ, jobs...'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/explore');
      router.go('/home');
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.byKey(const ValueKey('catalog-book-study-guide-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey('catalog-book-study-guide-0')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Book details'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/books/study-guide-0',
      );
      expect(find.text('Read now'), findsNothing);
    },
  );
  testWidgets('Profile push and back retain Home; auth back remains Welcome', (
    tester,
  ) async {
    final router = await start(tester);
    router.push('/profile');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    router.go('/welcome');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/welcome');
  });
}
