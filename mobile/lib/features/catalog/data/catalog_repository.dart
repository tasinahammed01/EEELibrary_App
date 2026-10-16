import 'dart:convert';

import '../../../core/config/api_config.dart';
import '../../auth/data/api_transport.dart';
import '../domain/catalog_models.dart';

abstract interface class CatalogRepository {
  Future<List<CatalogCategory>> categories();
  Future<CatalogPage> books({
    int page = 1,
    int pageSize = 12,
    String search = '',
    String? category,
    String sort = 'newest',
  });
  Future<CatalogBook> book(String slug);
  void close();
}

class CatalogApi implements CatalogRepository {
  CatalogApi({ApiConfig? config, ApiTransport? transport})
    : _config = config ?? ApiConfig.fromEnvironment(),
      _transport = transport ?? IoApiTransport();
  final ApiConfig _config;
  final ApiTransport _transport;
  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    try {
      final response = await _transport.send(
        method: 'GET',
        uri: _config.catalogEndpoint(path).replace(queryParameters: query),
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode == 404) {
        throw const CatalogFailure(notFound: true);
      }
      if (response.statusCode != 200) throw const CatalogFailure();
      return jsonDecode(response.body);
    } on CatalogFailure {
      rethrow;
    } catch (_) {
      throw const CatalogFailure();
    }
  }

  Future<T> _parse<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CatalogFailure {
      rethrow;
    } catch (_) {
      throw const CatalogFailure();
    }
  }

  @override
  Future<List<CatalogCategory>> categories() => _parse(
    () async => List.unmodifiable(
      (await _get('categories') as List).map(
        (e) => CatalogCategory.fromJson(e as Map<String, dynamic>),
      ),
    ),
  );
  @override
  Future<CatalogPage> books({
    int page = 1,
    int pageSize = 12,
    String search = '',
    String? category,
    String sort = 'newest',
  }) => _parse(
    () async => CatalogPage.fromJson(
      await _get('books', {
        'page': '$page',
        'pageSize': '$pageSize',
        'sort': sort,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'category': ?category,
      }) as Map<String, dynamic>,
    ),
  );
  @override
  Future<CatalogBook> book(String slug) => _parse(
    () async => CatalogBook.fromJson(
      await _get('books/${Uri.encodeComponent(slug)}') as Map<String, dynamic>,
      details: true,
    ),
  );
  @override
  void close() => _transport.close();
}
