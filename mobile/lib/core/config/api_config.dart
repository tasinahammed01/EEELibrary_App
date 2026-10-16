import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig(String value, {bool production = !kDebugMode})
    : baseUrl = Uri.parse(value) {
    final local = {'10.0.2.2', '127.0.0.1', 'localhost'}.contains(baseUrl.host);
    if (!baseUrl.hasAuthority ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        (baseUrl.scheme != 'https' &&
            !(baseUrl.scheme == 'http' && local && !production))) {
      throw const FormatException('Configure a secure backend URL.');
    }
  }
  factory ApiConfig.fromEnvironment() => ApiConfig(
    const String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: kDebugMode ? 'http://10.0.2.2:3000' : '',
    ),
  );
  final Uri baseUrl;
  Uri authEndpoint(String action) => baseUrl.resolve('/api/v1/auth/$action');
}
