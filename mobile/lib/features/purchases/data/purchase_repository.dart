import 'dart:async';
import 'dart:convert';

import '../../../core/config/api_config.dart';
import '../../auth/data/api_transport.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/purchase_models.dart';

abstract interface class PurchaseRepository {
  String? get sessionKey;
  Future<BookAccess> access(String slug);
  Future<PurchaseOrder> create(String slug);
  Future<PurchaseOrder> order(String id);
  Future<OrderPage> orders({int page = 1});
  Future<List<ManualPaymentOption>> options();
  Future<PurchaseOrder> submit(String id, String method, String reference);
  Future<CatalogPage> library({int page = 1});
  void close();
}

class PurchaseApi implements PurchaseRepository {
  PurchaseApi(this.auth, {ApiTransport? transport, ApiConfig? config})
    : _transport = transport ?? IoApiTransport(),
      _config = config ?? ApiConfig.fromEnvironment();
  final AuthController auth;
  final ApiTransport _transport;
  final ApiConfig _config;
  @override
  String? get sessionKey => auth.protectedSessionKey;
  Future<T> _request<T>(
    String method,
    String path,
    T Function(Object?) parse, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final identity = sessionKey;
    if (identity == null) throw const PurchaseFailure(401);
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = await auth.protectedIdToken(forceRefresh: attempt == 1);
        if (sessionKey != identity) throw const PurchaseFailure(401);
        final response = await _transport.send(
          method: method,
          uri: _config.catalogEndpoint(path).replace(queryParameters: query),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          body: body,
        );
        if (sessionKey != identity) throw const PurchaseFailure(401);
        if (response.statusCode == 401 && attempt == 0) continue;
        if (response.statusCode == 200) return parse(jsonDecode(response.body));
        if (response.statusCode == 401 || response.statusCode == 403) {
          unawaited(auth.refreshSession());
        }
        throw PurchaseFailure(response.statusCode);
      }
    } on PurchaseFailure {
      rethrow;
    } on FormatException {
      throw const PurchaseFailure(503);
    } on TypeError {
      throw const PurchaseFailure(503);
    } on AuthFailure catch (error) {
      throw PurchaseFailure(
        error.kind == AuthFailureKind.unauthorized ? 401 : 0,
      );
    } catch (_) {
      throw const PurchaseFailure();
    }
    throw const PurchaseFailure(401);
  }

  @override
  Future<BookAccess> access(String slug) => _request(
    'GET',
    'books/${Uri.encodeComponent(slug)}/access',
    BookAccess.fromJson,
  );
  @override
  Future<PurchaseOrder> create(String slug) => _request(
    'POST',
    'orders',
    PurchaseOrder.fromJson,
    body: {'bookSlug': slug},
  );
  @override
  Future<PurchaseOrder> order(String id) => _request(
    'GET',
    'orders/${Uri.encodeComponent(id)}',
    PurchaseOrder.fromJson,
  );
  @override
  Future<OrderPage> orders({int page = 1}) => _request(
    'GET',
    'orders',
    OrderPage.fromJson,
    query: {'page': '$page', 'pageSize': '12'},
  );
  @override
  Future<List<ManualPaymentOption>> options() =>
      _request('GET', 'orders/payment-options', (value) {
        if (value is! List || value.length > 2) throw const FormatException();
        return List.unmodifiable(value.map(ManualPaymentOption.fromJson));
      });
  @override
  Future<PurchaseOrder> submit(String id, String method, String reference) =>
      _request(
        'POST',
        'orders/${Uri.encodeComponent(id)}/payment',
        PurchaseOrder.fromJson,
        body: {'method': method, 'reference': reference.trim().toUpperCase()},
      );
  @override
  Future<CatalogPage> library({int page = 1}) => _request(
    'GET',
    'library',
    (value) => CatalogPage.fromJson(object(value)),
    query: {'page': '$page', 'pageSize': '12'},
  );
  @override
  void close() => _transport.close();
}
