import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/core/config/api_config.dart';
import 'package:eeelibrary/core/routing/app_router.dart';
import 'package:eeelibrary/core/theme/app_theme.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/catalog/domain/catalog_models.dart';
import 'package:eeelibrary/features/catalog/widgets/catalog_widgets.dart';
import 'package:eeelibrary/features/library/library_screen.dart';
import 'package:eeelibrary/features/purchases/data/purchase_repository.dart';
import 'package:eeelibrary/features/purchases/domain/purchase_models.dart';
import 'package:eeelibrary/features/purchases/presentation/book_purchase_panel.dart';
import 'package:eeelibrary/features/purchases/presentation/order_screen.dart';
import 'package:eeelibrary/features/purchases/presentation/purchase_controllers.dart';

import 'support/auth_fakes.dart';
import 'support/catalog_fakes.dart';
import 'support/purchase_fakes.dart';

class PurchaseProbe implements ApiTransport {
  final responses = <ApiResponse>[];
  final bodies = <Map<String, dynamic>?>[];
  final headers = <Map<String, String>>[];
  Completer<ApiResponse>? pending;
  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) async {
    bodies.add(body);
    this.headers.add(headers);
    return pending?.future ?? Future.value(responses.removeAt(0));
  }

  @override
  void close() {}
}

