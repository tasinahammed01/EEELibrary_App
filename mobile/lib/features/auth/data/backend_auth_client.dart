import 'dart:convert';

import '../../../core/config/api_config.dart';
import '../../../core/diagnostics/auth_diagnostics.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_models.dart';
import 'api_transport.dart';

class BackendFailure extends AuthFailure {
  const BackendFailure(this.statusCode, super.kind);
  final int statusCode;
}

class BackendAuthClient {
  BackendAuthClient(this._auth, this._transport, this._config);
  final AuthGateway _auth;
  final ApiTransport _transport;
  final ApiConfig _config;
  Future<ApplicationUser> bootstrap() =>
      _request('POST', AuthBackendRoute.bootstrap);
  Future<ApplicationUser> me() => _request('GET', AuthBackendRoute.me);
  Future<ApplicationUser> _request(
    String method,
    AuthBackendRoute action,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthFailure(AuthFailureKind.unauthorized);
    for (var attempt = 0; attempt < 2; attempt++) {
      final String token;
      try {
        token = await _auth.token(forceRefresh: attempt == 1);
        AuthDiagnostics.emit(
          AuthTraceEvent.token,
          route: action,
          attempt: attempt + 1,
          acquired: true,
        );
      } catch (_) {
        AuthDiagnostics.emit(
          AuthTraceEvent.token,
          route: action,
          attempt: attempt + 1,
          acquired: false,
        );
        rethrow;
      }
      if (_auth.currentUser?.uid != uid) {
        throw const AuthFailure(AuthFailureKind.unauthorized);
      }
      final response = await _transport.send(
        method: method,
        uri: _config.authEndpoint(action.name),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (_auth.currentUser?.uid != uid) {
        throw const AuthFailure(AuthFailureKind.unauthorized);
      }
      AuthDiagnostics.emit(
        AuthTraceEvent.response,
        route: action,
        status: response.statusCode,
        attempt: attempt + 1,
      );
      if (response.statusCode == 401 && attempt == 0) continue;
      if (response.statusCode == 200) {
        try {
          return ApplicationUser.fromJson(jsonDecode(response.body));
        } on AuthFailure {
          rethrow;
        } catch (_) {
          throw const AuthFailure(AuthFailureKind.unavailable);
        }
      }
      throw BackendFailure(response.statusCode, switch (response.statusCode) {
        401 => AuthFailureKind.unauthorized,
        403 => AuthFailureKind.denied,
        409 => AuthFailureKind.conflict,
        503 => AuthFailureKind.unavailable,
        _ => AuthFailureKind.unavailable,
      });
    }
    throw const AuthFailure(AuthFailureKind.unauthorized);
  }

  void close() => _transport.close();
}
