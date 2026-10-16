# Phase 4 purchase and entitlement validation

## Audit recorded before implementation

Inspected schema and both migrations, including PostgreSQL CHECKs and partial indexes; auth guards/decorators/module, safe exception filter, validation conventions, Prisma service/transaction patterns and integration fixtures; Flutter details, Library placeholder, router, auth scope/controller/gateway, transport, catalog layers and tokens.

Order has immutable-intent decimal amount/currency snapshot and PENDING_PAYMENT/PAYMENT_SUBMITTED/COMPLETED/CANCELLED states. Payment supports multiple attempts, case-insensitive globally unique alphanumeric reference, PENDING/APPROVED/REJECTED states, mandatory persisted admin review metadata, and one-approved-payment-per-order partial unique index. Entitlement is unique by user/book and by order, with composite FK tying owner/book to the order. AdminUser is separate from User, with trusted persisted roles/status. AuditLog requires a persisted admin actor and is immutable by trigger. Book/order/payment CHECKs restrict currency to BDT; Payment must have positive amount, so free acquisition must not create a Payment.

No migration is planned: existing constraints support this lifecycle. Pending-order duplication will be prevented by serializing all purchase mutations on the existing owner User row, across application instances. Admin role/status and owner ACTIVE status will be revalidated inside mutation transactions. Explicit selects will omit private storage, admin identity and payment reference from user DTOs.

## Implemented architecture and migration decision

PurchaseModule adds PurchaseService, EntitlementService, ManualPaymentOptions, trusted PaymentReviewerGuard and no-store response policy. It reuses AuthModule, FirebaseModule, PrismaModule, global `/api/v1` routing, validation, body-size limits and SafeExceptionFilter. No package/framework/version upgrade was needed.

No Prisma migration or schema edit was required. The existing unique user/book entitlement, unique order entitlement, globally case-insensitive payment reference, composite owner/book foreign keys and one-approved-payment partial index remain intact. Both existing migrations remain applied. No reset, forced push, table deletion, volume deletion or audit-trigger weakening was performed.

## Lifecycle and invariants

Paid: PENDING_PAYMENT order → PENDING payment + PAYMENT_SUBMITTED order → authorized approval → APPROVED payment + COMPLETED order + ACTIVE entitlement. Submission alone never grants access. Amount/currency are read from Book when creating the order, then copied from the immutable order snapshot into each payment attempt. The client sends no price, currency, status, user ID, admin identity or ownership state.

Rejected: payment becomes REJECTED; the same order returns to PENDING_PAYMENT. The prior attempt/reference remains recorded. A new, globally unused reference is required for resubmission. Previously rejected references cannot be recycled; corrections, disputes and refunds need trusted support/future workflow, not automatic transfers. Only three public reason codes are accepted: REFERENCE_NOT_FOUND, AMOUNT_MISMATCH, METHOD_MISMATCH. Arbitrary legacy notes are filtered out of user DTOs and never rendered as rejection text.

Already owned: creation returns the existing completed acquisition order without another payable order. Revoked or inconsistent entitlements cannot be reacquired/reactivated through this flow. Completed order/payment state alone never substitutes for a valid entitlement.

Free: authenticated POST /orders reads the real zero price, atomically creates a COMPLETED zero-price order and ACTIVE entitlement, and creates no Payment. Repeats/concurrent calls return the same order/entitlement. No fabricated admin actor is used for a free acquisition: its completed order is the acquisition record.

Price transitions: ordinary unpaid/submitted quotes keep their original amount even if catalog prices change. If a book becomes free before an unpaid quote is submitted, the old order is cancelled without changing its amount, and a new zero-price acquisition completes atomically. A previously submitted payment remains in review when catalog pricing becomes free; it is not silently discarded or auto-approved. Refund/price-adjustment policies are deferred.

## Exact API contract

All routes below are prefixed with `/api/v1`. Mutations return 200 for both first success and idempotent success.

| Endpoint | Authorization | Intent / response |
| --- | --- | --- |
| POST /orders | Verified Firebase + ACTIVE local User | Body `{bookSlug}` only; returns safe order, including zero-price completion |
| GET /orders | Same | Paginated own orders |
| GET /orders/:id | Same | Own order; unknown/foreign IDs return indistinguishable 404 |
| GET /orders/payment-options | Same | Configured receiving options array |
| POST /orders/:id/payment | Same | Body `{method, reference}` only; returns safe order with pending review |
| GET /books/:slug/access | Same | `{owned: boolean, order: SafeOrder or null}` |
| GET /library | Same | Paginated catalog summaries backed only by valid entitlements |
| GET /admin/payments | Verified Firebase + persisted ACTIVE reviewer | Paginated payment review list; optional status filter |
| GET /admin/payments/:id | Same | Review-safe detail with reference needed for manual verification |
| POST /admin/payments/:id/approve | Same | Empty body; transactional idempotent approval |
| POST /admin/payments/:id/reject | Same | Body `{reason}` with an allowlisted public reason code |

