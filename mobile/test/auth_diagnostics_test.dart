import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/core/diagnostics/auth_diagnostics.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';

import 'support/auth_fakes.dart';

void main() {
  test('auth diagnostics serialize only safe enums, status codes and acquisition booleans', () async {
    final lines = <String>[];
    final oldPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      lines.add(message ?? '');
    };
    final h = AuthHarness();
    try {
      await h.start();
      h.transport.responses.addAll([
        const ApiResponse(401, 'private-backend-body'),
        const ApiResponse(401, 'private-backend-body'),
      ]);
      await h.controller.login(
        'private-email@fixture.example',
        'private-password',
      );
      if (!AuthDiagnostics.enabled) {
        expect(lines, isEmpty);
        return;
      }
      final events = lines
          .map(
            (line) =>
                jsonDecode(line.substring(line.indexOf('{')))
                    as Map<String, dynamic>,
          )
          .toList();
      expect(
        events.where((e) => e['event'] == 'response').map((e) => e['status']),
        [401, 401],
      );
      expect(
        events
            .where((e) => e['event'] == 'token')
            .map((e) => e['tokenAcquired']),
        [true, true],
      );
      const keys = {
        'event',
        'operation',
        'action',
        'state',
        'route',
        'status',
        'attempt',
        'tokenAcquired',
        'failure',
      };
      expect(events.every((event) => event.keys.every(keys.contains)), isTrue);
      for (final forbidden in [
        'private-email',
        'private-password',
        'private-backend-body',
        'fixture-token',
        'fixture-uid',
        'Authorization',
        'Bearer',
      ]) {
        expect(lines.join(), isNot(contains(forbidden)));
      }
    } finally {
      await h.dispose();
      debugPrint = oldPrint;
    }
  });
}
