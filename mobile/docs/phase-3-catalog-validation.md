# Phase 3 catalog validation

## Scope and audit

Inspected the existing Category/Book schema, two migrations, Prisma service and configuration, Nest application/module wiring, global validation and safe exception filter, auth transport/ApiConfig, router and auth redirects, Home/Explore components, shared design tokens and regression tests. No dependency was added or upgraded. Authentication implementation, Android/Firebase configuration, reader protection and backend authority were preserved.

No migration was needed: Category already provides active visibility and ordering; Book already provides unique slugs, publication status, category, decimal price, currency, description and optional page count. Existing category/status/date indexes are reused. There is no author, edition, rating, featured flag or public cover URL, so these were not invented.

## Backend architecture and API contract

CatalogModule registers a public controller and CatalogService backed by the existing shared PrismaModule. Global `/api/v1` routing, ValidationPipe and SafeExceptionFilter apply. No Firebase token is necessary for public browsing.

- `GET /api/v1/categories`: array of `{id, name, slug, description}`. Only active categories, sorted by sortOrder, name and id. No per-category count queries.
- `GET /api/v1/books`: `{items, total, page, pageSize, hasMore}`. Each item has `{id, slug, title, price, currency, pageCount, createdAt, category: {id, name, slug}}`. Decimal prices serialize as strings; pageCount may be null. Full descriptions are intentionally fetched only for details.
- `GET /api/v1/books/:slug`: the same public metadata plus description. Lookup uses the existing unique slug. Missing, draft, archived and inactive-category books return the same safe 404. Invalid slug syntax returns 400.

Book queries:

| Parameter | Default | Rules |
| --- | --- | --- |
| page | 1 | Integer 1–10000 |
| pageSize | 12 | Integer 1–40; larger values rejected with 400 |
| search | absent | String up to 120 characters after trimming/collapsing whitespace; case-insensitive title substring via Prisma contains |
| category | absent | Existing category slug syntax, maximum 160 characters |
| sort | newest | newest, title, price-asc, price-desc |

Unknown parameters, arrays and invalid values are rejected. Every sort has an id tie-breaker. Book count and bounded page selection share a repeatable-read transaction. Only PUBLISHED books in active categories are eligible. No unsafe SQL or fetch-all-then-filter path is used. PostgreSQL LIKE semantics apply to `%` and `_` in search; query values remain parameterized.

Examples (no credentials):

```text
GET http://127.0.0.1:3000/api/v1/categories
GET http://127.0.0.1:3000/api/v1/books?page=1&pageSize=12&sort=newest
GET http://127.0.0.1:3000/api/v1/books?search=circuit&category=dev-sample-circuit-theory&sort=price-asc
GET http://127.0.0.1:3000/api/v1/books/dev-sample-circuit-theory-study-guide
```

## Development seed

From backend, run `npm.cmd run seed:development`, or explicitly `npx.cmd prisma db seed`. Prisma 7's migrations.seed invokes the same command. It requires NODE_ENV=development and a localhost/127.0.0.1 database before connecting. Configuration/ADC remain local; no credential file is copied or printed.

The transaction inserts eight EEE subject categories and eight clearly labeled development sample study guides using the `dev-sample-` slug namespace. One guide is free. Covers remain null and no files are bundled. createMany/skipDuplicates never overwrites existing records; an occupied category namespace with a different marker aborts the transaction. No users, purchases or entitlements are created. No reset, truncate, migration or volume removal is performed.

Executed twice successfully; the running public API reports eight categories and eight books afterward. Existing sample edits and matching slug records are left intact. This seed is optional development data, not production publication tooling.

## Flutter implementation

Feature-first catalog domain models, CatalogRepository/CatalogApi and ChangeNotifier controllers follow the existing application style. The public client reuses ApiConfig and the existing transport without modifying auth transport behavior. GET requests carry only Accept, never bearer tokens. Existing 5-second connect/15-second request deadlines, response limit and redirect protections remain in effect. Parsing and transport errors map to safe catalog messages; 404 details are distinguished.

Home now loads real categories and eight latest published books. The established brand header, educational banner, search entry and quick-access intent remain. Unsupported discount, rating and personalized recommendation claims are removed. Since no featured flag exists, the section is honestly named Latest books. Category taps open a filtered Explore route; cards open details. Loading, empty, independent category/book failures, retries and pull-to-refresh are available.

Explore loads real categories and books, offers All/category chips and actual schema-supported sorting. Search waits 350 ms; request generations immediately invalidate older results. Filter/sort changes reset pagination. Load more guards concurrent calls and deduplicates slugs. Failed append preserves existing results and retries the failed page. Refresh reloads both categories and books. Controller disposal cancels debounce and ignores late responses.

`/books/:slug` is a public detail route. It supports loading, safe unavailable/error/retry states, description, category, price/free label and optional page count. Deep-link back falls back to Explore. It explicitly explains that purchasing/reading are not available, with no fake purchase or reader action.

Shared branded fallback covers use existing navy/blue/gold tokens and a deterministic category-based gradient. No private coverObjectKey is turned into a URL. Natural-height lazy card rows use two columns where space/text scale permits and one column for larger text or narrower constraints. There are no intrinsic measurements, nested scroll views, polling, new state frameworks or new dependencies.

## Security review

