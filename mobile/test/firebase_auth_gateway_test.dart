import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eeelibrary/features/auth/data/firebase_auth_gateway.dart';
import 'package:eeelibrary/features/auth/domain/auth_models.dart';

class StubUser extends Fake implements User {
  String? name;
  int reloads = 0, verifications = 0;
  final refreshes = <bool>[];
  @override
  String get uid => 'sdk-fixture-uid';
  @override
  String get email => 'sdk@fixture.example';
  @override
  bool get emailVerified => false;
  @override
  Future<void> updateDisplayName(String? value) async {
    name = value;
  }

  @override
  Future<void> reload() async {
    reloads++;
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    verifications++;
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    refreshes.add(forceRefresh);
    return 'firebase-fixture-token';
  }
}

class StubCredential extends Fake implements UserCredential {
  StubCredential(this.user);
  @override
  final User? user;
}

class StubFirebase extends Fake implements FirebaseAuth {
  StubUser? identity = StubUser();
  String? failureCode;
  int logins = 0,
      registrations = 0,
      credentialLogins = 0,
      resets = 0,
      signOuts = 0;
  String? email;
  AuthCredential? credential;
  @override
  User? get currentUser => identity;
  @override
  Stream<User?> authStateChanges() => Stream.value(identity);
  void failIfNeeded() {
    if (failureCode != null) {
      throw FirebaseAuthException(
        code: failureCode!,
        message: 'raw secret exception',
      );
    }
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    logins++;
    this.email = email;
    failIfNeeded();
    return StubCredential(identity);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registrations++;
    this.email = email;
    failIfNeeded();
    return StubCredential(identity);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentialLogins++;
    this.credential = credential;
    failIfNeeded();
    return StubCredential(identity);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resets++;
    this.email = email;
    failIfNeeded();
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    identity = null;
  }
}

class StubGoogleAccount extends Fake implements GoogleSignInAccount {
  @override
  GoogleSignInAuthentication get authentication =>
      const GoogleSignInAuthentication(idToken: 'google-fixture-token');
}

class StubGoogle extends Fake implements GoogleSignIn {
  int initializations = 0, authentications = 0, signOuts = 0;
  bool cancel = false, initializationFails = false;
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializations++;
    if (initializationFails) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );
    }
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    authentications++;
    if (cancel) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    }
    return StubGoogleAccount();
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

void main() {
  late StubFirebase firebase;
  late StubGoogle google;
  late FirebaseAuthGateway gateway;
  setUp(() {
    firebase = StubFirebase();
    google = StubGoogle();
    gateway = FirebaseAuthGateway(firebase, google);
  });
  test('adapter forwards email sign-in without retaining passwords', () async {
    await gateway.login('sdk@fixture.example', 'fixture-password');
    expect(firebase.logins, 1);
    expect(firebase.email, 'sdk@fixture.example');
    expect(gateway.currentUser!.uid, 'sdk-fixture-uid');
    expect((await gateway.authChanges.first)!.emailVerified, isFalse);
  });
  test('registration updates name then reloads; verification and refresh use official APIs', () async {
    await gateway.register(
      'SDK Reader',
      'sdk@fixture.example',
      'fixture-password',
    );
    expect(firebase.registrations, 1);
    expect(firebase.identity!.name, 'SDK Reader');
    expect(firebase.identity!.reloads, 1);
    await gateway.sendVerification();
    await gateway.reload();
    await gateway.token();
    await gateway.token(forceRefresh: true);
    expect(firebase.identity!.verifications, 1);
    expect(firebase.identity!.reloads, 2);
    expect(firebase.identity!.refreshes, [false, true]);
  });
  test('Google initializes once, exchanges ID token for Firebase credential and signs out both', () async {
    expect(await gateway.googleLogin(), isTrue);
    expect(await gateway.googleLogin(), isTrue);
    expect(google.initializations, 1);
    expect(firebase.credentialLogins, 2);
    expect(firebase.credential!.providerId, 'google.com');
    expect(
      (firebase.credential as OAuthCredential).idToken,
      'google-fixture-token',
    );
    await gateway.signOut();
    expect(firebase.signOuts, 1);
    expect(google.signOuts, 1);
    expect(gateway.currentUser, isNull);
  });
  test(
    'Google cancellation never reaches Firebase credential exchange',
    () async {
      google.cancel = true;
      expect(await gateway.googleLogin(), isFalse);
      expect(firebase.credentialLogins, 0);
    },
  );
  test(
    'failed Google initialization recovers on the next explicit attempt',
    () async {
      google.initializationFails = true;
      await expectLater(gateway.googleLogin(), throwsA(isA<AuthFailure>()));
      google.initializationFails = false;
      expect(await gateway.googleLogin(), isTrue);
      expect(google.initializations, 2);
    },
  );
  test(
    'reset uses Firebase and missing sessions cannot reload or send tokens',
    () async {
      await gateway.resetPassword('sdk@fixture.example');
      expect(firebase.resets, 1);
      firebase.identity = null;
      for (final action in [
        gateway.reload,
        gateway.sendVerification,
        () => gateway.token(),
      ]) {
        await expectLater(
          action(),
          throwsA(
            isA<AuthFailure>().having(
              (e) => e.kind,
              'kind',
              AuthFailureKind.unauthorized,
            ),
          ),
        );
      }
    },
  );
  for (final entry in <String, AuthFailureKind>{
    'invalid-email': AuthFailureKind.invalidEmail,
    'wrong-password': AuthFailureKind.invalidCredentials,
    'invalid-credential': AuthFailureKind.invalidCredentials,
    'user-not-found': AuthFailureKind.invalidCredentials,
    'user-disabled': AuthFailureKind.disabled,
    'email-already-in-use': AuthFailureKind.emailInUse,
    'weak-password': AuthFailureKind.weakPassword,
    'too-many-requests': AuthFailureKind.throttled,
    'network-request-failed': AuthFailureKind.network,
    'user-token-expired': AuthFailureKind.unauthorized,
    'invalid-user-token': AuthFailureKind.unauthorized,
    'unrecognized': AuthFailureKind.unknown,
  }.entries) {
    test('Firebase ${entry.key} maps to sanitized ${entry.value}', () async {
      firebase.failureCode = entry.key;
      await expectLater(
        gateway.login('sdk@fixture.example', 'fixture-password'),
        throwsA(
          isA<AuthFailure>()
              .having((e) => e.kind, 'kind', entry.value)
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('raw secret')),
              ),
        ),
      );
    });
  }
}
