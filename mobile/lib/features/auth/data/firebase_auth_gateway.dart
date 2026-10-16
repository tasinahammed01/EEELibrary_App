import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_gateway.dart';
import '../domain/auth_models.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._firebase, this._google);
  final FirebaseAuth _firebase;
  final GoogleSignIn _google;
  Future<void>? _googleInitialization;
  FirebaseIdentity? _identity(User? user) => user == null
      ? null
      : FirebaseIdentity(
          uid: user.uid,
          email: user.email,
          emailVerified: user.emailVerified,
        );
  @override
  FirebaseIdentity? get currentUser => _identity(_firebase.currentUser);
  @override
  Stream<FirebaseIdentity?> get authChanges =>
      _firebase.authStateChanges().map(_identity);

  Future<T> _firebaseCall<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw _map(error.code);
    }
  }

  AuthFailure _map(String code) => AuthFailure(switch (code) {
    'invalid-email' => AuthFailureKind.invalidEmail,
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => AuthFailureKind.invalidCredentials,
    'user-token-expired' ||
    'invalid-user-token' ||
    'no-current-user' => AuthFailureKind.unauthorized,
    'user-disabled' => AuthFailureKind.disabled,
    'email-already-in-use' => AuthFailureKind.emailInUse,
    'weak-password' => AuthFailureKind.weakPassword,
    'too-many-requests' => AuthFailureKind.throttled,
    'network-request-failed' => AuthFailureKind.network,
    _ => AuthFailureKind.unknown,
  });
  @override
  Future<void> login(String email, String password) => _firebaseCall(() async {
    await _firebase.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  });
  @override
  Future<void> register(String name, String email, String password) =>
      _firebaseCall(() async {
        final result = await _firebase.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = result.user;
        if (user == null) throw const AuthFailure(AuthFailureKind.unknown);
        await user.updateDisplayName(name);
        await user.reload();
      });
  @override
  Future<bool> googleLogin() async {
    try {
      try {
        await (_googleInitialization ??= _google.initialize());
      } catch (_) {
        _googleInitialization = null;
        rethrow;
      }
      if (!_google.supportsAuthenticate()) {
        throw const AuthFailure(AuthFailureKind.unavailable);
      }
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(AuthFailureKind.invalidCredentials);
      }
      await _firebaseCall(
        () => _firebase.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        ),
      );
      return true;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      throw const AuthFailure(AuthFailureKind.unavailable);
    }
  }

  @override
  Future<void> sendVerification() => _firebaseCall(() async {
    final user = _firebase.currentUser;
    if (user == null) throw const AuthFailure(AuthFailureKind.unauthorized);
    await user.sendEmailVerification();
  });
  @override
  Future<void> reload() => _firebaseCall(() async {
    final user = _firebase.currentUser;
    if (user == null) throw const AuthFailure(AuthFailureKind.unauthorized);
    await user.reload();
  });
  @override
  Future<String> token({bool forceRefresh = false}) => _firebaseCall(() async {
    final token = await _firebase.currentUser?.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw const AuthFailure(AuthFailureKind.unauthorized);
    }
    return token;
  });
  @override
  Future<void> resetPassword(String email) =>
      _firebaseCall(() => _firebase.sendPasswordResetEmail(email: email));
  @override
  Future<void> signOut() async {
    AuthFailure? failure;
    try {
      await _firebaseCall(_firebase.signOut);
    } on AuthFailure catch (error) {
      failure = error;
    }
    if (_googleInitialization != null) {
      try {
        await _googleInitialization;
        await _google.signOut();
      } catch (_) {
        failure ??= const AuthFailure(AuthFailureKind.unavailable);
      }
    }
    if (failure != null) throw failure;
  }
}
