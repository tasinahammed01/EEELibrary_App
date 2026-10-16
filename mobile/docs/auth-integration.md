# EEELibrary mobile authentication

Phase 2B connects the existing Android UI to Firebase client authentication and the existing Phase 2A backend. It does not change backend identity verification, account status or entitlement policy.

## Configuration and running

The Android application ID stays `com.eeelibrary.eeelibrary`. The existing `android/app/google-services.json` is public Firebase client configuration, consumed by Google Services 4.4.4. It must belong to project `eee-library` and include the Android application plus a Web OAuth client for Google sign-in. SHA-1/SHA-256 and Email/Password + Google providers are already configured according to the supplied environment information.

Dependencies are official `firebase_core ^4.15.0`, `firebase_auth ^6.7.0`, and `google_sign_in ^7.2.0`. No state-management, HTTP, persistence or mocking package was added. The existing Android/Gradle versions were preserved.

From `mobile`:

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000 --no-enable-impeller
```

The debug default is `http://10.0.2.2:3000`. `ApiConfig` also accepts debug HTTP for `127.0.0.1` or `localhost`, or HTTPS. All other cleartext origins, URL credentials, queries, fragments and path prefixes are rejected. Android permits cleartext only for those three local hosts in the debug source set; main/release uses cleartext false. Physical-device debugging can use a trusted HTTPS endpoint or `adb reverse tcp:3000 tcp:3000` with `http://127.0.0.1:3000`.

Profile/release configuration requires an explicit HTTPS URL:

```powershell
flutter build apk --release --dart-define=BACKEND_BASE_URL=https://YOUR-BACKEND-HOST
```

Use a real deployed host and trusted certificate. Missing/invalid configuration deliberately opens the initialization-failure view. Release signing/deployment and non-Android Firebase configuration are outside this phase. Do not disable certificate validation. The emulator Impeller flag is local to the invocation; no production renderer setting was changed.

Admin ADC/GOOGLE_APPLICATION_CREDENTIALS belongs exclusively to the backend process. No service-account file or Admin SDK is required, read or shipped by mobile.

## Architecture and trust boundary

`main.dart` initializes bindings and Firebase once before constructing the app. A guarded retry presents a safe startup error instead of an apparently authenticated app. Android Firebase options come from the Google Services resources; no generated Dart secret configuration is needed.

`AuthGateway` isolates Firebase operations. `FirebaseAuthGateway` wraps the official Firebase and Google APIs, maps known codes to fixed messages and never retains passwords. Google is initialized lazily once; failed initialization can be retried. Google ID-token credentials are exchanged with Firebase before any backend request.

`AuthController` owns in-memory presentation/session state, the initial auth subscription, serialized operations and the verification resend timer. `AuthScope` provides the existing feature widgets with that controller. The production entry point always constructs the real gateway; a missing scope leaves screens read-only and cannot authenticate. No test-auth flag or runtime bypass exists.

`BackendAuthClient` obtains Firebase ID tokens and sends them exclusively as `Authorization: Bearer ...`. `IoApiTransport` reuses one HttpClient, rejects redirects, bounds response size to 64 KiB, uses a 5-second connection timeout and a 15-second request timeout. No custom certificate acceptance or token/password persistence exists.

- POST `/api/v1/auth/bootstrap` has zero request-body bytes. UID, email, display name, role, status and password are never sent in its body.
- GET `/api/v1/auth/me` confirms restored/resumed application state. A startup 404 invokes bootstrap once for an absent local user.
- One 401 forces token refresh and retries the same request once. A second 401 closes local application access and attempts Firebase/provider sign-out. Other failures are not retried automatically.
- The safe DTO contains id, email, displayName, status and createdAt. Only a successful backend response with ACTIVE status establishes normal application state. DISABLED/SUSPENDED, malformed DTOs, 403, 409 and 503 cannot grant access.
- The Firebase UID is checked before and after requests to reject an account switch during a pending request. It is never submitted as client-authoritative identity.

## Flows and explicit verification policy

Registration validates name/email/password/confirmation/terms, creates the Firebase user, updates the Firebase display name and sends verification. It immediately shows `/verify-email`. It does not pretend verification or backend bootstrap has succeeded.

**The current Phase 2A implementation inspected in this repository already rejects tokens without `email_verified == true`.** Consequently, registration and existing unverified sessions defer bootstrap until verification is confirmed. This reflects the existing backend contract; the frontend did not invent or modify a backend policy.

The verification screen offers resend, manual check and sign-out/change-account. Resend has a 60-second local cooldown and Firebase also enforces quotas. Checking reloads the Firebase user, checks its current verified flag, forces a fresh ID token to update claims, then bootstraps. There is no verification polling and emailVerified never implies paid access.

