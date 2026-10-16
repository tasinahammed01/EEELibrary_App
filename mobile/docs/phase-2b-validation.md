# Phase 2B validation report

Validated against the existing moved checkout at `D:\ALL Projects\EEE_Library_Project\EEELibrary`. Changes stay within `mobile`. No bug-free guarantee is implied.

## 1. Files inspected

Inspected pubspec/lockfile, Android settings/app/root Gradle Kotlin DSL and manifests, existing public google-services configuration, main/app/Splash, go_router/routes/shell, Login/Register/validators/shared auth widgets, theme/tokens/PageBody, Profile, Welcome and Home regressions, and Phase 2A Firebase/auth types/service/API documentation. Verified package `com.eeelibrary.eeelibrary`, project `eee-library`, existing Web OAuth client, and installed Flutter 3.47.0/Dart 3.13.0 compatibility. Private ADC file contents were not read or copied by mobile work.

## 2. Files created

- `android/app/src/debug/res/xml/debug_network_security.xml`
- `docs/auth-integration.md`
- `lib/app/initialization_failure_app.dart`
- `lib/core/config/api_config.dart`
- `lib/features/auth/auth_status_screen.dart`
- `lib/features/auth/data/api_transport.dart`
- `lib/features/auth/data/backend_auth_client.dart`
- `lib/features/auth/data/firebase_auth_gateway.dart`
- `lib/features/auth/domain/auth_gateway.dart`
- `lib/features/auth/domain/auth_models.dart`
- `lib/features/auth/presentation/auth_controller.dart`
- `lib/features/auth/presentation/auth_scope.dart`
- `lib/features/auth/verification_screen.dart`
- `test/auth_integration_test.dart`
- `test/auth_session_test.dart`
- `test/backend_auth_client_test.dart`
- `test/firebase_auth_gateway_test.dart`
- `test/support/auth_fakes.dart`
- `docs/phase-2b-validation.md`

## 3. Files modified

- `README.md`
- `android/.gitignore`
- `android/app/build.gradle.kts`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/main/AndroidManifest.xml`
- `android/settings.gradle.kts`
- `lib/app/app.dart`
- `lib/core/routing/app_router.dart`
- `lib/core/routing/app_routes.dart`
- `lib/features/auth/login_screen.dart`
- `lib/features/auth/register_screen.dart`
- `lib/features/auth/widgets/auth_widgets.dart`
- `lib/features/profile/profile_screen.dart`
- `lib/features/splash/splash_screen.dart`
- `lib/main.dart`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `pubspec.lock`
- `pubspec.yaml`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugins.cmake`

macOS/Windows plugin registrants changed automatically through Flutter dependency resolution. No backend, Docker, Home, Welcome, design-token/theme, artwork or original test-file hashes changed. No original test was removed or weakened. Kotlin compiler session files are generated artifacts and are now ignored.

## 4. Dependencies added

Official stable compatible `firebase_core 4.15.0`, `firebase_auth 6.7.0`, `google_sign_in 7.2.0`. Lockfile updated. No HTTP/state-management/storage/mock dependency or unrelated package upgrade was requested.

## 5. Android/Gradle changes

Applied Google Services 4.4.4 once in settings/app KTS. Preserved application ID, existing AGP/Kotlin/Flutter plugins and versions. Main manifest now has INTERNET, EEELibrary label and cleartext false. Debug-only network-security XML permits only 10.0.2.2, 127.0.0.1 and localhost; production transport is HTTPS. No production Impeller setting changed.

## 6. Firebase initialization

Bindings and Firebase initialize before production runApp. Native Android Google Services resources provide Firebase client options. Initialization is guarded against duplicate retries and failure shows a safe retry view. Production always receives the real auth gateway.

## 7. Auth-service architecture

AuthGateway domain interface, official FirebaseAuthGateway data adapter, typed identities/failures, ChangeNotifier AuthController and inherited AuthScope. Firebase operations stay out of widgets. Controller owns stream/timer/client lifetime, serializes submissions and rejects late grants after a UID switch or auth-stream failure.

## 8. API client architecture

Centralized ApiConfig + BackendAuthClient + reusable dart:io HttpClient transport. Typed safe DTO parsing, bounded response/timeout handling, no redirects and no certificate weakening. Body-free request interface prevents identity-body injection.

