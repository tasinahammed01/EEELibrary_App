import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AuthAction {
  restore,
  login,
  register,
  google,
  verify,
  resend,
  reset,
  retry,
  logout,
}

enum AuthTraceEvent {
  started,
  finished,
  state,
  streamIgnored,
  token,
  response,
  failure,
}

enum AuthBackendRoute { bootstrap, me }

/// Deliberately accepts only enums, integers and booleans: no identity or secret data.
abstract final class AuthDiagnostics {
  static const enabled = kDebugMode && bool.fromEnvironment('AUTH_DIAGNOSTICS');
  static void emit(
    AuthTraceEvent event, {
    int? operation,
    AuthAction? action,
    Enum? state,
    AuthBackendRoute? route,
    int? status,
    int? attempt,
    bool? acquired,
    Enum? failure,
  }) {
    if (!enabled) return;
    final fields = <String, Object>{
      'event': event.name,
      'operation': ?operation,
      'action': ?action?.name,
      'state': ?state?.name,
      if (route != null) 'route': '/api/v1/auth/${route.name}',
      'status': ?status,
      'attempt': ?attempt,
      'tokenAcquired': ?acquired,
      'failure': ?failure?.name,
    };
    debugPrint('[EEELibraryAuth] ${jsonEncode(fields)}');
  }
}
