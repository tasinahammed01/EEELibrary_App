import 'dart:async';
import 'dart:convert';

import 'package:eeelibrary/core/config/api_config.dart';
import 'package:eeelibrary/features/auth/data/api_transport.dart';
import 'package:eeelibrary/features/auth/data/backend_auth_client.dart';
import 'package:eeelibrary/features/auth/domain/auth_gateway.dart';
import 'package:eeelibrary/features/auth/domain/auth_models.dart';
import 'package:eeelibrary/features/auth/presentation/auth_controller.dart';

class FakeAuthGateway implements AuthGateway {
  FirebaseIdentity? identity;
  final events = StreamController<FirebaseIdentity?>.broadcast();
  int logins = 0,
      registrations = 0,
      googleLogins = 0,
      verifications = 0,
      reloads = 0,
      resets = 0,
      signOuts = 0;
  final refreshes = <bool>[];
  String? lastEmail, lastName;
  AuthFailure? loginFailure, verificationFailure, resetFailure, googleFailure;
  Completer<void>? loginWait;
  bool googleCancelled = false;
  bool verifiedAfterReload = false;
  @override
  FirebaseIdentity? get currentUser => identity;
  @override
  Stream<FirebaseIdentity?> get authChanges async* {
    yield identity;
    yield* events.stream;
  }

  @override
  Future<void> login(String email, String password) async {
    logins++;
    lastEmail = email;
    if (loginWait != null) await loginWait!.future;
    if (loginFailure != null) throw loginFailure!;
    identity ??= const FirebaseIdentity(
      uid: 'fixture-uid',
      emailVerified: true,
      email: 'reader@fixture.example',
    );
    events.add(identity);
  }

  @override
  Future<void> register(String name, String email, String password) async {
    registrations++;
    lastName = name;
    lastEmail = email;
    identity = FirebaseIdentity(
      uid: 'fixture-uid',
      emailVerified: false,
      email: email,
    );
    events.add(identity);
  }

  @override
  Future<bool> googleLogin() async {
    googleLogins++;
    if (googleFailure != null) throw googleFailure!;
    if (googleCancelled) return false;
    identity = const FirebaseIdentity(
      uid: 'google-fixture-uid',
      emailVerified: true,
      email: 'reader@fixture.example',
    );
    events.add(identity);
    return true;
  }

  @override
  Future<void> sendVerification() async {
    verifications++;
    if (verificationFailure != null) throw verificationFailure!;
  }

  @override
  Future<void> reload() async {
    reloads++;
    if (verifiedAfterReload && identity != null) {
      identity = FirebaseIdentity(
        uid: identity!.uid,
        emailVerified: true,
        email: identity!.email,
      );
    }
  }

  @override
  Future<String> token({bool forceRefresh = false}) async {
    refreshes.add(forceRefresh);
    return forceRefresh ? 'refreshed-fixture-token' : 'fixture-token';
  }

  @override
  Future<void> resetPassword(String email) async {
    resets++;
    lastEmail = email;
    if (resetFailure != null) throw resetFailure!;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    identity = null;
    events.add(null);
  }

  Future<void> close() => events.close();
}

class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers);
  final String method;
  final Uri uri;
  final Map<String, String> headers;
}

String userBody({String status = 'ACTIVE'}) => jsonEncode({
  'id': 'application-user-id',
  'email': 'reader@fixture.example',
  'displayName': 'Reader',
  'status': status,
  'createdAt': '2026-10-14T00:00:00.000Z',
});

class FakeTransport implements ApiTransport {
  final requests = <RecordedRequest>[];
  final responses = <ApiResponse>[];
  Completer<ApiResponse>? wait;
  bool closed = false;
  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
  }) async {
    requests.add(RecordedRequest(method, uri, headers));
    if (wait != null) return wait!.future;
    return responses.isEmpty
        ? ApiResponse(200, userBody())
        : responses.removeAt(0);
  }

  @override
  void close() {
    closed = true;
  }
}

class AuthHarness {
  AuthHarness() {
    client = BackendAuthClient(
      gateway,
      transport,
      ApiConfig('http://127.0.0.1:3000', production: false),
    );
    controller = AuthController(gateway, client);
  }
  final gateway = FakeAuthGateway();
  final transport = FakeTransport();
  late final BackendAuthClient client;
  late final AuthController controller;
  Future<void> start() async {
    controller.start();
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    controller.dispose();
    await gateway.close();
  }
}
