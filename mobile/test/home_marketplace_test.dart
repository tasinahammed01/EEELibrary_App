import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/catalog/domain/catalog_models.dart';
import 'package:eeelibrary/features/home/widgets/home_book_shelf.dart';
import 'package:eeelibrary/features/home/widgets/home_header.dart';
import 'package:eeelibrary/features/home/widgets/home_shortcuts.dart';

import 'support/catalog_fakes.dart';

const categories = [
  CatalogCategory(id: '1', slug: 'circuit-theory', name: 'Circuit Theory'),
  CatalogCategory(id: '2', slug: 'electronics', name: 'Electronics'),
  CatalogCategory(id: '3', slug: 'machines', name: 'Electrical Machines'),
  CatalogCategory(id: '4', slug: 'power', name: 'Power Systems'),
  CatalogCategory(id: '5', slug: 'control', name: 'Control Systems'),
  CatalogCategory(id: '6', slug: 'signals', name: 'Signals and Systems'),
  CatalogCategory(id: '7', slug: 'communication', name: 'Communication'),
  CatalogCategory(id: '8', slug: 'job-prep', name: 'Job Preparation'),
  CatalogCategory(id: '9', slug: 'extra', name: 'Additional Subject'),
];
final books = List.generate(
  8,
  (i) => CatalogBook(
    slug: 'resource-$i',
    title: '${categories[i].name} Study Guide for EEE',
    description: 'Development resource',
    category: categories[i],
    price: i == 0 ? '0.00' : '150.00',
    currency: 'BDT',
  ),
);
FakeCatalog repository() => FakeCatalog()
  ..categoriesHandler = (() => Future.value(categories))
  ..booksHandler = ((p, s, c, o) => Future.value(
    CatalogPage(items: books, page: 1, total: 8, hasMore: false),
  ))
  ..bookHandler = ((slug) =>
      Future.value(books.firstWhere((b) => b.slug == slug)));

void main() {
  Future<GoRouter> start(
    WidgetTester tester, {
    double scale = 1,
    FakeCatalog? fake,
  }) async {
    final router = createAppRouter(
      initialLocation: '/home',
      catalog: fake ?? repository(),
    );
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
    return router;
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Eight-category two-shelf Home at $width, scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await start(tester, scale: scale);
        await reveal(tester, find.byType(HomeCategoryGrid));
        expect(
          find.byKey(const ValueKey('catalog-category-extra')),
          findsNothing,
        );
        for (final category in categories.take(8)) {
          await reveal(
            tester,
            find.byKey(ValueKey('catalog-category-${category.slug}')),
          );
          expect(tester.takeException(), isNull);
        }
        await reveal(tester, find.text('Latest books'));
        await reveal(
          tester,
          find.byKey(const ValueKey('catalog-book-resource-3')),
        );
        expect(find.text('BDT 150.00'), findsWidgets);
        await reveal(tester, find.text('Discover more'));
        await reveal(
          tester,
          find.byKey(const ValueKey('catalog-book-resource-7')),
        );
        expect(find.byType(HomeBookCover), findsWidgets);
        await reveal(tester, find.byType(HomeQuickAccess));
        await reveal(tester, find.text('Downloads'));
        expect(find.text('Coming soon'), findsNWidgets(6));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Compact header and hero CTA are reachable on Small Phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = await start(tester);
    expect(
      tester.getSize(find.byType(HomeHeader)).height,
      lessThanOrEqualTo(64),
    );
    expect(find.text('Explore Now').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Explore Now'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/explore');
  });
  testWidgets('Compact shelf card opens real details and back returns Home', (
    tester,
  ) async {
    final router = await start(tester);
    await reveal(tester, find.byKey(const ValueKey('catalog-book-resource-7')));
    await tester.tap(find.byKey(const ValueKey('catalog-book-resource-7')));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/books/resource-7',
    );
    expect(find.text('Book details'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final label in [
    'Syllabus',
    'Previous Questions',
    'Bookmarks',
    'Free Samples',
    'Wishlist',
    'Downloads',
  ]) {
    testWidgets('$label offers safe, accessible availability feedback', (
      tester,
    ) async {
      final router = await start(tester);
      await reveal(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('$label will be available soon.'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/home');
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('$label will be available soon.'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantics.properties.liveRegion, isTrue);
    });
  }
  testWidgets('Both See All actions keep browsing on the existing route', (
    tester,
  ) async {
    final router = await start(tester);
    await reveal(tester, find.text('Latest books'));
    final section = find
        .ancestor(of: find.text('Latest books'), matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: section, matching: find.text('See All')),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/explore');
  });
  testWidgets('Home card and utility semantics have real tap actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(tester);
      await reveal(
        tester,
        find.byKey(const ValueKey('catalog-book-resource-0')),
      );
      final card = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('catalog-book-resource-0')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(card.properties.onTap, isNotNull);
      expect(card.properties.label, contains('Free'));
      await reveal(tester, find.text('Downloads'));
      final utility = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Downloads, coming soon',
        ),
      );
      expect(utility.properties.onTap, isNotNull);
      expect(utility.properties.label, contains('coming soon'));
    } finally {
      semantics.dispose();
    }
  });
  testWidgets(
    'Rebuild and shelf scrolling do not fetch additional catalog data',
    (tester) async {
      final fake = repository();
      await start(tester, fake: fake);
      await reveal(
        tester,
        find.byKey(const ValueKey('catalog-book-resource-7')),
      );
      await tester.pump();
      expect(fake.requests, 1);
      expect(find.textContaining('4.8'), findsNothing);
      expect(find.textContaining('Recommended for You'), findsNothing);
      expect(find.text('Cart'), findsNothing);
    },
  );
  for (final width in [0.0, 120.0, 200.0]) {
    testWidgets(
      'Shortcut grid handles tight width $width without negative constraints',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: HomeShortcutGrid(
                    children: const [
                      SizedBox(height: 48),
                      SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
