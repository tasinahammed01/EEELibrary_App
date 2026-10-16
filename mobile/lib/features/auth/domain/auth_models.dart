enum AuthFeedbackTone { error, notice, success }

enum AuthStatus {
  initializing,
  signedOut,
  verificationRequired,
  authenticated,
  error,
}

enum AuthFailureKind {
  invalidCredentials,
  invalidEmail,
  disabled,
  emailInUse,
  weakPassword,
  throttled,
  network,
  unauthorized,
  denied,
  conflict,
  unavailable,
  cancelled,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind);
  final AuthFailureKind kind;
  String get message => switch (kind) {
    AuthFailureKind.invalidCredentials => 'Email or password is incorrect.',
    AuthFailureKind.invalidEmail => 'Enter a valid email address.',
    AuthFailureKind.disabled || AuthFailureKind.denied => 'This account cannot access EEELibrary right now. Sign out or contact support.',
    AuthFailureKind.emailInUse =>
      'Unable to create this account. Try signing in or use another email.',
    AuthFailureKind.weakPassword =>
      'Choose a stronger password with at least 8 characters.',
    AuthFailureKind.throttled =>
      'Too many attempts. Please wait before trying again.',
    AuthFailureKind.network =>
      "We couldn't connect to EEELibrary. Check your connection and try again.",
    AuthFailureKind.unauthorized =>
      'We could not complete sign-in. Please try again.',
    AuthFailureKind.conflict => 'We could not link this account safely. Contact support or use your original sign-in.',
    AuthFailureKind.unavailable =>
      'EEELibrary is temporarily unavailable. Please try again in a moment.',
    AuthFailureKind.cancelled => '',
    AuthFailureKind.unknown => 'Something went wrong. Please try again.',
  };
  @override
  String toString() => message;
}

class FirebaseIdentity {
  const FirebaseIdentity({
    required this.uid,
    required this.emailVerified,
    this.email,
  });
  final String uid;
  final bool emailVerified;
  final String? email;
}

class ApplicationUser {
  const ApplicationUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    required this.createdAt,
  });
  factory ApplicationUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const AuthFailure(AuthFailureKind.unavailable);
    }
    final id = value['id'];
    final email = value['email'];
    final name = value['displayName'];
    final status = value['status'];
    final created = value['createdAt'];
    if (id is! String ||
        id.isEmpty ||
        email is! String ||
        name is! String ||
        status is! String ||
        !{'ACTIVE', 'DISABLED', 'SUSPENDED'}.contains(status) ||
        created is! String ||
        DateTime.tryParse(created) == null) {
      throw const AuthFailure(AuthFailureKind.unavailable);
    }
    return ApplicationUser(
      id: id,
      email: email,
      displayName: name,
      status: status,
      createdAt: DateTime.parse(created),
    );
  }
  final String id;
  final String email;
  final String displayName;
  final String status;
  final DateTime createdAt;
  bool get isActive => status == 'ACTIVE';
}
