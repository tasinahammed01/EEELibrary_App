import 'auth_models.dart';

abstract interface class AuthGateway {
  FirebaseIdentity? get currentUser;
  Stream<FirebaseIdentity?> get authChanges;
  Future<void> login(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<bool> googleLogin();
  Future<void> sendVerification();
  Future<void> reload();
  Future<String> token({bool forceRefresh = false});
  Future<void> resetPassword(String email);
  Future<void> signOut();
}