List parameters: page defaults to 1 (1–10000); pageSize defaults to 12 (1–40). Admin status filter accepts PENDING, APPROVED or REJECTED. Unknown query/body fields, invalid UUIDs/slugs and invalid method/reference values return 400. All lists use deterministic ordering, bounded selects and count metadata `{items,total,page,pageSize,hasMore}`.

SafeOrder includes id, amount as a decimal string, currency, status, createdAt, safe catalog book summary and at most one most-recent payment summary. Payment summary includes status, method, createdAt, reviewedAt and a safe public rejection code/null. It excludes the transaction reference, user/admin IDs, internal notes, audit relations and private storage fields. Access exposes no entitlement ID, revocation metadata or reader secret.

Admin review responses add payment id and transactionReference for trusted reviewers to verify the actual manual transfer; reviewer identities and private storage remain excluded. These protected responses use Cache-Control: no-store. No order, payment or ownership query is publicly exposed.

Examples (synthetic intent only; no tokens or merchant credentials):

```json
{"bookSlug":"dev-sample-electronics-study-guide"}
```

```json
{"method":"BKASH","reference":"DEVTEST123"}
```

```json
{"reason":"REFERENCE_NOT_FOUND"}
```

Errors use existing generic `{statusCode,message}` bodies. 401 means missing/invalid verified credentials; 403 denies inactive users/reviewers or unsafe revoked acquisition; 404 hides unknown/foreign resources; 409 handles changed state, reference collision and conflicting ownership; 503 safely disables paid creation/submission when methods are unavailable. Raw database/Firebase bodies and stacks are not returned.

## Manual payment configuration

Added only safe, blank example keys to backend/.env.example:

```dotenv
MANUAL_PAYMENT_BKASH_INSTRUCTIONS=
MANUAL_PAYMENT_NAGAD_INSTRUCTIONS=
MANUAL_PAYMENT_DEVELOPMENT_MODE=false
```

Instruction values are explicitly public receiving instructions, not API secrets/private credentials. They must be nonempty single-line strings of at most 400 characters when supplied. No receiving number/account was invented or committed; the actual local .env and external ADC file were not modified.

Only BKASH/NAGAD are supported. Without instructions, the options list is empty and paid creation/submission fails safely with 503; free acquisition still works. For local UI testing, explicitly set MANUAL_PAYMENT_DEVELOPMENT_MODE=true with NODE_ENV=development and no real receiving instructions. The fallback text is clearly DEVELOPMENT ONLY and says not to transfer money. The flag is rejected outside development. Configured instructions take precedence over a placeholder option; development mode never enables an automatic gateway.

The checked-in default remains disabled. No real payment option was enabled and no real transfer was made in validation.

## Trusted administration and transaction safety

PaymentReviewerGuard uses the existing verified Firebase identity to look up AdminUser by externalAuthId. Only persisted ACTIVE SUPER_ADMIN/PAYMENT_REVIEWER records pass. Normal users, disabled admins and CONTENT_MANAGER are denied. Admins need not be duplicated as normal User records. X-Admin/query roles/Firebase client claims are not trusted. There is no public admin-provisioning endpoint, auto-promotion or seeded real admin. Provision/revoke reviewers only through trusted operator-controlled state.

Purchase writes first lock the owner User row and recheck ACTIVE status. Submission also locks its Order; review locks owner, Order, Payment and reviewer state in a consistent order, then revalidates the fresh records. Book/category share locks protect eligibility and price snapshots against concurrent catalog edits. The owner lock serializes duplicate order creation across processes; existing unique constraints provide additional protection. Future purchase writers must follow this same lock protocol.

Approval atomically verifies payment/order state and equal amount/currency, checks conflicting/revoked ownership, creates entitlement, completes order, approves payment and writes PAYMENT_APPROVED plus ENTITLEMENT_GRANTED audit records. Rejection atomically records safe reason, returns the order to unpaid state and writes PAYMENT_REJECTED. Repeated same-decision calls return the existing result without another grant/audit; contradictory decisions conflict. Any audit/write failure rolls all approval changes back. Unique/serialization collisions become safe 409 responses. Transactions have bounded wait/execution windows; payment mutations are not blindly retried on network failure.