Login uses Firebase email/password sign-in, then verified-user backend bootstrap. Google uses the official Google 7 API, Firebase GoogleAuthProvider credentials and the same backend bootstrap. Cancellation remains quiet. A backend denial keeps application access closed and displays `/auth-status` with retry/sign-out. Password reset calls Firebase after valid email input and gives a generic inbox message, including for unknown accounts.

Startup waits for Firebase initial state and backend confirmation, retaining the existing approximately two-second splash minimum. Verified existing accounts use `/me`, while unverified accounts open verification. Foreground resume refreshes an authenticated session once; widget rebuilds do not trigger requests. Auth-required reader navigation redirects signed-out users to Login. Existing Home/Explore/Library/Profile guest routes remain intentional public browsing placeholders, without paid-access behavior.

Profile displays only the safe application DTO and supplies sign-out. Logout clears in-memory application identity, signs out Firebase and the Google session if initialized, and returns to Welcome. It does not delete server records. Remember Me remains a visual preference; Firebase uses its supported default persistence. Password text exists only in the form and is cleared on disposal.

## UX, performance and accessibility

Existing branding, hero assets, theme/tokens, Welcome and Home marketplace are preserved. Existing fields, validation, toggles, touch targets, scrolling and keyboard actions remain. Busy state disables form inputs, submit/social actions, account switches, checkbox edits and form back navigation. The controller independently blocks duplicate submissions. Safe inline feedback uses live-region semantics and progress indicators announce authentication activity. Verification/errors use SafeArea through PageBody and scrolling with wrapping buttons.

The initial Firebase subscription, Google initialization, reusable HTTP client and resend timer have explicit owners/disposal. No polling, database client, fake API, new scrolling layer or generic state library was introduced.

## Real Android integration checklist

Use only accounts and inboxes you control. Do not paste tokens into terminals, screenshots, bug reports or logs.

1. Launch with the backend running; confirm Splash -> Welcome, existing branding/hero and Browse as Guest -> Home.
2. Register a disposable, nonprivileged email. Confirm the actual Firebase user/display name and verification email. Before verification, confirm no local application User was created and only the verification UI is accessible.
3. Exercise resend/cooldown and an unverified manual check. Open the email link, return and check again; confirm Home appears only after backend bootstrap.
4. Inspect PostgreSQL through existing trusted admin tooling: confirm a single application User linked to that Firebase identity, with ACTIVE status. Never copy Admin credentials into mobile.
5. Relaunch while signed in; confirm `/me` restores state, without Welcome flashing. Check backend success through sanitized status telemetry or debugger metadata; do not log bearer headers.
6. Sign out from Profile; confirm Welcome and no application-user deletion. Sign in with email/password and confirm Home.
7. Try invalid credentials and offline networking; confirm safe errors, restored controls and preserved input. Test Forgot Password and confirm the generic response plus actual email delivery.
8. Sign in through the Google account chooser with an account you control. Confirm Firebase credential sign-in, successful bootstrap and one linked local User. Cancel a second chooser attempt; confirm no fatal error.
9. Using a nonprivileged QA account and existing backend tooling, test DISABLED/SUSPENDED, bootstrap conflict, backend unavailability and persistent unauthorized state. Restore QA state afterward.
10. Verify small-screen/keyboard/text scaling on physical Android hardware and production rendering without the emulator-only Impeller workaround. Validate release HTTPS and the actual release signing certificate/provider configuration before release.

Automated boundary/widget tests run without real users, credentials or internet. Passing them does not prove real Google OAuth, Firebase Console configuration, email delivery, release signing or production networking.

Primary integration references: [FlutterFire setup](https://firebase.google.com/docs/flutter/setup), [Firebase password authentication](https://firebase.google.com/docs/auth/flutter/password-auth), [Firebase federated authentication](https://firebase.google.com/docs/auth/flutter/federated-auth), [Google Sign-In package](https://pub.dev/packages/google_sign_in), [Android Google Sign-In integration](https://pub.dev/packages/google_sign_in_android).

## Runtime failure diagnostics and clock synchronization

See [the runtime investigation](../../docs/auth-runtime-investigation.md) for the verified local clock fault, event-order fixes, safe opt-in diagnostics and real-account retry steps. The local Windows clock was approximately 118 seconds behind Google authentication endpoints and Windows Time was stopped. Synchronize time before retrying a verified login; do not relax backend timestamp or revocation checks to accommodate a bad development clock.

Client traces are enabled only in debug builds with `--dart-define=AUTH_DIAGNOSTICS=true`. Backend traces require both `NODE_ENV=development` and `AUTH_DEBUG_DIAGNOSTICS=true`. They emit allowlisted metadata only. Release/production stays inactive. Normal production error responses remain sanitized.
