# Backend foundation and schema contract

## Modules

AppModule imports validated global ConfigModule, PrismaModule, HealthModule and AuthModule (which imports FirebaseModule). configureApp applies versioned routing and shared HTTP safety. PrismaService is the singleton PostgreSQL adapter client, generated with Prisma 7. Phase 2A identity/account guards and typed decorators are implemented; no placeholders are created for unimplemented features. See firebase-authentication.md for the current identity and bootstrap contract.

## Relational models

All identifiers are application-generated UUIDs. Mutable records have createdAt/updatedAt timestamps; append-only AuditLog events intentionally have only createdAt. All timestamps use timestamptz. All foreign keys specify update/delete behavior.

- User: required unique future externalAuthId, case-insensitive unique email, display name and explicit ACTIVE/SUSPENDED/DISABLED status. No password. Phase 2A now verifies Firebase ID tokens and bootstraps by this identity link.
- Category: unique slug, active flag and sort order. Book references one category.
- Book: unique slug, Decimal(12,2) price and BDT currency, DRAFT/PUBLISHED/ARCHIVED state, optional known page count, preview count, cover object key/alt text. No original PDF URL, PDF storage key, upload or storage service.
- Order: a single book per order, price/currency snapshot, PENDING_PAYMENT/PAYMENT_SUBMITTED/COMPLETED/CANCELLED states. Multiple manual payment attempts can belong to one order.
- Payment: BKASH/NAGAD method, globally case-insensitive unique alphanumeric transactionReference, positive Decimal amount, PENDING/APPROVED/REJECTED state and optional reviewer metadata. Global uniqueness deliberately prevents reuse even across providers/users. An additional partial unique index permits at most one APPROVED payment per order. Review consistency is a database check; approval/amount matching/idempotency are future transactional service rules.
- Entitlement: unique user/book, one source order, ACTIVE/REVOKED status. The composite source FK enforces the same user and book as the order. This is the future access authority; neither Flutter nor progress records grant access. Initial grants must explicitly pass status ACTIVE after server-side verification; schema defaults to REVOKED as a fail-closed foundation. Activation and completed-order/payment validation require future server transactions, not client writes.
- Device: user/deviceIdentifier uniqueness, platform, ACTIVE/REVOKED status and last-seen metadata. No fingerprinting implementation.
- Session: unique 64-character hexadecimal token digest, expiration/revocation metadata. Composite FK ensures the device belongs to the session owner. No plaintext tokens, issued tokens or auth endpoints.
- ReadingProgress: unique user/book and a positive page number. It cannot authorize reading.
- AdminUser: required future external identity, case-insensitive unique email, explicit SUPER_ADMIN/CONTENT_MANAGER/PAYMENT_REVIEWER role (no default role/account), status.
- AuditLog: relational actor, action and polymorphic target type/UUID. JSON is used only for extensible event details; future writers must allowlist nonsecret metadata. A database trigger prevents mutation/deletion of recorded events. Target UUID cannot have one FK because targets can be different entity types.

Paid/catalog/audit relationships restrict deletion to preserve history; disable/archive/revoke records instead. User deletion cascades only device/session/progress metadata; finance/entitlement relationships still block deleting purchasers. Audit actor deletion is restricted.

## Database invariants and indexes

PostgreSQL citext enforces email/payment-reference case-insensitive uniqueness. Checks reject whitespace variants, negative monetary values, non-BDT currency in this MVP, invalid page counts/preview counts, invalid token digests/session expirations, and inconsistent review/revocation metadata. Partial approved-payment uniqueness and checks are maintained in migration SQL because Prisma schema cannot represent all SQL constraints. Preserve these when adding migrations.

Composite ownership FKs prevent a payment assigned to another user's order, a wrong-user/book entitlement, or a session assigned to another user's device. Indexes cover publication/category browsing, user order history, pending verification, active entitlements/devices/sessions, session expiry, recent progress and actor/target audit lookup. Unique constraints already supply indexes; no redundant separate indexes are added for unique-only lookups.

These constraints cannot independently prove real payment verification or enforce allowed lifecycle transitions. Later services must use transactions and server authentication/authorization, never trust client status/price fields. No catalog, payment, secure-reader or admin routes exist in this phase.

## Next phases

2. Backend Phase 2A complete: Firebase ID-token verification and user bootstrap. Flutter Firebase Authentication integration is next.
3. Category/book catalog APIs.
4. Manual payment submission and audited admin verification.
5. Transactional orders and entitlement authorization.
6. Private PDF processing and secure page delivery.
7. Device/session controls, rate limits and watermarking.
8. Next.js admin panel.
