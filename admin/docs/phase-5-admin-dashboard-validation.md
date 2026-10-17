# Phase 5 admin dashboard validation

## Pre-implementation audit

Inspected root, backend/mobile, npm lockfile, Node 22.13.1, Prisma schema and both migrations, immutable AuditLog trigger, persisted AdminUser roles/status, Firebase revoked-token and verified-email policy, PaymentReviewerGuard and transactional PurchaseService, configureApp CORS/global prefix/strict validation/SafeExceptionFilter, unit and PostgreSQL integration harnesses, environment examples, ignores and Flutter design tokens. No admin app or provisioning command existed. Existing payment endpoints remain unchanged. Existing schema supports all requested metadata; no migration planned. Flutter navy #142B50, blue #244BC5, gold #F2BD57 inspire independent web CSS.

## Architecture and versions

Separate /admin Next.js 16.4.2 App Router application with TypeScript, React/React DOM 19.3.1, Firebase Web 12.19.0. Node tested: 22.13.1. Exact dependency graph is locked in admin/package-lock.json. Native React state, CSS tokens, semantic HTML and native dialog; no UI/icon/state framework. Vitest + jsdom + Testing Library provide focused tests. Firebase Web 13 requires Node >=24.12; the compatible stable 12.19 release is intentional. Overrides pin @firebase/app 0.16.2 and @firebase/app-compat 0.5.18 because newer transitive releases require a newer Node. Backend/Flutter dependencies were not upgraded.

Protected pages are client-rendered behind SessionProvider and /admin/me. The root is force-dynamic; protected API requests and admin HTTP responses (including denied/error responses) use no-store. No protected records are statically generated. Firebase app/auth are the only client SDK imports; no Firebase Admin SDK in /admin.

## Authentication and provisioning

Email/password only, no signup. Firebase SDK manages browser-session persistence. Application code never writes tokens to localStorage/sessionStorage, cookies, logs, URLs or application caches. ID tokens are obtained immediately before API calls; one forced refresh is attempted after backend 401. Persistent 401 clears the protected UI session; 403 is safe Access Denied. Requests capture identity object and recheck before send and after response; unmounted reads abort, stale mutations cannot update UI. Both token acquisition and fetch have a 15-second deadline. Safe errors map 400/401/403/404/409/503 without displaying raw backend/Firebase text.

The existing backend verifier checks token revocation, disabled Firebase accounts, project/audience/issuer and verified email. New AdminGuard independently looks up ACTIVE persisted AdminUser by verified Firebase UID. Browser claims/roles/headers are not authority. AdminUser does not require a matching ordinary User row. /admin/me returns only id, displayName, email, role and status from an explicit select.

NEXT_PUBLIC Firebase web config identifies the Firebase project/client; it is not administrator authority. Only the persisted backend AdminUser grants permission. admin/.env.example contains blank public placeholders and a local API origin. No credentials or actual environment files were copied.

Trusted operator steps (run in backend with existing private environment and ADC):

1. Create/identify an existing enabled Firebase email/password identity, verify its email through the established Firebase flow, and check the intended project and UID. Do not send passwords or tokens to this tool.
2. Run npm run admin:operator -- provision --uid EXISTING_FIREBASE_UID SUPER_ADMIN (or CONTENT_MANAGER / PAYMENT_REVIEWER).
3. The CLI validates exact arguments and enum, verifies the Firebase identity through Admin SDK, then deliberately creates/updates only the named AdminUser role/status. It never creates a Firebase account or modifies User. No default admin is seeded, and no provisioning HTTP route exists.
4. To revoke persisted admin authority: npm run admin:operator -- disable --uid EXISTING_FIREBASE_UID CONFIRM. Database row locking serializes role/status updates against in-flight protected mutations. Already committed operations are not undone.
5. Record these privileged operator actions in the trusted operations/change log. Bootstrap has no pre-existing AuditLog actor; CLI actions do not impersonate another admin actor.

## Role policy

| Role             | Dashboard                        | Payments             | Books/categories | Users/status         | Orders | Entitlements | Audit  |
| ---------------- | -------------------------------- | -------------------- | ---------------- | -------------------- | ------ | ------------ | ------ |
| SUPER_ADMIN      | All five metrics                 | Existing review APIs | Read/create/edit | Read/status mutation | Read   | Read         | Read   |
| CONTENT_MANAGER  | Published books                  | Denied               | Read/create/edit | Denied               | Denied | Denied       | Denied |
| PAYMENT_REVIEWER | Pending reviews/completed orders | Existing review APIs | Denied           | Denied               | Read   | Denied       | Denied |

