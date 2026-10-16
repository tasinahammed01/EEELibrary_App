import 'dart:async';

import 'package:eeelibrary/features/catalog/domain/catalog_models.dart';
import 'package:eeelibrary/features/purchases/data/purchase_repository.dart';
import 'package:eeelibrary/features/purchases/domain/purchase_models.dart';

import 'catalog_fakes.dart';

PurchaseOrder fixtureOrder({
  OrderStage stage = OrderStage.pendingPayment,
  String? paymentStatus,
  String? reason,
}) => PurchaseOrder(
  id: 'order-fixture',
  book: fixtureBooks[1],
  amount: '320.00',
  currency: 'BDT',
  stage: stage,
  paymentStatus: paymentStatus,
  rejectionReason: reason,
);

class FakePurchases implements PurchaseRepository {
  String? identity = 'fixture-user';
  @override
  String? get sessionKey => identity;
  PurchaseOrder current = fixtureOrder();
  BookAccess snapshot = const BookAccess(owned: false);
  CatalogPage shelf = const CatalogPage(
    items: [],
    page: 1,
    total: 0,
    hasMore: false,
  );
  int creates = 0, submits = 0, accessCalls = 0, libraryCalls = 0;
  Future<PurchaseOrder> Function()? createHandler, orderHandler;
  Future<PurchaseOrder> Function(String method, String reference)?
  submitHandler;
  Future<BookAccess> Function()? accessHandler;
  Future<CatalogPage> Function()? libraryHandler;
  @override
  Future<BookAccess> access(String slug) async {
    accessCalls++;
    return accessHandler == null ? snapshot : accessHandler!();
  }

  @override
  Future<PurchaseOrder> create(String slug) async {
    creates++;
    return createHandler == null ? current : createHandler!();
  }

  @override
  Future<PurchaseOrder> order(String id) async =>
      orderHandler == null ? current : orderHandler!();
  @override
  Future<OrderPage> orders({int page = 1}) async => OrderPage([current], false);
  @override
  Future<List<ManualPaymentOption>> options() async => const [
    ManualPaymentOption(
      method: 'BKASH',
      instructions: 'Development only. Do not send money.',
      development: true,
    ),
  ];
  @override
  Future<PurchaseOrder> submit(
    String id,
    String method,
    String reference,
  ) async {
    submits++;
    if (submitHandler != null) return submitHandler!(method, reference);
    current = fixtureOrder(
      stage: OrderStage.submitted,
      paymentStatus: 'PENDING',
    );
    snapshot = BookAccess(owned: false, order: current);
    return current;
  }

  @override
  Future<CatalogPage> library({int page = 1}) async {
    libraryCalls++;
    return libraryHandler == null ? shelf : libraryHandler!();
  }

  @override
  void close() {}
}
