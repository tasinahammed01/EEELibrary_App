import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/auth_diagnostics.dart';
import '../data/backend_auth_client.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._gateway, this._backend);
  final AuthGateway _gateway;
  final BackendAuthClient _backend;
  StreamSubscription<FirebaseIdentity?>? _subscription;
  Timer? _resendTimer;
  bool _disposed = false;
  bool _streamFailed = false;
  bool _started = false;
  bool _busy = false;
  bool _resendReady = true;
  bool _splashReady = false;
  int _operation = 0;
  AuthStatus _status = AuthStatus.initializing;
  ApplicationUser? _user;
  String? _sessionUid;
  AuthStatus? _lastDiagnosticStatus;
  String? _message;
  AuthFailureKind? _failureKind;
  AuthFeedbackTone _feedbackTone = AuthFeedbackTone.error;
  bool _sessionExpired = false;
  AuthStatus get status => _status;
  ApplicationUser? get user => _user;
  bool get busy => _busy;
  bool get splashReady => _splashReady;
  bool get canResend => _resendReady && !_busy;
  String? get message => _message;
  AuthFailureKind? get failureKind => _failureKind;
  AuthFeedbackTone get feedbackTone => _feedbackTone;
  bool get sessionExpired => _sessionExpired;
  String? get verificationEmail => _gateway.currentUser?.email;
  void _notify() {
    if (_disposed) return;
    if (_lastDiagnosticStatus != _status) {
      _lastDiagnosticStatus = _status;
      AuthDiagnostics.emit(
        AuthTraceEvent.state,
        operation: _operation,
        state: _status,
      );
    }
    notifyListeners();
  }

  void start() {
    if (_subscription != null) return;
    _subscription = _gateway.authChanges.listen(
      (identity) {
        if (_disposed) return;
        // Stream snapshots can be delivered after currentUser has moved on.
        final current = _gateway.currentUser;
        if (_busy || identity?.uid != current?.uid) {
          AuthDiagnostics.emit(
            AuthTraceEvent.streamIgnored,
            operation: _operation,
          );
          return;
        }
        _started = true;
        if (current == null) {
          _sessionUid = null;
          if (_status != AuthStatus.signedOut || _user != null) {
            _operation++;
            final lostSession =
                _status == AuthStatus.authenticated && _user != null;
            _user = null;
            _status = AuthStatus.signedOut;
            _failureKind = lostSession ? AuthFailureKind.unauthorized : null;
            _sessionExpired = lostSession;
            _feedbackTone = AuthFeedbackTone.error;
            _message = lostSession
                ? 'Your session expired. Please sign in again.'
                : null;
            // Duplicate signed-out notifications leave existing failure feedback intact.
            _notify();
          }
        } else if (_sessionUid != current.uid ||
            _status == AuthStatus.initializing) {
          _user = null;
          _status = AuthStatus.initializing;
          unawaited(_run(AuthAction.restore, () => _resolve(restore: true)));
        }
      },
      onError: (Object _) {
        if (!_disposed) {
          _streamFailed = true;
          _user = null;
          _status = AuthStatus.error;
          _failureKind = AuthFailureKind.unavailable;
          _sessionExpired = false;
          _feedbackTone = AuthFeedbackTone.error;
          _message = const AuthFailure(AuthFailureKind.unavailable).message;
          _notify();
        }
      },
    );
  }

  void completeSplash() {
    _splashReady = true;
    _notify();
  }

  Future<void> _run(AuthAction name, Future<void> Function() action) async {
    if (_busy || _disposed) return;
    final hadSession = _status == AuthStatus.authenticated && _user != null;
    final initialUid = _gateway.currentUser?.uid;
    _busy = true;
    _streamFailed = false;
    _message = null;
    _failureKind = null;
    _sessionExpired = false;
    _feedbackTone = AuthFeedbackTone.error;
    final operation = ++_operation;
    AuthDiagnostics.emit(
      AuthTraceEvent.started,
      operation: operation,
      action: name,
    );
    _notify();
    try {
      await action();
    } catch (error) {
      if (!_disposed && operation == _operation) {
        final failure = error is AuthFailure
            ? error
            : const AuthFailure(AuthFailureKind.unknown);
        AuthDiagnostics.emit(
          AuthTraceEvent.failure,
          operation: operation,
          action: name,
          failure: failure.kind,
        );
        _failureKind = failure.kind;
        _feedbackTone = failure.kind == AuthFailureKind.network
            ? AuthFeedbackTone.notice
            : AuthFeedbackTone.error;
        _sessionExpired =
            failure.kind == AuthFailureKind.unauthorized &&
            hadSession &&
            name == AuthAction.retry &&
            (_gateway.currentUser == null ||
                _gateway.currentUser?.uid == initialUid);
        _user = null;
        if (failure.kind == AuthFailureKind.unauthorized) {
          try {
            await _gateway.signOut();
          } catch (_) {
            /* Local access remains closed. */
          }
          _sessionUid = null;
          _status = AuthStatus.signedOut;
        } else if (failure.kind == AuthFailureKind.disabled) {
          _status = AuthStatus.error;
        } else if (_gateway.currentUser?.emailVerified == false) {
          _status = AuthStatus.verificationRequired;
        } else {
          _status = _gateway.currentUser == null
              ? AuthStatus.signedOut
              : AuthStatus.error;
        }
        _message = switch ((failure.kind, name, _sessionExpired)) {
          (_, _, true) => 'Your session expired. Please sign in again.',
          (AuthFailureKind.invalidCredentials, AuthAction.google, _) =>
            'We could not complete Google sign-in. Please try again.',
          _ => failure.message,
        };
      }
    } finally {
      if (!_disposed && operation == _operation) {
        _busy = false;
        AuthDiagnostics.emit(
          AuthTraceEvent.finished,
          operation: operation,
          action: name,
          state: _status,
        );
        _notify();
      }
    }
  }

  Future<void> _resolve({bool restore = false, String? expectedUid}) async {
    if (_streamFailed) throw const AuthFailure(AuthFailureKind.unavailable);
    final identity = _gateway.currentUser;
    _user = null;
    if (expectedUid != null && identity?.uid != expectedUid) {
      throw const AuthFailure(AuthFailureKind.unauthorized);
    }
    _sessionUid = identity?.uid;
    if (identity == null) {
      _status = AuthStatus.signedOut;
      return;
    }
    if (!identity.emailVerified) {
      _status = AuthStatus.verificationRequired;
      return;
    }
    ApplicationUser user;
    if (restore) {
      try {
        user = await _backend.me();
      } on BackendFailure catch (error) {
        if (error.statusCode != 404) rethrow;
        user = await _backend.bootstrap();
      }
    } else {
      user = await _backend.bootstrap();
    }
    if (_disposed) return;
    if (_streamFailed) throw const AuthFailure(AuthFailureKind.unavailable);
    if (_gateway.currentUser?.uid != identity.uid) {
      throw const AuthFailure(AuthFailureKind.unauthorized);
    }
    if (!user.isActive) throw const AuthFailure(AuthFailureKind.denied);
    _resendTimer?.cancel();
    _resendReady = true;
    _user = user;
    _status = AuthStatus.authenticated;
  }

  Future<void> login(String email, String password) =>
      _run(AuthAction.login, () async {
        await _gateway.login(email.trim(), password);
        await _resolve();
      });
  Future<void> register(String name, String email, String password) =>
      _run(AuthAction.register, () async {
        await _gateway.register(name.trim(), email.trim(), password);
        await _resolve();
        if (_status == AuthStatus.verificationRequired) {
          await _gateway.sendVerification();
          _verificationSent();
        }
      });
  Future<void> googleLogin() => _run(AuthAction.google, () async {
    if (await _gateway.googleLogin()) {
      await _resolve();
    } else {
      if (!_started || _status == AuthStatus.initializing) {
        _status = AuthStatus.signedOut;
      }
    }
  });
  void _verificationSent() {
    if (_disposed) return;
    _feedbackTone = AuthFeedbackTone.success;
    _message = 'Verification email sent. Check your inbox and spam folder.';
    _resendReady = false;
    _resendTimer?.cancel();
    _resendTimer = Timer(const Duration(minutes: 1), () {
      _resendReady = true;
      _notify();
    });
  }

  Future<void> resendVerification() async {
    if (!canResend) return;
    await _run(AuthAction.resend, () async {
      await _gateway.sendVerification();
      _verificationSent();
    });
  }

  Future<void> checkVerification() => _run(AuthAction.verify, () async {
    final uid = _gateway.currentUser?.uid;
    if (uid == null) throw const AuthFailure(AuthFailureKind.unauthorized);
    await _gateway.reload();
    if (_gateway.currentUser?.uid != uid) {
      throw const AuthFailure(AuthFailureKind.unauthorized);
    }
    if (_gateway.currentUser?.emailVerified == true) {
      await _gateway.token(
        forceRefresh: true,
      ); // Mint the updated email_verified claim before bootstrap.
      await _resolve(expectedUid: uid);
    } else {
      _status = AuthStatus.verificationRequired;
      _feedbackTone = AuthFeedbackTone.notice;
      _message = 'Your email is not verified yet. Open the link in your inbox, then check again.';
    }
  });
  Future<void> resetPassword(String email) => _run(AuthAction.reset, () async {
    try {
      await _gateway.resetPassword(email.trim());
    } on AuthFailure catch (error) {
      if (error.kind != AuthFailureKind.invalidCredentials &&
          error.kind != AuthFailureKind.emailInUse) {
        rethrow;
      }
    }
    _feedbackTone = AuthFeedbackTone.success;
    _message = 'If this email can receive a reset link, check its inbox and spam folder.';
  });
  Future<void> retry() => _run(AuthAction.retry, () => _resolve(restore: true));
  Future<void> refreshSession() async {
    if (_status == AuthStatus.authenticated && !_busy) await retry();
  }

  Future<void> signOut() => _run(AuthAction.logout, () async {
    _resendTimer?.cancel();
    _resendReady = true;
    _user = null;
    await _gateway.signOut();
    _sessionUid = null;
    _status = AuthStatus.signedOut;
  });
  @override
  void dispose() {
    _disposed = true;
    _operation++;
    _subscription?.cancel();
    _resendTimer?.cancel();
    _backend.close();
    super.dispose();
  }
}
