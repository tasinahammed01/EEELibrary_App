import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app/app.dart';
import 'app/initialization_failure_app.dart';
import 'core/config/api_config.dart';
import 'features/auth/data/api_transport.dart';
import 'features/auth/data/backend_auth_client.dart';
import 'features/auth/data/firebase_auth_gateway.dart';
import 'features/auth/presentation/auth_controller.dart';

bool _initializing = false;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  if (_initializing) return;
  _initializing = true;
  try {
    final config = ApiConfig.fromEnvironment();
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final gateway = FirebaseAuthGateway(
      FirebaseAuth.instance,
      GoogleSignIn.instance,
    );
    final session = AuthController(
      gateway,
      BackendAuthClient(gateway, IoApiTransport(), config),
    );
    runApp(EEELibraryApp(auth: session));
  } catch (_) {
    runApp(InitializationFailureApp(onRetry: () => unawaited(_start())));
  } finally {
    _initializing = false;
  }
}