Audit metadata contains only order/payment identifiers, never references, tokens or payment credentials. Existing immutable audit protection remains enabled.

## Entitlement-backed Library

Library requires an ACTIVE user, ACTIVE non-revoked entitlement, COMPLETED source order and currently published book in an active category. It returns safe catalog summaries only. Withdrawn/revoked/inconsistent records are omitted; no private PDF path, coverObjectKey, page asset, download URL or reader token is issued. Purchase-state lookups require a currently eligible catalog book and never infer ownership merely from order/payment existence.

## Flutter implementation

Added typed purchase models/repository, guarded authenticated client, session-aware ChangeNotifier controllers, BookPurchasePanel, manual reference form and order/history screens. Existing architecture, shell, catalog controller, Home/Explore design and authentication transitions remain.

AuthController adds only a read-only protected token/session bridge: it requires an established backend-confirmed session, checks Firebase UID linkage and rechecks identity after token acquisition. Disposal immediately invalidates the bridge and in-flight feature responses. PurchaseApi verifies identity before/after requests and retries a 401 once with a fresh token; persistent auth denial asks the existing controller to revalidate its session. No Firebase SDK/token cache or alternate auth flow was introduced. ApiTransport accepts optional JSON bodies; existing empty auth POSTs and redirect/timeout/response-size protections are preserved.

Book Details remains public. Guests get a Sign In acquisition CTA. Authenticated users get backend-derived Buy/Get free/Continue order/Pending review/Rejected/In Library states. Acquisition and return from order review refresh backend ownership. Completed order state without entitlement never produces an Owned label.

Order review shows the server snapshot, then configured instructions/method selector/reference validation. Submission disables while active; controllers and server both guard double submits. Network submission feedback is beside the submit action; changed-state errors require status refresh. Reference text is retained only in the active form for retry, with suggestions/autocorrect disabled, and disposed when the form closes. No payment reference/token is saved in preferences or logs. Success is a calm pending-review state with manual refresh; there is no polling or pretend approval.

Routes added: `/orders`, `/orders/:id`. They use existing go_router patterns and redirect signed-out users to Login. My Library remains a guest-accessible entry showing a sign-in prompt; authenticated content comes solely from GET /library. It supports loading/empty/error/retry/refresh/pagination, shows In Library on entitled cards, and opens Book Details rather than a PDF. Existing public catalog cards still show prices by default.

Every feature controller binds to the session identity, guards stale epochs/responses, rejects mutations after identity changes and disposes safely. Protected cached UI is cleared on auth changes. The existing blue/gold Material 3 tokens, safe areas, scrolling, live-region notices and touch targets are reused.

## Security review

- Verified ACTIVE-user guards cover all user order/payment/library/access routes; mutation transactions revalidate owner status.
- Persisted reviewer authorization and transaction revalidation protect admin actions; no client role/admin flag is used.
- Order reads/submissions scope by authenticated owner and return safe 404 for foreign records.
- Strict DTOs reject mass assignment of user, totals, currency, status, ownership and admin identity.
- Real server Decimal prices/currency are snapshotted; references cannot mutate totals.
- Pending/rejected payments grant nothing. Revoked/inconsistent ownership cannot be bypassed by free or paid reacquisition.
- User DTOs exclude payment references, arbitrary rejection notes, admin/audit data and all storage/reader fields.
- Protected response caching is disabled; no sensitive logs or new local persistent payment storage exist.
- Existing global body limits, helmet/CORS and auth behavior remain. No new rate limiter was introduced; production deployment still needs its appropriate request-limit/monitoring policy.

## Tests and validation

Backend: **195 unit/HTTP tests** (8 suites), **63 PostgreSQL integration tests** (4 suites), **258 total**. This adds 49 unit/HTTP and 30 database tests to the Phase 3 baseline. Coverage includes auth/role boundaries, forged inputs, safe methods/reference normalization, configuration gating, price snapshots, duplicate/concurrent create/submit/approve, cross-owner reference collisions, IDOR, audit-failure rollback, free/revoked/inconsistent ownership, paid-to-free transitions, sanitized DTOs and real audit writes.

Because audit logs are immutable, real-audit success/rejection/HTTP smoke tests use outer rollback transactions. The committed concurrent approval case stubs only its audit sink while exercising real PostgreSQL locks, order/payment state and entitlement uniqueness; real audit writes and rollback atomicity are covered separately. No audit triggers are disabled or audit records deleted. UUID-tagged fixtures delete only their own users/orders/payments/entitlements/books/categories/admins. A read-only post-test audit found zero Phase 4 fixture users and zero fixture admins remaining.