Every route enforces this on the backend. UI navigation hiding is convenience only. Existing PaymentReviewerGuard and PurchaseService authority/transaction/review behavior remain intact.

## Exact backend contracts

All paths below have /api/v1 prefix and require verified Firebase bearer identity plus ACTIVE persisted admin authorization.

- GET /admin/me: safe persisted identity; all three roles.
- GET /admin/dashboard: role-filtered metric object.
- GET /admin/books: bounded page, optional title search/publication status; content roles.
- GET /admin/books/:id: safe metadata by UUID; content roles.
- POST /admin/books: title, description, categoryId, price decimal string, optional BDT currency, status, pageCount; content roles.
- PATCH /admin/books/:id: partial allowlist of those fields; content roles.
- GET /admin/categories: bounded page, optional name search; content roles.
- POST /admin/categories: name, optional description/isActive/sortOrder; content roles.
- PATCH /admin/categories/:id: partial category allowlist; content roles.
- GET /admin/users: bounded page, optional display-name search/status; SUPER_ADMIN.
- GET /admin/users/:id: safe id/displayName/email/status/createdAt; SUPER_ADMIN.
- PATCH /admin/users/:id/status: only ACTIVE/DISABLED/SUSPENDED; SUPER_ADMIN.
- GET /admin/orders and GET /admin/orders/:id: safe order snapshot, book/user display context, latest payment state; SUPER_ADMIN/PAYMENT_REVIEWER.
- GET /admin/entitlements and GET /admin/entitlements/:id: safe user/book/source-order/status/grant/revocation information; SUPER_ADMIN, read only.
- GET /admin/audit: bounded immutable events with safe actor/name, action, target and timestamp; SUPER_ADMIN, read only. Metadata is deliberately excluded.
- Existing GET /admin/payments, GET /admin/payments/:id, POST /admin/payments/:id/approve and POST /admin/payments/:id/reject remain unchanged, protected by PaymentReviewerGuard. Reject body reason is REFERENCE_NOT_FOUND, AMOUNT_MISMATCH or METHOD_MISMATCH; approve body is empty object. Reference is visible only on protected payment review.

New list responses: items/total/page/pageSize/hasMore; defaults page=1, pageSize=12; page <=10000 and pageSize <=40; stable createdAt/id ordering. Search <=100 characters. Status is checked for the relevant resource. Unsupported fields, nested unsafe query input, malformed UUIDs, null patch values and mass assignment are rejected. Unknown permitted detail UUID returns 404; unauthorized roles get 403 before detail lookup.

## Catalog and account mutations

Server generates ASCII slugs from names/titles on creation. Slugs remain stable on edit, and collisions safely return 409. Names with no valid ASCII slug require a suitable title/name; an empty slug fails closed. No hard-delete endpoints. No browser-controlled storage keys, preview counts, user/admin identities, audit fields, entitlements or arbitrary columns. BDT only, price string has at most ten integer digits and two decimals, and remains nonnegative. Page metadata preserves existing preview invariants. Category active status and book publication status preserve existing public catalog/purchase eligibility rules; no reader/upload workflow is added.

Metadata mutations and audit events commit together. Mutations revalidate ACTIVE persisted actor/role inside transaction with AdminUser FOR SHARE lock. User status updates lock the target User before admin, matching purchase lock ordering, then append USER_STATUS_CHANGED with only previous/new status. Same-status retry is idempotent without duplicate audit. Catalog audit events contain target/type/action, no arbitrary metadata. Audit insertion failure rolls back the user change. Existing immutable database audit trigger is unchanged.

User status never edits Firebase UID, passwords, orders or entitlements. Existing ActiveUserGuard rejects disabled/suspended users on subsequent requests; existing purchase locks also enforce status during concurrent actions. No ad-hoc entitlement grant/revoke controls. Order status remains PurchaseService-controlled.

## Dashboard and UI

Metrics are bounded database counts, not invented analytics: published books with active category, ACTIVE users, PENDING payment reviews, COMPLETED orders, and ACTIVE nonrevoked entitlements whose owner/order/catalog still qualify for Library access. Five aggregate counts run in a repeatable-read transaction and only allowed metric keys are returned. No revenue estimate.

Responsive navy/blue/gold workspace includes desktop sidebar, keyboard-operable mobile navigation, identity/role header, sign out, skeletons, empty states, retries, paginated scrollable tables and debounced catalog/user search. Payment details expose amount/currency/method/reference/order/book/date/state. Approval/rejection require native confirmation dialog, disable duplicate submits, send only backend-supported reason codes, and refresh authoritative state. User status and publication changes require explicit confirmation. Forms use bounded category pages, field constraints, unsaved-page unload warning and safe error/success live regions. Audit and entitlement views are read only. Static EEELibrary branding only.

