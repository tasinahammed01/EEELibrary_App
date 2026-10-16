import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog_models.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase_models.dart';

abstract class SessionController extends ChangeNotifier {
  SessionController(this.repository) : identity = repository.sessionKey;
  final PurchaseRepository repository;
  final String? identity;
  bool disposed = false;
  int epoch = 0;
  bool get active =>
      !disposed && identity != null && repository.sessionKey == identity;
  bool valid(int version) =>
      !disposed &&
      epoch == version &&
      identity != null &&
      repository.sessionKey == identity;
  @override
  void dispose() {
    disposed = true;
    epoch++;
    super.dispose();
  }
}

class BookPurchaseController extends SessionController {
  BookPurchaseController(super.repository, this.slug);
  final String slug;
  BookAccess? access;
  PurchaseFailure? error;
  bool loading = true, busy = false;
  String? success;
  Future<void> load() async {
    if (!active) return;
    if (!active || busy) return;
    final version = ++epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.access(slug);
      if (!valid(version)) return;
      access = result;
    } on PurchaseFailure catch (e) {
      if (!valid(version)) return;
      error = e;
    } catch (_) {
      if (!valid(version)) return;
      error = const PurchaseFailure();
    }
    loading = false;
    notifyListeners();
  }

  Future<PurchaseOrder?> acquire() async {
    if (!active || busy || loading) return null;
    final version = ++epoch;
    busy = true;
    error = null;
    success = null;
    notifyListeners();
    PurchaseOrder? result;
    try {
      result = await repository.create(slug);
      if (!valid(version)) return null;
      final fresh = await repository.access(slug);
      if (!valid(version)) return null;
      access = fresh;
      if (fresh.owned) success = 'Added to your library.';
    } on PurchaseFailure catch (e) {
      if (!valid(version)) return null;
      error = e;
    } catch (_) {
      if (!valid(version)) return null;
      error = const PurchaseFailure();
    }
    busy = false;
    notifyListeners();
    return error == null ? result : null;
  }
}

class OrderController extends SessionController {
  OrderController(super.repository, this.id);
  final String id;
  PurchaseOrder? order;
  BookAccess? access;
  List<ManualPaymentOption> options = const [];
  PurchaseFailure? error;
  bool loading = true, busy = false;
  bool submitted = false;
  Future<void> load() async {
    if (!active) return;
    if (!active || busy) return;
    final version = ++epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.order(id);
      final ownership = await repository.access(result.book.slug);
      final methods = result.stage == OrderStage.pendingPayment
          ? await repository.options()
          : <ManualPaymentOption>[];
      if (!valid(version)) return;
      order = result;
      access = ownership;
      options = methods;
    } on PurchaseFailure catch (e) {
      if (!valid(version)) return;
      error = e;
    } catch (_) {
      if (!valid(version)) return;
      error = const PurchaseFailure();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> submit(String method, String reference) async {
    if (!active ||
        busy ||
        loading ||
        order?.stage != OrderStage.pendingPayment) {
      return;
    }
    final version = ++epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.submit(id, method, reference);
      if (!valid(version)) return;
      final fresh = await repository.order(id);
      final ownership = await repository.access(fresh.book.slug);
      if (!valid(version)) return;
      order = fresh;
      access = ownership;
      submitted = fresh.stage == OrderStage.submitted;
    } on PurchaseFailure catch (e) {
      if (!valid(version)) return;
      error = e;
    } catch (_) {
      if (!valid(version)) return;
      error = const PurchaseFailure();
    }
    busy = false;
    notifyListeners();
  }
}

class LibraryController extends SessionController {
  LibraryController(super.repository);
  List<CatalogBook> books = const [];
  PurchaseFailure? error;
  bool loading = true, loadingMore = false, hasMore = false;
  int page = 0;
  Future<void> load() async {
    if (!active) return;
    final version = ++epoch;
    loading = true;
    loadingMore = false;
    error = null;
    books = const [];
    hasMore = false;
    page = 0;
    notifyListeners();
    await _fetch(version, 1);
  }

  Future<void> more() async {
    if (!active || loading || loadingMore || !hasMore) return;
    loadingMore = true;
    error = null;
    notifyListeners();
    await _fetch(epoch, page + 1);
  }

  Future<void> _fetch(int version, int next) async {
    try {
      final result = await repository.library(page: next);
      if (!valid(version)) return;
      final seen = books.map((b) => b.slug).toSet();
      books = List.unmodifiable([
        ...books,
        ...result.items.where((b) => seen.add(b.slug)),
      ]);
      page = result.page;
      hasMore = result.hasMore;
    } on PurchaseFailure catch (e) {
      if (!valid(version)) return;
      error = e;
    } catch (_) {
      if (!valid(version)) return;
      error = const PurchaseFailure();
    }
    loading = false;
    loadingMore = false;
    notifyListeners();
  }
}

class OrdersController extends SessionController {
  OrdersController(super.repository);
  List<PurchaseOrder> orders = const [];
  PurchaseFailure? error;
  bool loading = true, loadingMore = false, hasMore = false;
  int page = 0;
  Future<void> load() async {
    if (!active) return;
    final version = ++epoch;
    loading = true;
    loadingMore = false;
    orders = const [];
    error = null;
    page = 0;
    notifyListeners();
    await _fetch(version, 1);
  }

  Future<void> more() async {
    if (!active || loading || loadingMore || !hasMore) return;
    loadingMore = true;
    error = null;
    notifyListeners();
    await _fetch(epoch, page + 1);
  }

  Future<void> _fetch(int version, int next) async {
    try {
      final result = await repository.orders(page: next);
      if (!valid(version)) return;
      final seen = orders.map((o) => o.id).toSet();
      orders = List.unmodifiable([
        ...orders,
        ...result.items.where((o) => seen.add(o.id)),
      ]);
      page = next;
      hasMore = result.hasMore;
    } on PurchaseFailure catch (e) {
      if (!valid(version)) return;
      error = e;
    } catch (_) {
      if (!valid(version)) return;
      error = const PurchaseFailure();
    }
    loading = false;
    loadingMore = false;
    notifyListeners();
  }
}
