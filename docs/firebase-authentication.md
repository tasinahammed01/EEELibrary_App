# Phase 2A: Firebase identity and application users

The backend uses the official Firebase Admin SDK. Flutter has not been changed and has no Firebase packages in this phase.

## Enable real Firebase verification

1. Select/create the intended Firebase project in Firebase Console. Copy its **project ID**, not the display name or project number, into FIREBASE_PROJECT_ID in the ignored backend/.env. Initialize Firebase Authentication. Enable the intended Email/Password and/or Google providers when preparing the client integration.
2. Production: prefer Application Default Credentials (ADC) from the backend's attached managed service identity/workload identity; do not create or ship a private key unnecessarily. The identity needs read permission for Firebase Auth users because this backend checks revocation/disabled Firebase accounts. A restricted custom role with firebaseauth.users.get, or the predefined [Firebase Authentication Viewer](https://docs.cloud.google.com/iam/docs/roles-permissions/firebaseauth) role, supplies the needed read access. No user creation/custom-token/admin permissions are required by this backend.
3. Local development: if managed/impersonated ADC is unavailable, use a dedicated service-account credential JSON stored outside this repository, with restricted local file access. Set GOOGLE_APPLICATION_CREDENTIALS to its absolute path in your shell or ignored backend/.env. The only permitted in-repository location is ignored backend/.credentials/. Never paste JSON/private keys into .env, source, messages, logs or Flutter. No credential has been generated/provided by this implementation.
4. Restart the backend. The credential path must be an accessible absolute JSON file no larger than 64 KiB; unsafe repository placement, unreadable/invalid JSON and invalid project-ID syntax fail environment validation with key names only. Firebase Admin validates actual credential structure/authorization. A readable JSON object alone does not prove valid Firebase credentials.

FIREBASE_PROJECT_ID can remain blank during infrastructure-only development; both auth routes then fail closed with 503 for a syntactically valid bearer header. Missing/malformed headers still return 401. Health remains public and unchanged. Set a real project ID and working ADC before using or deploying authentication. The current local .env is deliberately preserved and has no Firebase project/credentials configured by Codex. During validation, a workstation GOOGLE_APPLICATION_CREDENTIALS setting appeared pointing to a missing file. Correct/clear that setting or point it at the actual safely stored credential file, and configure FIREBASE_PROJECT_ID. Supplied invalid credentials fail startup even if auth is otherwise unconfigured.

FIREBASE_AUTH_EMULATOR_HOST is rejected in all environments: that SDK mode can accept unsigned tokens. Tests mock the verifier and do not enable the emulator. This phase supports one non-tenant Firebase project; tenant-scoped tokens are rejected because tenant UIDs can collide. Changing the configured project for an existing database requires an explicit identity migration, not just an environment edit.

## Trust and routes

Firebase Authentication authenticates the client. The client sends its Firebase client-SDK **ID token** over HTTPS in Authorization: Bearer TOKEN. Backend FirebaseService calls verifyIdToken(token, true) using the explicit project ID. Signature/expiration/project verification is delegated to the official SDK, with required UID/sub/audience/issuer/time claims checked defensively afterward. A valid verified email is required. Custom/admin claims are ignored.