## CORS, caching and data boundaries

Existing exact-origin CORS allowlist is preserved. backend/.env.example documents http://localhost:3001 and http://127.0.0.1:3001; the real ignored .env is untouched. Operator must configure those explicit origins/restart locally. Production validation already requires HTTPS origins. Wildcards and credentials are not enabled; native Flutter requests without Origin retain existing behavior.

Admin no-store middleware runs before guards and parsers so unauthorized/invalid/error responses also avoid caches. Next.js sends no-store, nosniff, no-referrer, frame denial and restrictive device-permission headers. Central API uses no-store, omitted cookies, rejects redirects, validates base URL (HTTPS except loopback), guards JSON/pagination, and does not log requests. Browser-bundle marker audit checks for service-account/private-key/database/ADC markers. React escapes rendered metadata; no raw HTML or arbitrary remote asset workflow.

## Schema and performance

No Prisma schema change, migration, database reset, trigger bypass, destructive infrastructure operation or new index. Existing UUID relations, BDT/decimal/page/review constraints, entitlement uniqueness and immutable audit trigger suffice. Existing Phase 4 price snapshots, idempotent/concurrent review and free acquisitions remain tested. Lists use bounded pagination, relation selects and aggregate counts, without per-row N+1 queries; no unbounded data loads or polling. Existing query indexes were retained rather than adding speculative indexes.

## Exact file inventory

### Created (38)

- `admin/.env.example`
- `admin/.gitignore`
- `admin/README.md`
- `admin/docs/phase-5-admin-dashboard-validation.md`
- `admin/eslint.config.mjs`
- `admin/next-env.d.ts`
- `admin/next.config.ts`
- `admin/package-lock.json`
- `admin/package.json`
- `admin/scripts/check-bundle.mjs`
- `admin/src/app/[[...path]]/page.tsx`
- `admin/src/app/globals.css`
- `admin/src/app/layout.tsx`
- `admin/src/components/feedback.tsx`
- `admin/src/components/shell.tsx`
- `admin/src/features/auth/firebase.ts`
- `admin/src/features/auth/login.tsx`
- `admin/src/features/auth/session.tsx`
- `admin/src/features/dashboard/overview.tsx`
- `admin/src/features/records/metadata-form.tsx`
- `admin/src/features/records/records.tsx`
- `admin/src/lib/api.ts`
- `admin/src/lib/use-record.ts`
- `admin/test/api.test.ts`
- `admin/test/session.test.tsx`
- `admin/test/setup.ts`
- `admin/test/ui.test.tsx`
- `admin/tsconfig.json`
- `admin/vitest.config.ts`
- `backend/src/admin/admin.controller.ts`
- `backend/src/admin/admin.dto.ts`
- `backend/src/admin/admin.guard.ts`
- `backend/src/admin/admin.module.ts`
- `backend/src/admin/admin.service.ts`
- `backend/src/admin/partial-type.ts`
- `backend/src/admin/provision.ts`
- `backend/test/admin.integration.spec.ts`
- `backend/test/admin.spec.ts`

### Modified (5)

- `README.md`
- `backend/.env.example`
- `backend/package.json`
- `backend/src/app.module.ts`
- `backend/src/config/configure-app.ts`

### Deleted (0)

None.

## Exact installed web tooling

| Package                     | Version |
| --------------------------- | ------- |
| next                        | 16.4.2  |
| react                       | 19.3.1  |
| react-dom                   | 19.3.1  |
| firebase                    | 12.19.0 |
| typescript                  | 5.9.3   |
| eslint                      | 9.39.5  |
| eslint-config-next          | 16.4.2  |
| vitest                      | 4.1.12  |
| jsdom                       | 27.4.0  |
| @testing-library/react      | 16.3.3  |
| @testing-library/user-event | 14.6.8  |
| @testing-library/jest-dom   | 6.9.1   |