Map<String, dynamic> orderJson() => {
  'id': 'order-fixture',
  'status': 'PENDING_PAYMENT',
  'amount': '320.00',
  'currency': 'BDT',
  'payments': [],
  'book': {
    'slug': 'book',
    'title': 'Resource',
    'price': '320.00',
    'currency': 'BDT',
    'pageCount': null,
    'category': {'id': 'category', 'slug': 'circuit', 'name': 'Circuit'},
  },
};
void main() {
  test(
    'disposed auth provider invalidates protected token and session access',
    () async {
      final auth = AuthHarness();
      await auth.controller.login('reader@fixture.example', 'test-password');
      expect(auth.controller.protectedSessionKey, isNotNull);
      auth.controller.dispose();
      await auth.gateway.close();
      expect(auth.controller.protectedSessionKey, isNull);
      await expectLater(
        auth.controller.protectedIdToken(),
        throwsA(isA<Exception>()),
      );
    },
  );
  test(
    'order parsing rejects invalid status/amount and does not infer ownership',
    () {
      expect(
        PurchaseOrder.fromJson(orderJson()).stage,
        OrderStage.pendingPayment,
      );
      expect(
        () => PurchaseOrder.fromJson(orderJson()..['amount'] = 'NaN'),
        throwsFormatException,
      );
      expect(
        () => PurchaseOrder.fromJson(orderJson()..['status'] = 'OWNED'),
        throwsFormatException,
      );
      expect(
        BookAccess.fromJson({
          'owned': false,
          'order': orderJson()..['status'] = 'COMPLETED',
        }).owned,
        isFalse,
      );
    },
  );
  test('public rejection messaging comes only from allowlisted codes', () {
    final json = orderJson()
      ..['payments'] = [
        {'status': 'REJECTED', 'rejectionReason': 'private admin details'},
      ];
    expect(PurchaseOrder.fromJson(json).rejectionReason, isNull);
  });
  test(
    'protected requests acquire headers and send only safe intent fields',
    () async {
      final auth = AuthHarness();
      addTearDown(auth.dispose);
      await auth.controller.login(
        'reader@fixture.example',
        'private-test-password',
      );
      final transport = PurchaseProbe()
        ..responses.add(ApiResponse(200, jsonEncode(orderJson())));
      final api = PurchaseApi(
        auth.controller,
        transport: transport,
        config: ApiConfig('http://localhost:3000'),
      );
      await api.create('book');
      expect(transport.bodies.single, {'bookSlug': 'book'});
      expect(transport.headers.single.containsKey('Authorization'), isTrue);
    },
  );
  test('protected requests refresh token once on 401', () async {
    final auth = AuthHarness();
    addTearDown(auth.dispose);
    await auth.controller.login(
      'reader@fixture.example',
      'private-test-password',
    );
    final transport = PurchaseProbe()
      ..responses.addAll([
        const ApiResponse(401, 'private'),
        const ApiResponse(200, '{"owned":false,"order":null}'),
      ]);
    final api = PurchaseApi(
      auth.controller,
      transport: transport,
      config: ApiConfig('http://localhost:3000'),
    );
    await api.access('book');
    expect(transport.bodies.length, 2);
    expect(auth.gateway.refreshes.last, isTrue);
  });
  test('account change discards an in-flight protected response', () async {
    final auth = AuthHarness();
    addTearDown(auth.dispose);
    await auth.controller.login(
      'reader@fixture.example',
      'private-test-password',
    );
    final transport = PurchaseProbe()..pending = Completer<ApiResponse>();
    final api = PurchaseApi(
      auth.controller,
      transport: transport,
      config: ApiConfig('http://localhost:3000'),
    );
    final result = api.access('book');
    final assertion = expectLater(result, throwsA(isA<PurchaseFailure>()));
    await auth.settle();
    auth.gateway.identity = null;
    transport.pending!.complete(
      const ApiResponse(200, '{"owned":true,"order":null}'),
    );
    await assertion;
  });
  test(
    'double create is guarded and ownership is refreshed from backend',
    () async {
      final pending = Completer<PurchaseOrder>();
      final fake = FakePurchases()..createHandler = (() => pending.future);
      final controller = BookPurchaseController(fake, 'book');
      await controller.load();
      final first = controller.acquire();
      await controller.acquire();
      expect(fake.creates, 1);
      fake.snapshot = BookAccess(
        owned: true,
        order: fixtureOrder(stage: OrderStage.completed),
      );
      pending.complete(fixtureOrder(stage: OrderStage.completed));
      await first;
      expect(controller.access!.owned, isTrue);
      expect(fake.accessCalls, 2);
      controller.dispose();
    },
  );
  test('controller cannot mutate after a session identity switch', () async {
    final fake = FakePurchases();
    final controller = BookPurchaseController(fake, 'book');
    await controller.load();
    fake.identity = 'different-user';
    await controller.acquire();
    expect(fake.creates, 0);
    controller.dispose();
  });
  test('disposed library ignores a late response', () async {
    final pending = Completer<CatalogPage>();
    final fake = FakePurchases()..libraryHandler = (() => pending.future);
    final controller = LibraryController(fake);
    final load = controller.load();
    controller.dispose();
    pending.complete(
      CatalogPage(items: fixtureBooks, page: 1, total: 4, hasMore: false),
    );
    await load;
    expect(controller.books, isEmpty);
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

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('guest Book Details has a sign-in acquisition CTA', (
    tester,
  ) async {
    final router = createAppRouter(
      initialLocation: '/books/study-guide-0',
      catalog: FakeCatalog(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Sign in to get this book'));
    await tester.tap(find.text('Sign in to get this book'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/login',
    );
  });
  testWidgets('authenticated Buy creates order then navigates to review', (
    tester,
  ) async {
    final fake = FakePurchases();
    final router = createAppRouter(
      initialLocation: '/books/study-guide-1',
      catalog: FakeCatalog(),
      purchases: fake,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Buy book'));
    await tester.tap(find.text('Buy book'));
    await tester.pumpAndSettle();
    expect(find.text('Order review'), findsOneWidget);
    expect(find.text('BDT 320.00'), findsOneWidget);
    expect(fake.creates, 1);
  });
  testWidgets(
    'free acquisition uses backend ownership before showing In Library',
    (tester) async {
      final fake = FakePurchases();
      fake.createHandler = (() async {
        fake.snapshot = BookAccess(
          owned: true,
          order: fixtureOrder(stage: OrderStage.completed),
        );
        return fixtureOrder(stage: OrderStage.completed);
      });
      await mount(
        tester,
        BookPurchasePanel(slug: 'free', free: true, repository: fake),
      );
      await tester.tap(find.text('Get free book'));
      await tester.pumpAndSettle();
      expect(find.text('In Library'), findsOneWidget);
      expect(find.text('Added to your library.'), findsOneWidget);
      expect(fake.submits, 0);
    },
  );
  testWidgets(
    'already owned uses explicit backend state and does not create order',
    (tester) async {
      final fake = FakePurchases()..snapshot = const BookAccess(owned: true);
      await mount(
        tester,
        BookPurchasePanel(slug: 'book', free: false, repository: fake),
      );
      expect(find.text('In Library'), findsOneWidget);
      expect(find.text('Buy book'), findsNothing);
      expect(fake.creates, 0);
    },
  );
  testWidgets('pending payment does not show owned state', (tester) async {
    final fake = FakePurchases()
      ..snapshot = BookAccess(
        owned: false,
        order: fixtureOrder(
          stage: OrderStage.submitted,
          paymentStatus: 'PENDING',
        ),
      );
    await mount(
      tester,
      BookPurchasePanel(slug: 'book', free: false, repository: fake),
    );
    expect(find.text('View order status'), findsOneWidget);
    expect(find.text('In Library'), findsNothing);
  });
  testWidgets('rejected payment explains a new reference is required', (
    tester,
  ) async {
    final fake = FakePurchases()
      ..snapshot = BookAccess(
        owned: false,
        order: fixtureOrder(
          paymentStatus: 'REJECTED',
          reason: 'Check the instructions and use a new reference.',
        ),
      );
    await mount(
      tester,
      BookPurchasePanel(slug: 'book', free: false, repository: fake),
    );
    expect(find.text('Review and resubmit'), findsOneWidget);
    expect(find.textContaining('new reference'), findsOneWidget);
  });
  for (final status in [0, 401, 403, 409, 503]) {
    testWidgets('purchase failure $status is safe and retryable', (
      tester,
    ) async {
      final fake = FakePurchases()
        ..accessHandler = (() => Future.error(PurchaseFailure(status)));
      await mount(
        tester,
        BookPurchasePanel(slug: 'book', free: false, repository: fake),
      );
      expect(find.text(PurchaseFailure(status).message), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      fake.accessHandler = null;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Buy book'), findsOneWidget);
    });
  }
  testWidgets(
    'payment review validates reference and successfully shows pending',
    (tester) async {
      final fake = FakePurchases();
      await mount(tester, OrderScreen(id: fake.current.id, repository: fake));
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Submit payment reference'));
      await tester.tap(find.text('Submit payment reference'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 3–100 letters or digits.'), findsOneWidget);
      expect(fake.submits, 0);
      await tester.enterText(find.byType(TextFormField), 'DEV12345');
      await reveal(tester, find.text('Submit payment reference'));
      await tester.tap(find.text('Submit payment reference'));
      await tester.pumpAndSettle();
      expect(fake.submits, 1);
      expect(
        find.textContaining('Reference submitted successfully'),
        findsOneWidget,
      );
      expect(find.text('Open My Library'), findsNothing);
    },
  );
  testWidgets(
    'double submission is guarded and form disables during the request',
    (tester) async {
      final pending = Completer<PurchaseOrder>();
      final fake = FakePurchases()..submitHandler = ((m, r) => pending.future);
      await mount(tester, OrderScreen(id: 'order-fixture', repository: fake));
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'DEV123');
      await reveal(tester, find.text('Submit payment reference'));
      await tester.tap(find.text('Submit payment reference'));
      await tester.pump();
      expect(find.text('Submitting…'), findsOneWidget);
      expect(fake.submits, 1);
      fake.current = fixtureOrder(
        stage: OrderStage.submitted,
        paymentStatus: 'PENDING',
      );
      pending.complete(fake.current);
      await tester.pumpAndSettle();
    },
  );
  testWidgets('order status refreshes backend ownership after approval', (
    tester,
  ) async {
    final fake = FakePurchases()
      ..current = fixtureOrder(stage: OrderStage.submitted);
    await mount(tester, OrderScreen(id: 'order-fixture', repository: fake));
    expect(find.text('Refresh status'), findsOneWidget);
    fake.current = fixtureOrder(
      stage: OrderStage.completed,
      paymentStatus: 'APPROVED',
    );
    fake.snapshot = BookAccess(owned: true, order: fake.current);
    await tester.tap(find.text('Refresh status'));
    await tester.pumpAndSettle();
    expect(find.text('Open My Library'), findsOneWidget);
  });
  testWidgets(
    'Library loading then success renders only the entitlement response',
    (tester) async {
      final pending = Completer<CatalogPage>();
      final fake = FakePurchases()..libraryHandler = (() => pending.future);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: LibraryScreen(repository: fake)),
        ),
      );
      await tester.pump();
      expect(find.byType(CatalogLoading), findsOneWidget);
      pending.complete(
        CatalogPage(
          items: [fixtureBooks.first],
          page: 1,
          total: 1,
          hasMore: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(fixtureBooks.first.title), findsWidgets);
      expect(find.text(fixtureBooks.last.title), findsNothing);
      expect(find.text('In Library'), findsOneWidget);
    },
  );
  testWidgets('Library empty, network failure and retry remain clear', (
    tester,
  ) async {
    final fake = FakePurchases()
      ..libraryHandler = (() => Future.error(const PurchaseFailure()));
    await mount(tester, LibraryScreen(repository: fake));
    expect(find.text('Try Again'), findsOneWidget);
    fake.libraryHandler = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your library is empty'), findsOneWidget);
    expect(find.byType(CatalogBookCard), findsNothing);
  });
  testWidgets('guest Library does not request private data', (tester) async {
    final fake = FakePurchases()..identity = null;
    await mount(tester, LibraryScreen(repository: fake));
    expect(find.text('Sign In'), findsOneWidget);
    expect(fake.libraryCalls, 0);
  });
  testWidgets('Book purchase refresh rejects stale older ownership responses', (
    tester,
  ) async {
    final old = Completer<BookAccess>();
    final fake = FakePurchases()..accessHandler = (() => old.future);
    final controller = BookPurchaseController(fake, 'book');
    final pending = controller.load();
    fake.accessHandler = (() => Future.value(const BookAccess(owned: false)));
    await controller.load();
    old.complete(const BookAccess(owned: true));
    await pending;
    expect(controller.access!.owned, isFalse);
    controller.dispose();
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Order and owned Library at width $width, scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fake = FakePurchases();
        await mount(
          tester,
          OrderScreen(id: 'order-fixture', repository: fake),
          scale: scale,
        );
        await reveal(tester, find.text('Continue to payment'));
        await tester.tap(find.text('Continue to payment'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Submit payment reference'));
        expect(tester.takeException(), isNull);
        fake.shelf = CatalogPage(
          items: [fixtureBooks.last],
          page: 1,
          total: 1,
          hasMore: false,
        );
        await mount(tester, LibraryScreen(repository: fake), scale: scale);
        await reveal(
          tester,
          find.byKey(ValueKey('catalog-book-${fixtureBooks.last.slug}')),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final status in [0, 401, 403, 409, 503]) {
    testWidgets('Order service error $status remains safe and recoverable', (
      tester,
    ) async {
      final fake = FakePurchases()
        ..orderHandler = (() => Future.error(PurchaseFailure(status)));
      await mount(tester, OrderScreen(id: 'order-fixture', repository: fake));
      expect(find.text(PurchaseFailure(status).message), findsOneWidget);
      fake.orderHandler = null;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Continue to payment'), findsOneWidget);
    });
  }
  testWidgets('completed order without entitlement never shows owned', (
    tester,
  ) async {
    final fake = FakePurchases()
      ..current = fixtureOrder(stage: OrderStage.completed);
    await mount(tester, OrderScreen(id: 'order-fixture', repository: fake));
    expect(find.text('Open My Library'), findsNothing);
    expect(
      find.textContaining('access is currently unavailable'),
      findsOneWidget,
    );
  });
  testWidgets(
    'payment network failure preserves a safe retry without fake ownership',
    (tester) async {
      final fake = FakePurchases()
        ..submitHandler = ((m, r) => Future.error(const PurchaseFailure()));
      await mount(tester, OrderScreen(id: 'order-fixture', repository: fake));
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'DEVRETRY');
      await reveal(tester, find.text('Submit payment reference'));
      await tester.tap(find.text('Submit payment reference'));
      await tester.pumpAndSettle();
      expect(find.text(const PurchaseFailure().message), findsOneWidget);
      expect(find.text('Open My Library'), findsNothing);
      fake.submitHandler = null;
      await reveal(tester, find.text('Submit payment reference'));
      await tester.tap(find.text('Submit payment reference'));
      await tester.pumpAndSettle();
      expect(fake.submits, 2);
    },
  );
  test(
    'malformed protected response becomes safe service-unavailable feedback',
    () async {
      final auth = AuthHarness();
      addTearDown(auth.dispose);
      await auth.controller.login('reader@fixture.example', 'test-password');
      final transport = PurchaseProbe()
        ..responses.add(const ApiResponse(200, 'private invalid JSON'));
      final api = PurchaseApi(
        auth.controller,
        transport: transport,
        config: ApiConfig('http://localhost:3000'),
      );
      await expectLater(
        api.access('book'),
        throwsA(
          isA<PurchaseFailure>().having((error) => error.status, 'status', 503),
        ),
      );
    },
  );
  testWidgets('orders and new purchase routes preserve back navigation', (
    tester,
  ) async {
    final fake = FakePurchases();
    final router = createAppRouter(
      initialLocation: '/library',
      purchases: fake,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('My orders'), findsOneWidget);
    await tester.tap(find.text(fake.current.book.title));
    await tester.pumpAndSettle();
    expect(find.text('Order review'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('My orders'), findsOneWidget);
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Order history at $width with text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fake = FakePurchases();
        await mount(tester, OrdersScreen(repository: fake), scale: scale);
        expect(find.text(fake.current.book.title), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
