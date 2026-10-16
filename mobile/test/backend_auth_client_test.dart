import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/core/config/api_config.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/auth/data/backend_auth_client.dart';
import 'package:eeelibrary/features/auth/domain/auth_models.dart';

import 'support/auth_fakes.dart';

void main() {
  test('production requires HTTPS and excludes unsafe URL components', () {
    for (final value in [
      'http://10.0.2.2:3000',
      'https://user:password@example.com',
      'https://example.com/path',
      'https://example.com?token=value',
      'https://example.com#fragment',
      '',
    ]) {
      expect(() => ApiConfig(value, production: true), throwsFormatException);
    }
    expect(
      ApiConfig('https://api.example.com', production: true).baseUrl.scheme,
      'https',
    );
  });
  test('development cleartext is confined to the documented local hosts', () {
    expect(
      ApiConfig('http://10.0.2.2:3000', production: false).baseUrl.host,
      '10.0.2.2',
    );
    expect(
      () => ApiConfig('http://example.com', production: false),
      throwsFormatException,
    );
  });
  test('malformed application DTO fails closed', () {
    for (final value in [
      null,
      {},
      {
        'id': 'x',
        'email': 'a',
        'displayName': 'b',
        'status': 'ADMIN',
        'createdAt': '2026-10-14',
      },
    ]) {
      expect(
        () => ApplicationUser.fromJson(value),
        throwsA(isA<AuthFailure>()),
      );
    }
  });
  test(
    'tokens appear only in Authorization, and backend error bodies are ignored',
    () async {
      final h = AuthHarness();
      addTearDown(h.dispose);
      h.gateway.identity = const FirebaseIdentity(
        uid: 'fixture',
        emailVerified: true,
      );
      h.transport.responses.add(const ApiResponse(409, 'private details'));
      await expectLater(
        h.client.bootstrap(),
        throwsA(
          isA<BackendFailure>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('private')),
          ),
        ),
      );
      final r = h.transport.requests.single;
      expect(r.headers['Authorization'], 'Bearer fixture-token');
      expect(r.uri.query, isEmpty);
      expect(r.uri.userInfo, isEmpty);
    },
  );
  test(
    'real transport POST body is empty and bearer is never redirected',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final gateway = FakeAuthGateway()
        ..identity = const FirebaseIdentity(
          uid: 'fixture',
          emailVerified: true,
        );
      final io = IoApiTransport();
      final client = BackendAuthClient(
        gateway,
        io,
        ApiConfig('http://127.0.0.1:${server.port}', production: false),
      );
      addTearDown(() async {
        client.close();
        await server.close(force: true);
        await gateway.close();
      });
      var calls = 0;
      String? body;
      String? authorization;
      server.listen((request) async {
        calls++;
        body = await utf8.decoder.bind(request).join();
        authorization = request.headers.value('authorization');
        if (calls == 1) {
          request.response.headers.contentType = ContentType.json;
          request.response.write(userBody());
        } else {
          request.response.statusCode = 302;
          request.response.headers.set(
            'location',
            'https://untrusted.example/',
          );
        }
        await request.response.close();
      });
      await client.bootstrap();
      expect(body, isEmpty);
      expect(authorization, 'Bearer fixture-token');
      await expectLater(client.me(), throwsA(isA<BackendFailure>()));
      expect(calls, 2);
    },
  );
}
