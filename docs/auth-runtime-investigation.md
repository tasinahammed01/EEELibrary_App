# Authentication runtime investigation - 16 October 2026

## 1. Root cause and evidence

The local Windows clock was **approximately 118 seconds behind** three Google HTTPS response clocks: the Firebase certificate endpoint, `securetoken.googleapis.com`, and `identitytoolkit.googleapis.com`. Fresh uncached responses from the two authentication hosts agreed; neither reported a cached Age. `w32tm /query /status` reported that Windows Time was not started.

The existing FirebaseService first performs `verifyIdToken(token, true)`, then explicitly rejects `decoded.iat > now` or `decoded.auth_time > now`. Therefore a newly issued token whose Google timestamps are 118 seconds ahead of this host is rejected with 401 even after the SDK boundary succeeds. A forced refresh creates another fresh timestamp and does not correct the host clock. The client's second-401 cleanup then signs Firebase out. This mechanism explains both the post-verification and correct-password sign-in symptoms.

A deterministic backend regression models that measured offset, confirms 401 while the host lags, and confirms acceptance after aligning the test clock. Revocation checking remains enabled in both assertions. No timestamp tolerance, signature bypass, revocation bypass or email-policy relaxation was added.

**Evidence limit:** a real verified-account bearer request was not captured during this investigation. The user chose diagnostics/tests and will perform the account retry afterward. The measured clock fault and rejection mechanism are established; the exact rejection of the previously observed real request remains to be correlated with the new safe reason code. Do not describe a fixture response as a captured real-account response.

## 2. Frontend defects also reproduced and fixed

Seven new deterministic tests failed against the original controller before the fix:

- An old null stream snapshot could clear an authenticated application session despite a live Firebase currentUser.
- A delayed same-user signed-in notification could start an extra /me restoration after interactive login or verification had already bootstrapped.
- Delayed same-user events following 403/409/503 could automatically retry and replace the intended error state.
- A delayed null notification after persistent 401 could clear the error message, making a valid Firebase login appear to do nothing.

The controller now reconciles stream snapshots against the current Firebase UID, coalesces same-session events, retains failure feedback across duplicate signed-out notifications and revalidates UID around verification reload/refresh. An idle account change closes old application access while the new backend identity is checked. Genuine auth loss, UID changes during requests and stream failures remain fail-closed. No separate session manager or generic state framework was introduced.

## 3. Actual runtime statuses and configuration

Local health returned 200. Both GET /api/v1/auth/me and empty POST /api/v1/auth/bootstrap without a bearer returned 401, as expected. Opt-in running-backend logs were checked and emitted only route/status pairs for these probes. The backend was initially not listening in this session; a task-owned process was started with the backend/.env configuration, project eee-library and safe diagnostics. Android emulator-5554 then reached http://10.0.2.2:3000/api/v1/health directly and received HTTP 200 with {"status":"ok"}. This proves loopback reachability, not successful real-account authentication. No authenticated bootstrap 200/401/403/409/503 was captured from the verified account; the owner elected to perform that retry afterward. The public Android Firebase configuration was checked: eee-library and the expected com.eeelibrary.eeelibrary package.

Default Android debug target remains `http://10.0.2.2:3000`, centralized in ApiConfig. Debug XML narrowly permits the three existing local development hosts; main/release remains HTTPS-only. No Android, dependency or Gradle version change was needed.

Both the ambient shell ADC and backend/.env ADC independently passed Admin listUsers and verified-user getUser permission probes. The latter exercises the user lookup permission needed by revocation/disabled-user checks. Neither probe exposed tokens, account identifiers or credential contents. Both were configured for `eee-library`; the ADC paths differed, but both worked. No evidence of missing Firebase user-read IAM permission was found. For the local running backend, backend/.env was explicitly applied to its child-process environment so ADC selection is unambiguous. Credential files remain outside the repository.

## 4. PostgreSQL verification

Read-only inspection found **one enabled, verified Firebase user and zero PostgreSQL User rows**, including zero links for that verified Firebase UID. Thus the reported user had not completed application bootstrap. No user was recreated, relinked or deleted. Existing database integration tests create UUID-tagged fixtures and remove only their own fixtures; no reset/drop/truncate occurred.