The complete transitive graph is pinned in package-lock.json. Sources consulted: [Next.js installation](https://nextjs.org/docs/app/getting-started/installation) and [Firebase auth persistence](https://firebase.google.com/docs/auth/web/auth-state-persistence).

## Validation results

- Backend npm test: **295 passing tests in 9 suites** (195 existing +100 new HTTP/DTO/operator/security tests).
- Backend npm run test:integration: **86 passing tests in 5 suites** (63 existing +23 new PostgreSQL tests).
- Total backend: **381 passing tests**. Existing payment approval/concurrency/idempotency/free-acquisition regressions remain passing.
- Backend build, lint and format:check: passed.
- Prisma validate: valid. Prisma migrate status: 2 existing migrations; database schema up to date. No migration applied or generated.
- Admin npm test: **64 passing tests in 3 files**. Admin lint/typecheck/build: passed. Next.js reports dynamic routes, with no protected static page data.
- Flutter analyze: **No issues found**. Flutter test: **359 passing tests**. No mobile source change; Android rebuild was not required.
- Admin audit:bundle: passed across 11 browser build files; no server credential markers. Also reviewed next.config.ts, public config placeholders and frontend imports: no server-secret env export, Firebase Admin SDK or backend imports.
- Real Edge: **44 isolated-fixture page compositions** across 320/360/390/1440 widths, followed by **4 actual production-login compositions**. No document-level horizontal overflow or browser runtime exception. Visually reviewed desktop dashboard/payment detail and mobile login/payments/forms. Tables intentionally scroll within their regions.
- Actual production HTTP smoke: **15 checks passed** against Next production server and an isolated backend process with process-local explicit CORS origins. Checked readiness, guest 401/no-store for all admin areas, allowed/denied origin, PATCH bearer preflight, production page 200/no-store/frame-denial, and public catalog 200. No authenticated real-user mutation.
- Read-only fixture audit: **0 Phase 5 admins, users, categories or books remain**. Most integration fixtures use outer rollback transactions; the audit-failure test removes only its two exact fixture UUID records after verifying rollback. No audit event was deleted or trigger disabled.
- git diff --check: passed (Git prints only line-ending normalization notices).

The first Prisma invocation from the repository root could not resolve the backend environment; validation was rerun successfully from backend. The PostgreSQL joined-transaction test harness emits a non-failing pg query-overlap deprecation warning; production uses normal Prisma transactions. Earlier iterative failure logs are ignored; the totals above refer to final passing runs.

## Test coverage and final review

New backend tests cover all three role matrices, guest/ordinary/disabled admin denial, forged browser role inputs, safe /admin/me, CORS, no-store on denials, strict query/page/UUID/DTO validation, decimal/currency/page bounds, null patch/mass-assignment rejection, trusted CLI arguments, safe selects, real metrics, category/book mutations and audit events, unpublished/inactive-category public visibility, user status audit/idempotency, transaction role revalidation, missing details, and audit failure rollback. A real PostgreSQL HTTP fixture proves disabling a User immediately affects the existing auth guard.

Web tests cover guest login, backend bootstrap, normal-user denial, missing configuration, sign out, 401 retry/403/409/503, invalid JSON and payload guards, token deadline, stale account/signout/filter requests, navigation, loading/empty/error/retry, filter/detail flows, approve/reject confirmation and reason allowlist, publication/user status confirmation, book/category create/edit, default category preservation after async options, switching editors without stale values, duplicate-submit guards, read-only order/entitlement/audit controls and basic narrow/desktop structure. Actual browser checks supplement jsdom; jsdom alone does not prove pixel layout.

Two additional form regressions caught and fixed real UI state issues: selecting another category editor now remounts the form by record id, and an existing book's category is controlled so asynchronous option replacement cannot silently clear it. No existing tests were weakened.

## Manual checks and remaining verification

Performed real PostgreSQL integration/rollback checks and production local HTTP checks; protected browser workflow rendering uses ignored, isolated fixtures, never a production auth bypass. Actual production login was rendered with safe missing-public-config feedback. Task-owned smoke servers and headless browser were stopped; existing backend/infrastructure were preserved.

The owner/operator still needs to supply the Firebase **web app** public configuration, configure the exact real admin browser origin in backend CORS, explicitly provision the intended verified Firebase UID, and complete a real-account browser sign-in/sign-out and role check. No real Firebase password/token was requested; no real identity was promoted and no arbitrary real payment was approved/rejected. Check receiving records before any genuine approval. Verify keyboard/screen-reader behavior in target browsers and tablet/device zoom as part of release QA. Automated tests reduce regression risk; they are not a bug-free guarantee.

## Deferred scope

No PDF upload/processing/delivery/reader session/watermark/device-limit/offline feature, payment gateway, refund/dispute, subscription, AI, storefront, branding/logo upload, advanced analytics, public admin signup, admin-provisioning HTTP endpoint, arbitrary order-status editing or ad-hoc entitlement grant/revoke. Entitlement revocation remains future audited domain work. Admin Google sign-in is optional and not included; email/password uses the existing backend verified-email policy.