- Explicit Prisma allowlists omit storage keys, private file URLs, status internals, identities, admin/audit data, orders and entitlement relations.
- Public details never grant purchase ownership or reading rights, including free resources.
- Guest catalog requests neither acquire nor refresh Firebase tokens.
- Existing auth controllers, session semantics, 401/403/409/503 handling, backend guards and protected reader routing are unchanged.
- No raw backend body, exception, token, password or Authorization header is displayed or logged.
- Existing safe startup and exception behavior is retained.

## Regression coverage and validation

Backend additions cover HTTP query validation, public access, defaults, maximum page size, normalized search, category/sort forwarding, deterministic query construction, exact safe selects and safe missing-book status. PostgreSQL fixtures test pagination, search, category filtering, numeric price order, DTO serialization, private-field exclusion, draft/archive/missing visibility and inactive categories. Cleanup deletes only this suite's UUID-tagged fixtures.

Flutter additions cover summary/detail parsing, malformed price/JSON/pagination, credential-free GETs, safe backend/network errors, debounce and stale responses, duplicate/concurrent pagination, category races, independent failures, sorting/refresh, disposed details, Home loading/error/empty/data, filtering, append/retry, detail states, both entry routes, fallback covers and live-region semantics. The existing Home tests now inject real-contract fixtures instead of asserting mock prices/ratings; their responsive/navigation intent remains. Existing auth tests were preserved.

Results:

- Backend unit/HTTP: **146 passing** (7 suites).
- Backend PostgreSQL integration: **33 passing** (3 suites).
- Total backend: **179 passing**.
- Flutter: **291 passing**, including all existing auth regressions and 43 new catalog tests.
- `dart format .`: passed.
- `flutter analyze`: no issues.
- `npm.cmd run build`: passed.
- `npm.cmd run lint`: passed.
- `npm.cmd run format:check`: passed.
- `npx.cmd prisma validate`: valid.
- `npx.cmd prisma migrate status`: two existing migrations; database up to date.
- Live API smoke: eight categories/eight books, pagination, details, category filter and privacy passed; oversized page returns 400 and missing book returns 404.
- `flutter build apk --debug`: passed in 102.0 seconds using only process-scoped GRADLE_OPTS. Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Existing Firebase KGP/native-access compatibility warnings are non-blocking; versions/configuration were not changed.
- Android runtime: `adb install -r` succeeded and preserved app data. `adb shell am start -n com.eeelibrary.eeelibrary/.MainActivity` succeeded on emulator-5554 (720x1280, density 320). However, the emulator remained on Android's native Flutter launch screen after a process-only restart, so the final on-device composition is NOT marked as verified. Sanitized process diagnostics found the Flutter library/VM running, no Flutter exception, Android fatal exception, negative constraints or out-of-memory error; the Dart isolate was runnable and not paused. The underlying startup delay remains undiagnosed. This occurs before catalog UI; existing main/Firebase initialization was inspected and left unchanged. Automated widget/layout tests and live backend checks passed independently. A fresh-launch/runtime check remains manual.

Responsive widget coverage includes 320/360/390 widths, short 568-height viewports and double text size; Home also retains its 412-width and 1.5x coverage. No overflow/layout exceptions were observed.

## Limitations and manual checks

Google Sign-In and real-account login remain explicitly deferred to the owner; no credentials were requested or used. Verify device-level screen-reader announcements, keyboard behavior and final typography on your target devices. Cover URL delivery, purchase/entitlement workflows and secure PDF reading are outside this phase. The existing transport rejects responses above 64 KiB; oversized future detail text/category datasets fail safely and will need a deliberate response-size policy. Page-number browsing is bounded; cursor pagination/full-text search can be introduced if measured catalog size warrants it. No API-level popularity/featured/personalization is claimed.

## Exact file changes

### created (15)

- `backend/src/catalog/catalog-query.dto.ts`
- `backend/src/catalog/catalog.controller.ts`
- `backend/src/catalog/catalog.module.ts`
- `backend/src/catalog/catalog.service.ts`
- `backend/src/catalog/seed-development.ts`
- `backend/test/catalog.integration.spec.ts`
- `backend/test/catalog.spec.ts`
- `mobile/docs/phase-3-catalog-validation.md`
- `mobile/lib/features/catalog/book_details_screen.dart`
- `mobile/lib/features/catalog/data/catalog_repository.dart`
- `mobile/lib/features/catalog/domain/catalog_models.dart`
- `mobile/lib/features/catalog/presentation/catalog_controller.dart`
- `mobile/lib/features/catalog/widgets/catalog_widgets.dart`
- `mobile/test/catalog_test.dart`
- `mobile/test/support/catalog_fakes.dart`

### modified (10)

- `backend/package.json`
- `backend/prisma.config.ts`
- `backend/src/app.module.ts`
- `mobile/lib/core/config/api_config.dart`
- `mobile/lib/core/routing/app_router.dart`
- `mobile/lib/core/routing/app_routes.dart`
- `mobile/lib/features/explore/explore_screen.dart`
- `mobile/lib/features/home/home_screen.dart`
- `mobile/lib/features/home/widgets/promo_banner.dart`
- `mobile/test/home_screen_test.dart`

### deleted (6)

- `mobile/lib/features/home/data/mock_home_data.dart`
- `mobile/lib/features/home/widgets/book_card.dart`
- `mobile/lib/features/home/widgets/category_card.dart`
- `mobile/lib/features/home/widgets/compact_book_card.dart`
- `mobile/lib/features/home/widgets/home_collections.dart`
- `mobile/lib/features/home/widgets/quick_access_item.dart`
