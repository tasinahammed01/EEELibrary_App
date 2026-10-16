import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/core/config/api_config.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/catalog/book_details_screen.dart';
import 'package:eeelibrary/features/catalog/data/catalog_repository.dart';
import 'package:eeelibrary/features/catalog/domain/catalog_models.dart';
import 'package:eeelibrary/features/catalog/presentation/catalog_controller.dart';
import 'package:eeelibrary/features/catalog/widgets/catalog_widgets.dart';
import 'package:eeelibrary/features/explore/explore_screen.dart';
import 'package:eeelibrary/features/home/home_screen.dart';
import 'package:eeelibrary/features/home/widgets/home_book_shelf.dart';

import 'support/catalog_fakes.dart';

class ProbeTransport implements ApiTransport {
  ApiResponse response = const ApiResponse(200, '[]');
  Map<String, String>? headers;
  Uri? uri;
  bool closed = false;
  bool fail = false;
  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    if (fail) throw StateError('private transport detail');
    expect(method, 'GET');
    this.uri = uri;
    this.headers = headers;
    return response;
  }

  @override
  void close() {
    closed = true;
  }
}

Map<String, dynamic> bookJson() => {
  'slug': 'circuit',
  'title': 'Circuit Theory',
  'description': 'Study resource',
  'price': '120.00',
  'currency': 'BDT',
  'pageCount': 120,
  'category': {'id': 'id', 'slug': 'circuit', 'name': 'Circuits'},
};
void main() {
  test('summary does not require description; details do', () {
    final summary = bookJson()..remove('description');
    expect(CatalogBook.fromJson(summary).description, isEmpty);
    expect(
      () => CatalogBook.fromJson(summary, details: true),
      throwsFormatException,
    );
  });
  test(
    'transport exceptions and malformed JSON become safe failures',
    () async {
      final transport = ProbeTransport()..fail = true;
      final api = CatalogApi(
        config: ApiConfig('http://localhost:3000'),
        transport: transport,
      );
      await expectLater(api.categories(), throwsA(isA<CatalogFailure>()));
      transport
        ..fail = false
        ..response = const ApiResponse(200, 'invalid json');
      await expectLater(api.categories(), throwsA(isA<CatalogFailure>()));
    },
  );
  test(
    'sort and refresh use the selected filter without duplicate calls',
    () async {
      final fake = FakeCatalog();
      final controller = CatalogController(fake);
      await controller.initialize();
      expect(fake.requests, 1);
      controller.setCategory('power');
      await Future<void>.delayed(Duration.zero);
      controller.setSort('price-asc');
      await Future<void>.delayed(Duration.zero);
      expect(fake.category, 'power');
      expect(fake.sort, 'price-asc');
      await controller.refresh();
      expect(fake.requests, 4);
      controller.dispose();
    },
  );
  test('detail controller ignores a response after disposal', () async {
    final pending = Completer<CatalogBook>();
    final fake = FakeCatalog()..bookHandler = ((slug) => pending.future);
    final controller = BookDetailsController(fake, 'book');
    final loading = controller.load();
    controller.dispose();
    pending.complete(fixtureBooks.first);
    await loading;
    expect(controller.book, isNull);
  });

  test('parses decimal price, category and optional pages safely', () {
    final b = CatalogBook.fromJson(bookJson());
    expect(b.priceLabel, 'BDT 120.00');
    expect(b.pageCount, 120);
    final data = bookJson()
      ..['price'] = '0'
      ..['pageCount'] = null;
    expect(CatalogBook.fromJson(data).priceLabel, 'Free');
  });
  for (final price in ['NaN', 'Infinity', '-1', 'invalid']) {
    test('rejects invalid price $price', () {
      expect(
        () => CatalogBook.fromJson(bookJson()..['price'] = price),
        throwsFormatException,
      );
    });
  }
  test('rejects malformed pagination', () {
    expect(
      () => CatalogPage.fromJson({
        'items': [],
        'page': 0,
        'total': -1,
        'hasMore': false,
      }),
      throwsFormatException,
    );
  });
  test('public API omits credentials and encodes query centrally', () async {
    final transport = ProbeTransport();
    final api = CatalogApi(
      config: ApiConfig('http://127.0.0.1:3000'),
      transport: transport,
    );
    transport.response = const ApiResponse(
      200,
      '{"items":[],"page":2,"total":0,"hasMore":false}',
    );
    await api.books(page: 2, search: 'circuit & power', category: 'circuit');
    expect(transport.uri!.path, '/api/v1/books');
    expect(transport.uri!.queryParameters['search'], 'circuit & power');
    expect(transport.headers, {'Accept': 'application/json'});
    api.close();
    expect(transport.closed, isTrue);
  });
  for (final status in [401, 403, 409, 500, 503]) {
    test('catalog status $status becomes safe failure', () async {
      final transport = ProbeTransport()
        ..response = ApiResponse(status, 'private backend stack');
      final api = CatalogApi(
        config: ApiConfig('http://localhost:3000'),
        transport: transport,
      );
      await expectLater(api.categories(), throwsA(isA<CatalogFailure>()));
    });
  }
  test('detail 404 is distinguished and malformed DTO is sanitized', () async {
    final transport = ProbeTransport()
      ..response = const ApiResponse(404, 'secret');
    final api = CatalogApi(
      config: ApiConfig('http://localhost:3000'),
      transport: transport,
    );
    await expectLater(
      api.book('missing'),
      throwsA(
        isA<CatalogFailure>().having((e) => e.notFound, 'not found', true),
      ),
    );
    transport.response = const ApiResponse(200, '{"secret":"raw"}');
    await expectLater(api.book('missing'), throwsA(isA<CatalogFailure>()));
  });
  testWidgets('search debounces, ignores stale requests and disposes safely', (
    tester,
  ) async {
    final old = Completer<CatalogPage>(), fresh = Completer<CatalogPage>();
    final fake = FakeCatalog()
      ..booksHandler = ((page, search, category, sort) =>
          search.isEmpty ? old.future : fresh.future);
    final controller = CatalogController(fake);
    unawaited(controller.reload());
    controller.setSearch('C');
    controller.setSearch('Circuit');
    await tester.pump(const Duration(milliseconds: 349));
    expect(fake.requests, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(fake.requests, 2);
    old.complete(
      CatalogPage(items: fixtureBooks, page: 1, total: 4, hasMore: false),
    );
    await tester.pump();
    expect(controller.books, isEmpty);
    fresh.complete(
      CatalogPage(
        items: [fixtureBooks.last],
        page: 1,
        total: 1,
        hasMore: false,
      ),
    );
    await tester.pump();
    expect(controller.books.single.slug, fixtureBooks.last.slug);
    controller.setSearch('later');
    controller.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(fake.requests, 2);
  });
  test('pagination guards duplicates and concurrent load more', () async {
    final next = Completer<CatalogPage>();
    final fake = FakeCatalog()
      ..booksHandler = ((page, search, category, sort) => page == 1
          ? Future.value(
              CatalogPage(
                items: [fixtureBooks.first],
                page: 1,
                total: 2,
                hasMore: true,
              ),
            )
          : next.future);
    final c = CatalogController(fake);
    await c.reload();
    final pending = c.loadMore();
    await c.loadMore();
    expect(fake.requests, 2);
    next.complete(
      CatalogPage(
        items: [fixtureBooks.first, fixtureBooks.last],
        page: 2,
        total: 2,
        hasMore: false,
      ),
    );
    await pending;
    expect(c.books.length, 2);
    expect(c.hasMore, isFalse);
    c.dispose();
  });
  test('old pagination cannot overwrite a new category', () async {
    final old = Completer<CatalogPage>();
    final fake = FakeCatalog()
      ..booksHandler = ((page, search, category, sort) => category == null
          ? old.future
          : Future.value(
              CatalogPage(
                items: [fixtureBooks.last],
                page: 1,
                total: 1,
                hasMore: false,
              ),
            ));
    final c = CatalogController(fake);
    unawaited(c.reload());
    c.setCategory('power');
    await Future<void>.delayed(Duration.zero);
    old.complete(
      CatalogPage(
        items: [fixtureBooks.first],
        page: 1,
        total: 1,
        hasMore: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(c.books.single.slug, fixtureBooks.last.slug);
    c.dispose();
  });
  test('category failures do not hide valid books', () async {
    final fake = FakeCatalog()
      ..categoriesHandler = (() => Future.error(const CatalogFailure()));
    final c = CatalogController(fake);
    await c.initialize();
    expect(c.categoryError, isNotNull);
    expect(c.books, hasLength(4));
    expect(c.bookError, isNull);
    c.dispose();
  });
  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: screen),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home displays loading before responses arrive', (tester) async {
    final pending = Completer<CatalogPage>();
    final fake = FakeCatalog()..booksHandler = ((p, s, c, o) => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: HomeScreen(repository: fake)),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(CatalogLoading),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byType(CatalogLoading), findsWidgets);
    pending.complete(
      const CatalogPage(items: [], page: 1, total: 0, hasMore: false),
    );
    await tester.pumpAndSettle();
  });
  testWidgets('Home empty catalog remains calm and refreshable', (
    tester,
  ) async {
    final fake = FakeCatalog()
      ..booksHandler = ((p, s, c, o) => Future.value(
        const CatalogPage(items: [], page: 1, total: 0, hasMore: false),
      ));
    await mount(tester, HomeScreen(repository: fake));
    await reveal(tester, find.text('The catalog is growing. Check back soon.'));
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
  testWidgets('Home failed books can retry without hiding categories', (
    tester,
  ) async {
    final fake = FakeCatalog()
      ..booksHandler = ((p, s, c, o) => Future.error(const CatalogFailure()));
    await mount(tester, HomeScreen(repository: fake));
    await reveal(tester, find.text('Try Again'));
    fake.booksHandler = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('catalog-book-study-guide-0')),
    );
    expect(find.byType(HomeBookCard), findsWidgets);
  });
  testWidgets('Explore search and category filters reach the repository', (
    tester,
  ) async {
    final fake = FakeCatalog();
    await mount(tester, ExploreScreen(repository: fake));
    await tester.enterText(find.byType(TextField), 'Circuit');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(fake.search, 'Circuit');
    await tester.tap(find.text('Power Systems').first);
    await tester.pumpAndSettle();
    expect(fake.category, 'power');
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(fake.category, isNull);
  });
  testWidgets('Explore empty results and error retry are contextual', (
    tester,
  ) async {
    final fake = FakeCatalog()
      ..booksHandler = ((p, s, c, o) => Future.value(
        const CatalogPage(items: [], page: 1, total: 0, hasMore: false),
      ));
    await mount(tester, ExploreScreen(repository: fake));
    await reveal(tester, find.textContaining('No books match'));
    fake.booksHandler = ((p, s, c, o) => Future.error(const CatalogFailure()));
    await tester.enterText(find.byType(TextField), 'unknown');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Try Again'));
    fake.booksHandler = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('catalog-book-study-guide-0')),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Explore load more appends results', (tester) async {
    final fake = FakeCatalog()
      ..booksHandler = ((p, s, c, o) => Future.value(
        CatalogPage(
          items: [fixtureBooks[p - 1]],
          page: p,
          total: 2,
          hasMore: p < 2,
        ),
      ));
    await mount(tester, ExploreScreen(repository: fake));
    await reveal(tester, find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('catalog-book-study-guide-1')),
    );
    expect(fake.requests, 2);
    expect(find.text('Load more'), findsNothing);
  });
  testWidgets('Book details loading, not found and retry are safe', (
    tester,
  ) async {
    final pending = Completer<CatalogBook>();
    final fake = FakeCatalog()..bookHandler = ((slug) => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: BookDetailsScreen(slug: 'missing', repository: fake),
      ),
    );
    await tester.pump();
    expect(find.byType(CatalogLoading), findsOneWidget);
    pending.completeError(const CatalogFailure(notFound: true));
    await tester.pumpAndSettle();
    expect(find.text('This book is not available.'), findsOneWidget);
    fake.bookHandler = ((slug) => Future.value(fixtureBooks.first));
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Free'), findsOneWidget);
    expect(find.byType(CatalogCover), findsOneWidget);
    await reveal(tester, find.textContaining('Catalog preview only'));
    expect(find.text('Read now'), findsNothing);
  });
  testWidgets('Book details generic failures never show raw exceptions', (
    tester,
  ) async {
    final fake = FakeCatalog()
      ..bookHandler = ((slug) => Future.error(StateError('private exception')));
    await mount(tester, BookDetailsScreen(slug: 'book', repository: fake));
    expect(find.textContaining('private exception'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);
  });
  testWidgets('Explore card navigates to guest book details', (tester) async {
    final router = createAppRouter(
      initialLocation: '/explore',
      catalog: FakeCatalog(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await reveal(
      tester,
      find.byKey(const ValueKey('catalog-book-study-guide-0')),
    );
    await tester.tap(find.byKey(const ValueKey('catalog-book-study-guide-0')));
    await tester.pumpAndSettle();
    expect(find.text('Book details'), findsOneWidget);
  });
  testWidgets('feedback is a screen-reader live region', (tester) async {
    final semantics = tester.ensureSemantics();

    await mount(tester, const CatalogNotice(message: 'Catalog unavailable'));
    final widget = tester.widget<Semantics>(
      find
          .descendant(
            of: find.byType(CatalogNotice),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(widget.properties.liveRegion, isTrue);
    semantics.dispose();
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final details in [false, true]) {
        testWidgets('Catalog width $width text $scale details $details', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fake = FakeCatalog();
          await mount(
            tester,
            details
                ? BookDetailsScreen(
                    slug: fixtureBooks.first.slug,
                    repository: fake,
                  )
                : ExploreScreen(repository: fake),
            scale: scale,
          );
          await reveal(
            tester,
            details
                ? find.textContaining('Catalog preview only')
                : find.byKey(const ValueKey('catalog-book-study-guide-3')),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