## 9. Registration

Validated name/email/password/confirmation/terms -> Firebase create user -> display-name update/reload -> verification send -> verification screen. No fake success. Bootstrap is deferred until actual verification, consistent with the inspected backend verifier.

## 10. Login

Validated email/password -> Firebase sign-in -> verified-user bootstrap -> backend ACTIVE DTO -> Home. Inputs are preserved after failure and cleared on disposal. Remember Me remains visual; supported default Firebase persistence is unchanged.

## 11. Verification

Unverified Firebase accounts cannot establish normal app identity. Manual check reloads the Firebase user and force-refreshes the ID token before bootstrap. Resend has a one-minute local cooldown; no polling. Sign-out/change-account is available. Current `backend/src/firebase/firebase.service.ts` already rejects `email_verified !== true`; no backend policy was invented or changed. Verification alone grants no paid entitlement.

## 12. Google

Lazy Google 7 initialization -> account authentication -> Firebase GoogleAuthProvider credential exchange -> Firebase ID-token backend bootstrap. Cancellation is quiet; other failures map safely. The Android Web OAuth client is supplied by the existing Google Services configuration.

## 13. Password reset

Uses Firebase sendPasswordResetEmail after local email validation. Generic inbox/spam confirmation, including unknown-account Firebase errors. No backend secrets or raw exception strings are shown.

## 14. Bootstrap

POST `/api/v1/auth/bootstrap`, bearer header, zero request-body bytes. No UID/email/name/role/status/password body. Real loopback HTTP regression confirms this contract. Backend derives identity from verified Firebase claims.

## 15. Me

GET `/api/v1/auth/me` confirms restored and resumed sessions; a startup 404 bootstraps an absent local application user. No calls from widget rebuilds. Backend response, not Firebase currentUser alone, establishes application identity.

## 16. Token refresh/retry

Firebase getIdToken normal first attempt; force refresh once after a 401; retry once. Persistent unauthorized response closes application access and attempts sign-out. No automatic retry on 403/409/503. Tokens are neither logged nor manually persisted and are sent only in Authorization headers.

## 17. Routing/auth state

Existing routes and guest app shell preserved. Added `/verify-email` and `/auth-status`. Initializing waits behind Splash; existing approximately two-second splash minimum retained. Verified + backend ACTIVE reaches Home. Unverified reaches verification. Denied/conflict/unavailable state reaches safe account-access screen. Intentional guest Home/Explore/Library/Profile remain available after sign-out; reader requires sign-in and remains a placeholder.

## 18. Logout

Clears in-memory application user, signs out Firebase and initialized Google session, returns safely to Welcome. No database deletion or account/profile editing. Verification timer is cancelled on successful verification/sign-out and disposal.

## 19. Error mapping

Known Firebase invalid-email/credential/password/user-disabled/email-in-use/weak-password/throttled/network/session-expired codes map to fixed user messages. Google cancellation is nonfatal. Backend 401/403/409/503 and malformed DTOs cannot grant access or reveal raw error bodies.

## 20. Security review

Mobile private Admin credential scan: zero matches. No Admin SDK/service-account import, token print/debugPrint, credential persistence, query-string token, custom token, client role/paid-access trust or certificate bypass. Public Android client configuration was preserved. Bootstrap's identity-free body and redirect refusal are tested. Firebase account-change and late-stream-error races fail closed. No payment/PDF/admin authorization was added.

## 21. Performance review

One startup Firebase initialization, lazy reusable Google initialization, one reusable HTTP client, one owned auth subscription and one temporary cooldown timer. No polling, repeated API calls on rebuild, generic state framework or additional scrolling layer. Foreground checks are serialized and only run for authenticated state.

## 22. Accessibility review

Existing labels, password-toggle tooltips, focus traversal, 48px touch targets, scrolling and SafeAreas retained. Live-region error/success feedback and progress semantics added. Busy inputs, submit/social/checkbox/account-switch/back controls are disabled and double submission is independently blocked in the controller. Live-scope form/verification/error views pass 320/360/390 widths, 2x text and keyboard-inset checks.

## 23. Tests added

