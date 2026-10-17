# EEELibrary Admin

Separate Next.js App Router application. Backend authorization is mandatory for every protected operation. There is no public registration.

## Local setup

1. Use repository-compatible Node 22.13+ (22.x) or 24.x and run `npm ci` in this directory.
2. Copy `.env.example` to ignored `.env.local`. Supply the Firebase **web app** public configuration from the existing Firebase project. Do not use a service account or Android app ID. Enable the project's email/password provider and authorized web domains as required.
3. Backend: configure `CORS_ORIGINS=http://localhost:3001,http://127.0.0.1:3001` in its ignored operator environment; restart backend. Production requires exact HTTPS origins. Keep existing database and ADC configuration private in the backend environment.
4. Provision a pre-existing, enabled, verified-email Firebase identity through the backend operator command below. No identity or default administrator is created by this app.
5. Run backend normally on 127.0.0.1:3000, then `npm run dev` here (port 3001). Browser SDK session persistence is managed by Firebase; tokens are never manually stored.

## Trusted operator commands (backend directory only)

`npm run admin:operator -- provision --uid EXISTING_FIREBASE_UID SUPER_ADMIN`

Other explicit roles: CONTENT_MANAGER, PAYMENT_REVIEWER. Re-running deliberately updates the named AdminUser role/status; it does not modify/promote the ordinary User row. The operator must check target identity/project/environment before running. No real admin is seeded automatically.

`npm run admin:operator -- disable --uid EXISTING_FIREBASE_UID CONFIRM`

Requires the existing backend environment and Application Default Credentials / GOOGLE_APPLICATION_CREDENTIALS outside the repository. Provision verifies an enabled Firebase identity with verified email. Disable revokes persisted admin authority. Operator actions run outside HTTP; record these privileged operator actions in your trusted operations/change log (the first admin has no existing audit actor). Do not distribute operator access to web users.

## Validation

`npm test`, `npm run lint`, `npm run typecheck`, `npm run build`, `npm run audit:bundle`.

See [Phase 5 validation](docs/phase-5-admin-dashboard-validation.md) for API contracts, roles, test evidence and limitations.