## 5. Files changed

Created:

- `backend/src/common/auth-diagnostics.ts`
- `backend/test/auth-diagnostics.spec.ts`
- `docs/auth-runtime-investigation.md`
- `mobile/lib/core/diagnostics/auth_diagnostics.dart`
- `mobile/test/auth_diagnostics_test.dart`
- `mobile/test/auth_event_order_test.dart`

Modified:

- `backend/src/config/configure-app.ts`
- `backend/src/firebase/firebase.service.ts`
- `backend/test/firebase.spec.ts`
- `backend/test/setup.ts`
- `mobile/docs/auth-integration.md`
- `mobile/lib/features/auth/data/backend_auth_client.dart`
- `mobile/lib/features/auth/presentation/auth_controller.dart`
- `mobile/test/auth_integration_test.dart`
- `mobile/lib/core/routing/app_router.dart`

Firebase gateway, transport, domain DTO, base URL, forms, illustrations, Home, Android configuration, dependencies and database schema remain unchanged. Backend changes add diagnostics only; the verification conditions, statuses and revocation call are unchanged. Backend unit setup now blocks real .env Firebase settings from leaking into mocked suites, using empty test-only environment values. This fixes test isolation rather than changing runtime configuration.

## 6. State-machine and routing behavior

- Interactive login owns its operation; signed-in stream events during it cannot start restoration. Null -> the newly signed-in UID is accepted normally.
- Registration creates the Firebase account and presents verification, without premature bootstrap.
- Verification reloads the same user, forces token refresh, and bootstraps exactly once. A UID switch during reload/refresh cannot establish a different account.
- Backend 200 + ACTIVE grants Home only after the backend result.
- One backend 401 forces one refresh/retry. A second 401 still closes local access and attempts Firebase/provider sign-out.
- Signed-out failures from Splash/verification/status now lead to Login with the retained safe message, rather than Welcome silently discarding it. Explicit logout still returns Welcome through existing routing/UI behavior.
- Backend 403/409/503 retain the safe account-access screen. Same-session notifications do not silently retry them.
- Restore still falls back from /me 404 to bootstrap once. A new Firebase UID must establish its own backend application identity.
- Genuine Firebase loss and stream errors still close application access. Stale stream snapshots cannot undo a successful current session.

## 7. Why previous mocked tests missed it

Backend fixtures issued claims relative to the same mocked Date.now clock (`iat = now - 30`, `auth_time = now - 60`). They never modeled Google being 118 seconds ahead. Flutter's fake transport returned safe DTOs without running real Firebase token verification. Existing auth fakes delivered ordinary stream events while the interactive operation was still busy; they did not explicitly release stale null/same-user notifications after completion. The previous report explicitly left real-account verification to manual QA.

## 8. New regressions

Added 12 deterministic event-order cases covering interactive event interleaving, legitimate null-to-user transitions, no duplicate restoration, verification interleaving, stale null after success, persistent 401 feedback, 403/409/503 late events, genuine auth loss, logout late events, verification UID switches and idle UID-switch gating. Existing tests continue to cover in-flight UID switches and real stream errors.

Two widget regressions verify verification failure reaches Login with live-region feedback, and a failed login message survives a delayed null event before a successful retry clears it and reaches Home.

An opt-in diagnostics test exercises a full two-401 client flow and asserts that only allowlisted metadata is emitted, never token/password/email/UID/header/body fixtures. Three backend diagnostics cases verify disabled-by-default and production/test gating plus field reconstruction. Two Firebase backend cases cover the measured clock rejection, recovery with aligned time, distinct auth-time rejection and insufficient-permission classification. No existing assertion was weakened.

## 9-11. Validation