84 tests: 25 controller/session cases, five API/real loopback transport cases, 18 official Firebase/Google adapter cases and 36 widget/route/responsive cases. Test-only Firebase/provider/HTTP fakes require no real credentials, real users or external internet. Covers initialization state/failure UX, backend-gated restoration, invalid/valid forms, one-call submissions, verification/terms/confirmation, Google cancellation/exchange, reset, logout, guest routes, inactive DTOs, 401 refresh ceiling, 403/409/503, malformed DTOs, empty bootstrap body, redirect refusal, UID-switch and auth-stream failure races. All original 112 tests remain intact.

## 24. Total Flutter tests

`flutter test`: **196 passed**. Existing Home/Welcome/benefit-grid/auth-presentation/widget regressions passed. Final output saved locally under ignored `build/qa/phase2b-all-tests.log`.

## 25. Formatting/pub/analyze

`dart format .` completed, `flutter pub get` succeeded, `flutter analyze` reports **No issues found**. No introduced warnings/errors/lints remain in Dart analysis.

## 26. Android debug build

`flutter build apk --debug`: **passed**, APK at `build/app/outputs/flutter-apk/app-debug.apk` (debug artifact). Initial builds failed while closing Windows plugin incremental caches. Stopping the Gradle daemon, removing only verified mobile/build plugin Kotlin caches and applying per-process compiler flags resolved this. No repository Gradle version or permanent compiler setting was changed:

```powershell
$env:GRADLE_OPTS = '-Dorg.gradle.project.kotlin.incremental=false -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process -Dorg.gradle.jvmargs=-Xmx2G'
flutter build apk --debug
```

A nonfatal Flutter notice remains: the official firebase_core/firebase_auth plugins still apply KGP and need future built-in Kotlin support before a later Flutter version makes that unsupported. Installed versions build successfully with current Flutter. Debug APK size/performance is not a release APK benchmark.

## 27. Backend regression

Backend/Docker source hashes are unchanged from the phase-start snapshot. No backend tests or migrations were modified. The user's existing 140-test backend result was not claimed as a new rerun; a backend test rerun was unnecessary because no backend change was made.

## 28. Real Firebase checks completed

Built APK launched on the local Android emulator with the invocation-only --no-enable-impeller flag. Native Firebase initialization completed and signed-out startup reached Welcome. Inspected actual Welcome and Login screenshots, scrolled the Login form, confirmed empty submit disabled and Google enabled, opened Register through the account switch, confirmed its heading, then returned to Welcome and used Browse as Guest to reach the existing Home marketplace. No recorded app fatal/layout exceptions occurred during this smoke flow. Backend health returned HTTP 200 and unauthenticated /auth/me HTTP 401. Screenshots and UI evidence remain under ignored build/qa. The constrained headless emulator showed startup frame skips and an unrelated system Messages ANR, which was dismissed; this smoke run is not a physical-device performance benchmark.

No real account creation, verification-email receipt, Google account authorization, authenticated bootstrap or corresponding PostgreSQL row inspection was performed using owner credentials. Automated SDK/boundary/widget tests prove the client behavior, not external Console/inbox/OAuth configuration.

## 29. Manual checks remaining

Follow [the Android integration checklist](auth-integration.md#real-android-integration-checklist) using a disposable email and Google account you control: receive verification, finish bootstrap, inspect one local User, restore via /me, email login/logout/reset, Google OAuth/bootstrap, cancellation, backend account denials, offline UX and physical-device rendering. Do not print, copy or record bearer tokens. Validate actual release HTTPS/signing certificates separately.

## 30. Known limitations

Android Firebase setup only; iOS/web/desktop setup and production deployment are not claimed. Release requires an actual HTTPS backend URL and production signing/provider checks. No paid entitlements, PDF security, payments, phone/MFA, custom tokens, profile editing, admin authentication or persistence customization. Firebase/network quotas still apply; cooldown is local UX, not authorization. Real-provider and physical-device integration remains manual. Windows plugin cache workaround and future Flutter/Kotlin plugin compatibility are recorded above.

## 31. Recommended next phase

Complete the controlled real-account Android checklist and release transport/signing validation first. Then define and implement backend-authoritative library/entitlement behavior with dedicated integration tests, before adding payments or secure PDF authorization. No such future capability was implemented in Phase 2B.
