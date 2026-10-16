import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';

class CatalogController extends ChangeNotifier {
  CatalogController(this.repository, {this.pageSize = 12});
  final CatalogRepository repository;
  final int pageSize;
  List<CatalogCategory> categories = const [];
  List<CatalogBook> books = const [];
  CatalogFailure? categoryError, bookError;
  bool loading = true,
      loadingMore = false,
      categoriesLoading = true,
      hasMore = false;
  int _page = 0, _epoch = 0, _categoryEpoch = 0;
  String search = '', sort = 'newest';
  String? category;
  Timer? _debounce;
  bool _disposed = false;
  Future<void> initialize() => Future.wait([loadCategories(), reload()]);
  Future<void> loadCategories() async {
    final epoch = ++_categoryEpoch;
    categoriesLoading = true;
    categoryError = null;
    _notify();
    try {
      final result = await repository.categories();
      if (_disposed || epoch != _categoryEpoch) return;
      categories = result;
    } catch (_) {
      if (_disposed || epoch != _categoryEpoch) return;
      categoryError = const CatalogFailure();
    }
    categoriesLoading = false;
    _notify();
  }

  Future<void> refresh() => Future.wait([loadCategories(), reload()]);
  Future<void> reload() async {
    _debounce?.cancel();
    final epoch = ++_epoch;
    loading = true;
    loadingMore = false;
    bookError = null;
    books = const [];
    hasMore = false;
    _page = 0;
    _notify();
    await _fetch(epoch, 1);
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    loadingMore = true;
    bookError = null;
    _notify();
    await _fetch(_epoch, _page + 1);
  }

  Future<void> _fetch(int epoch, int page) async {
    try {
      final result = await repository.books(
        page: page,
        pageSize: pageSize,
        search: search,
        category: category,
        sort: sort,
      );
      if (_disposed || epoch != _epoch) return;
      final seen = books.map((b) => b.slug).toSet();
      books = List.unmodifiable([
        ...books,
        ...result.items.where((b) => seen.add(b.slug)),
      ]);
      _page = result.page;
      hasMore = result.hasMore;
    } catch (_) {
      if (_disposed || epoch != _epoch) return;
      bookError = const CatalogFailure();
    }
    loading = false;
    loadingMore = false;
    _notify();
  }

  void setSearch(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (search == normalized) return;
    search = normalized;
    hasMore = false;
    _debounce?.cancel();
    ++_epoch;
    loading = true;
    loadingMore = false;
    bookError = null;
    books = const [];
    _notify();
    _debounce = Timer(const Duration(milliseconds: 350), reload);
  }

  void setCategory(String? value) {
    if (category == value) return;
    category = value;
    unawaited(reload());
  }

  void setSort(String value) {
    if (sort == value) return;
    sort = value;
    unawaited(reload());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    ++_epoch;
    ++_categoryEpoch;
    super.dispose();
  }
}

class BookDetailsController extends ChangeNotifier {
  BookDetailsController(this.repository, this.slug);
  final CatalogRepository repository;
  final String slug;
  CatalogBook? book;
  CatalogFailure? error;
  bool loading = true, _disposed = false;
  int _epoch = 0;
  Future<void> load() async {
    final epoch = ++_epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.book(slug);
      if (_disposed || epoch != _epoch) return;
      book = result;
    } on CatalogFailure catch (e) {
      if (_disposed || epoch != _epoch) return;
      error = e;
    } catch (_) {
      if (_disposed || epoch != _epoch) return;
      error = const CatalogFailure();
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    super.dispose();
  }
}