- `dart format .`: completed.
- `flutter analyze`: No issues found.
- `flutter test --dart-define=AUTH_DIAGNOSTICS=true`: **211 passed**, including all previous 196 tests, with diagnostics exercised across the full suite. The ordinary diagnostics-disabled suite also passed 211.
- Dedicated diagnostics-enabled secret-redaction regression: passed.
- `flutter build apk --debug --dart-define=AUTH_DIAGNOSTICS=true`: passed with the documented local Kotlin cache workaround after the normal attempt reproduced that cache failure. APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Backend unit/HTTP: **122 passed**; real PostgreSQL integration: **23 passed**; total **145**.
- Backend TypeScript build, ESLint and Prettier format check: passed.
- Android emulator loopback health: HTTP 200. Merged debug manifest confirms INTERNET, the scoped XML and cleartext false at application base.
- Real verified-account sign-in/verification/restore: not performed, per the owner's choice to verify afterward.

## 12. Security review

No real ID/OAuth/refresh token, Authorization header, password, raw exception, decoded token or service-account contents were logged. No secret file was copied into mobile or the repository. No custom tokens, test authentication bypass, role/paid entitlement trust, database reset or certificate relaxation was introduced. `verifyIdToken(token, true)`, strict timestamp/email/project/tenant/account checks and one-refresh retry ceiling remain intact. Production diagnostics stay inactive regardless of opt-in flags. Backend response bodies remain sanitized.

## 13. Required local remediation and real-account verification

**Synchronize Windows time before testing sign-in again.** Use Windows Settings -> Time & language -> Date & time -> automatic time / Sync now. Windows Time was stopped on this machine; an administrator may need to enable/start it. If using an elevated PowerShell, the Windows maintenance commands are `Start-Service w32time` and `w32tm /resync`. They are provided for the operator; this task did not change global Windows services or the system clock. Timezone display alone does not correct UTC clock drift. Keep backend hosts time-synchronized in deployment.

Then use an account/inbox you control:

1. Login with the already verified account; do not recreate it. Confirm bootstrap 200 -> Home, Firebase remains signed in, and exactly one matching PostgreSQL User exists.
2. Logout -> Welcome -> email/password login -> Home.
3. Restart the app -> /me 200 -> restored Home, without duplicate bootstrap.
4. For a disposable account, register -> receive/complete email verification -> check -> one bootstrap 200 -> Home.
5. Confirm explicit logout -> Welcome, and backend denial/unavailability remains visible and fail-closed.

The task-started backend is already running on port 3000 with safe diagnostics enabled. Reuse it for the retry; its PID is recorded locally in ignored mobile/build/qa/auth-bug-backend.pid. Stop that process normally before starting a replacement to avoid a port conflict. The task-created headless emulator was shut down after connectivity validation.

Enable only safe traces while reproducing:

```powershell
# backend, with its normal ADC/environment loaded; use development only
$env:NODE_ENV = 'development'
$env:AUTH_DEBUG_DIAGNOSTICS = 'true'
npm.cmd run start:dev

# mobile
flutter run -d emulator-5554 --no-enable-impeller --dart-define=AUTH_DIAGNOSTICS=true
```

Backend traces contain only fixed verification-rejection reason enums or allowlisted route/status pairs. Client `[EEELibraryAuth]` traces contain operation sequence numbers, action/state/failure enums, route/status/attempt and token-acquisition booleans. No client UID is used. Collect these allowlisted traces rather than sharing full Firebase/Android logs. `issued-in-future` identifies the clock mechanism; `admin-permission-denied` distinguishes IAM; SDK rejection, email policy and backend response statuses have separate safe categories. Remove the flags after diagnosis.

The generated debug APK already includes AUTH_DIAGNOSTICS=true. To reuse it without rebuilding, start the emulator normally and run from mobile:

```powershell
flutter run -d emulator-5554 --no-enable-impeller --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

The normal build hit the documented Windows Kotlin incremental-cache failure. It passed after stopping the daemon, clearing only verified mobile/build plugin Kotlin caches and using the same per-process workaround:

```powershell
$env:GRADLE_OPTS = '-Dorg.gradle.project.kotlin.incremental=false -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process -Dorg.gradle.jvmargs=-Xmx2G'
flutter build apk --debug --dart-define=AUTH_DIAGNOSTICS=true
```

No permanent compiler/renderer setting or package version was changed.

Manual real registration/verification/login/restoration success is **not claimed** for this turn. This is the remaining confirmation after fixing local time. If the live trace shows another reason, investigate that reason without weakening authorization checks.
