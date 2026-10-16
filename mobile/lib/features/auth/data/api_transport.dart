import 'dart:convert';
import 'dart:io';

import '../domain/auth_models.dart';

class ApiResponse {
  const ApiResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

abstract interface class ApiTransport {
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
  });
  void close();
}

class IoApiTransport implements ApiTransport {
  IoApiTransport()
    : _client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final HttpClient _client;
  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    HttpClientRequest? active;
    Future<ApiResponse> execute() async {
      active = await _client.openUrl(method, uri);
      final request = active!;
      request.followRedirects =
          false; // Never forward bearer credentials to another location.
      headers.forEach(request.headers.set);
      if (method == 'POST') {
        request.contentLength = 0; // No identity or password body.
      }
      final response = await request.close();
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 64 * 1024) {
          request.abort();
          throw const AuthFailure(AuthFailureKind.unavailable);
        }
        bytes.addAll(chunk);
      }
      return ApiResponse(response.statusCode, utf8.decode(bytes));
    }

    try {
      return await execute().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          active?.abort();
          throw const AuthFailure(AuthFailureKind.network);
        },
      );
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure(AuthFailureKind.network);
    }
  }

  @override
  void close() => _client.close(force: true);
}