Flutter: **359 full-suite tests**, preserving 311 existing tests and adding 48 purchase tests. Purchase tests cover guest/sign-in navigation, real-intent payloads and token refresh, identity races/provider disposal, double-submit guards, owned/free/pending/rejected states, 401/403/409/503/network/parse failures, reference validation, status refresh, Library entitlement-only rendering/retry and back navigation. Order form, history and owned Library have 320/360/390-width coverage at 1x/2x text.

Required checks completed:

- dart format .: passed.
- flutter pub get: passed; no dependency changes.
- flutter analyze: no issues.
- flutter test: 359 passed; final run recorded under mobile/build/qa.
- Backend npm test and test:integration: totals above, passing.
- npm run build: passed.
- npm run lint: passed.
- npm run format:check: passed.
- npx prisma validate: valid.
- npx prisma migrate status: two existing migrations; database up to date.
- flutter build apk --debug: passed in **31.4 seconds**, using only the existing process-scoped Kotlin GRADLE_OPTS workaround. APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. No permanent Gradle/Kotlin settings were changed; existing Firebase KGP/native-access compatibility warnings remain non-blocking.

Widget-rendered 360x640 logical previews of order review, manual development instructions/reference form, pending review and Library were inspected with local Roboto/Material icons. Temporary preview code/images/logs are ignored under mobile/build/qa; no application assets or dependencies were added. This is not a claim of device-level real Firebase/payment QA.

## Smoke checks and remaining manual verification

Live local backend: public catalog remains available; unauthenticated GET /orders, /library and /admin/payments return 401. Controlled HTTP integration against real PostgreSQL exercised create, submit, ordinary-user admin denial, approval, audit entries and Library appearance; its verified Firebase identity was simulated only in the isolated test app and its writes were fully rolled back. It did not authenticate to real Firebase or approve a real user's payment.

Owner still needs real-account/device verification of the full UI, session refresh, keyboard/TalkBack and configured public receiving instructions. Google Sign-In manual verification remains deferred. No private credentials were requested. Production receiving instructions/reviewer provisioning/reconciliation policy must be supplied by trusted operators before real payments are accepted.

Deferred: secure PDF serving/downloading/page assets, reader flags/sessions/device limits/progress/offline storage, automatic gateways, refunds/dispute/appeal tooling, user-facing cancellation/expiry policy, subscriptions, AI, reviews/recommendation engine and full admin dashboard. Already-submitted payments remain under review after price changes; refunds/adjustments are not automatic. Invalid/withdrawn catalog books cannot be newly purchased or granted by approval. No bug-free guarantee is made.

## Exact files created / modified / deleted

### created (19)

- `backend/src/purchases/entitlement.service.ts`
- `backend/src/purchases/manual-payment-options.ts`
- `backend/src/purchases/payment-reviewer.guard.ts`
- `backend/src/purchases/purchase-no-store.interceptor.ts`
- `backend/src/purchases/purchase.controller.ts`
- `backend/src/purchases/purchase.dto.ts`
- `backend/src/purchases/purchase.module.ts`
- `backend/src/purchases/purchase.service.ts`
- `backend/test/purchases.integration.spec.ts`
- `backend/test/purchases.spec.ts`
- `mobile/docs/phase-4-purchase-entitlement-validation.md`
- `mobile/lib/features/purchases/data/purchase_repository.dart`
- `mobile/lib/features/purchases/domain/purchase_models.dart`
- `mobile/lib/features/purchases/presentation/book_purchase_panel.dart`
- `mobile/lib/features/purchases/presentation/manual_payment_form.dart`
- `mobile/lib/features/purchases/presentation/order_screen.dart`
- `mobile/lib/features/purchases/presentation/purchase_controllers.dart`
- `mobile/test/purchases_test.dart`
- `mobile/test/support/purchase_fakes.dart`

### modified (14)

- `backend/.env.example`
- `backend/src/app.module.ts`
- `backend/src/config/environment.ts`
- `backend/test/setup.ts`
- `mobile/lib/app/app.dart`
- `mobile/lib/core/routing/app_router.dart`
- `mobile/lib/core/routing/app_routes.dart`
- `mobile/lib/features/auth/data/api_transport.dart`
- `mobile/lib/features/auth/presentation/auth_controller.dart`
- `mobile/lib/features/catalog/book_details_screen.dart`
- `mobile/lib/features/catalog/widgets/catalog_widgets.dart`
- `mobile/lib/features/library/library_screen.dart`
- `mobile/test/catalog_test.dart`
- `mobile/test/support/auth_fakes.dart`

### deleted (0)

None.