[Firebase ID-token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens) is different from accepting custom tokens. This backend neither creates custom tokens nor accepts local passwords. Revocation checking intentionally includes a [Firebase Auth backend round trip](https://firebase.google.com/docs/reference/admin/node/firebase-admin.auth.baseauth); it also rejects Firebase-disabled accounts. No extra getUser call, token caching or application Redis connection is added.

| Route                       | Requirements                                                            | Response                                                  |
| --------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------- |
| GET /api/v1/health          | Public                                                                  | 200 {status: ok}                                          |
| POST /api/v1/auth/bootstrap | Valid non-tenant Firebase ID token and verified email; no client fields | 200 safe User DTO; creates an application user if missing |
| GET /api/v1/auth/me         | Same identity verification plus existing ACTIVE local user              | 200 safe User DTO; never creates a user on GET            |

Bootstrap should send no body or an empty JSON object. Parsed bodies containing any UID, email, display name, password, role, status or other field are rejected with 400. No body or query value supplies identity. UID/email/name come only from the verified token. New users receive the schema's normal ACTIVE default, without roles/admin privileges. Existing user metadata/status is left unchanged, including when token metadata differs. Email/profile synchronization is deferred to an explicit verified update flow.

Safe DTO fields are exactly id, email, displayName, status and createdAt (ISO timestamp). externalAuthId, token/claim metadata and admin/audit/session details are not returned. Display names use a bounded Unicode-safe claim or EEELibrary Reader fallback.

A unique externalAuthId is the sole identity link. Case-insensitive email uniqueness remains enforced by PostgreSQL. Bootstrap uses an upsert without updating existing identity/status; a P2002 race retries a UID-only lookup for the winner. If no same-UID winner exists, it returns generic 409 rather than relinking by email. Even a verified same-email account cannot take over a different UID. Such collisions require a future explicit audited recovery/linking flow.

## Guards and principal

FirebaseModule exports one singleton FirebaseService with one named eeelibrary-backend Admin app and shared Auth instance. Only same-project app reuse is allowed. Shutdown deletes only an app owned by this provider.

FirebaseAuthGuard rejects missing/empty/malformed/duplicate/oversized bearer headers and attaches a frozen VerifiedIdentity containing only firebaseUid, verified email and bounded displayName. It does not attach a token or the full decoded object. Bootstrap uses @VerifiedFirebaseIdentity().

ActiveUserGuard resolves the local record once by verified UID, rejects missing/inactive records, and attaches the selected SafeUser. /me accesses it through typed @CurrentUser() without requerying. Future protected application endpoints must use **both** FirebaseAuthGuard and ActiveUserGuard; Firebase verification alone does not authorize application or paid access. Bootstrap uses FirebaseAuthGuard and enforces account status after its database operation so first-time identities can create a user.

Both DISABLED and SUSPENDED users are denied with 403, including concurrent bootstrap winners. No client-controlled values can reactivate them. Entitlement/admin authorization remains a separate future server responsibility.

## Error contract

Existing sanitized filtering remains unchanged:

- 400: invalid parsed bootstrap body.
- 401: missing/malformed bearer, invalid/expired/revoked/wrong-project token or unsupported tenant identity.
- 403: missing/unverified/invalid Firebase email, or inactive local account.
- 404: authenticated /me before local bootstrap.
- 409: identity cannot be created due to another UID's email ownership; no account details returned.
- 503: unconfigured Firebase or SDK credential/permission/network failure.
- 500: unexpected database/application failure.

Responses contain generic statusCode/message only. Neither Firebase error strings nor bearer values are logged/serialized. Unexpected infrastructure errors use the existing fixed generic logger. Production transport still needs HTTPS via its reverse proxy and the existing deployment safeguards.

## Test and verification workflow

From backend:

```powershell
npm.cmd run format
npm.cmd run lint
npm.cmd test
npm.cmd run test:integration
npm.cmd run build
npx.cmd tsc --noEmit -p tsconfig.json
```

SDK unit tests mock firebase-admin/app/auth to verify lifecycle, ADC use, checkRevoked=true, required claims, project/tenant checks, email policy and sanitized failures. HTTP tests override FirebaseService (not the guard/controller), keeping the real guards, pipes, decorators, exception filter and application service in the request path. Unit setup prevents real Firebase calls and removes workstation credential/emulator configuration.

Database integration tests require the existing guarded local development .env and no Firebase credentials. The original 17 rollback-based schema tests are preserved. Six additional auth integration tests exercise real pooled-connection races, idempotency, collision safety and inactive accounts. They create random UUID-tagged test users and clean up **only those exact UIDs**, never reset/truncate/drop the database or delete volumes.

Compiled runtime checks confirm health 200, missing bearer 401 and unconfigured auth 503. Protected success/error paths are exercised with test-only verifier injection; this is not an application bypass or production test-auth mode. Real credential/project end-to-end validation must be completed after the owner configures Firebase and obtains a genuine client-SDK ID token. Never paste that token into logs/chat/source. Flutter authentication and email verification UX are the next phase.
