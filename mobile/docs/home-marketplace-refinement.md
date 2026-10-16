# Home marketplace UI refinement

## Inspection and reference status

Inspected HomeScreen, the Home header/search/banner/section components, the shared navigation shell, branding and design tokens, public catalog models/controller/repository, and existing Home/catalog/auth regression tests. Existing routing and API contracts were preserved.

The request did not contain an accessible homepage image. The available design_refs files were inspected: auth_reference.jpg and auth_reference2.jpg are educational illustrations, and get_started_reference.jpg is the onboarding reference. A Home reference path was requested asynchronously but was not received during implementation. The detailed written homepage specification therefore guided this original composition; no direct image-match claim is made.

## Presentation changes

- Compact brand lockup places EEELibrary, notifications and profile in one row on normal phones. It stacks safely at larger text sizes. The unsupported unread-notification badge was removed.
- Rounded, touch-friendly search/filter actions retain the existing Explore route.
- A navy-to-blue hero uses a gold CTA, stronger heading hierarchy and lightweight widget-built book artwork. Artwork is decorative and yields space to text at enlarged scales. No discount or offer is invented.
- Real category shortcuts replace filter chips on Home. The backend-ordered first eight categories use deterministic icons, soft brand tints and aligned label areas. Four columns fit when each shortcut has adequate width; two columns serve narrower/larger-text layouts, and one column handles very tight constraints. See All exposes the complete catalog through Explore. Category taps retain the category slug query.
- Latest books presents the first four returned books in a cover-first horizontal shelf. Discover more presents the next four with narrower cards, and is omitted when no additional records exist. These are transparent selections from the existing latest catalog, not backend-featured flags or personalized recommendations.
- Branded navy/blue/gold covers display real titles and the EEELibrary name. Ratings are omitted because the model has no ratings. Title/category truncation retains full accessible labels.
- Syllabus, Previous Questions, Bookmarks, Free Samples, Wishlist and Downloads appear in a six-item utility grid. Every item visibly says Coming soon and provides an accessible non-blocking availability notice. No utility grants content access or creates fake state.
- Existing Home/Explore/Library/Profile navigation receives a white surface, restrained top border and existing blue selection colors. No Cart route/tab was added.

## Data, architecture and safety

Category/book titles, prices, categories, free labels and detail navigation come from the existing catalog repository/controller. Home still requests eight latest books; rendering/shelf scrolling does not fetch additional pages. Separate category/book loading, error, retry and empty states remain, along with pull-to-refresh.

Icons, cover styling and hero artwork are presentation fallbacks only. No API, Prisma, Firebase, auth/session, payment, order, entitlement, reader, token, credential, storage or routing logic was changed. No dependency or production asset was added. Shared Explore/Details cards remain unchanged.

The two shelves each construct at most four cards, so natural-height horizontal rows are deliberately bounded rather than using fixed-height/intrinsic layouts. The outer vertical list remains lazy. No IntrinsicHeight/IntrinsicWidth, animation controllers, large raster artwork, heavy shadows or nested vertical scrolling were added. Spacing, radii and colors reuse existing tokens.

Headings have header semantics; book cards and shortcuts expose full labels and tap actions; decorative artwork is excluded; availability notices use live regions. Header actions retain 48-pixel minimum targets. Shortcut label slots derive minimum height from the active typography/text scale and may grow naturally.

## Regression coverage

Existing Home tests retain layout and navigation coverage while targeting the new Home-specific cover/card presentation. One catalog test now expects the Home-specific card after a successful retry; Explore/Details assertions remain unchanged. No auth tests were removed or weakened.

Twenty new Home tests cover:

- Eight-category/two-shelf layouts at 320, 360 and 390 widths, with 1x and 2x text.
- A compact header and visible hero CTA at 360x640 logical Small Phone dimensions.
- Compact shelf to real details and back.
- Safe feedback for all six utilities without navigation/access changes.
- See All routing, full accessibility labels and semantic tap actions.
- No additional catalog requests during rebuild/shelf scrolling; no fake ratings, personalized label or Cart.
- Shortcut grid constraints of 0, 120 and 200 pixels without negative constraints/layout exceptions.

## Validation

- dart format .: passed.
- flutter pub get: passed; dependency versions unchanged.
- flutter analyze: no issues.
- Full flutter test: **311 passed** (291 existing plus 20 new).
- Final Home/Home-marketplace/catalog focused run: **82 passed**, including the last alignment refinement.
- Widget-rendered visual preview: passed; actual Home widgets rendered at 360x640 logical / 720x1280 output with local Roboto and Material icons. Top, shelves and utilities were reviewed. Preview artifacts and the temporary rendering harness are ignored under mobile/build/qa and are not application assets.
- flutter build apk --debug: passed in **78.3 seconds**. Output: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. Used only process-scoped GRADLE_OPTS for the existing Windows Kotlin setup; no Gradle files were changed. Existing Firebase plugin/Kotlin and native-access compatibility warnings remain non-blocking.

## Limitations and manual review

Direct comparison with the requested homepage image remains pending its path. Verify final device typography, TalkBack, horizontal swipe discoverability and larger system text on target Android devices. The visual previews are widget renders with injected catalog fixtures, not a claim of a completed device-level authentication/runtime check. The existing real catalog/auth regressions pass. No real Google/account login was attempted.

Ratings, actual public cover URLs, featured selection, personalization, Cart, purchases and the six utility modules remain future product/backend work. The second shelf is hidden rather than duplicating or inventing books when fewer than five records are returned. Existing light-theme design tokens were preserved; no new dark theme was introduced.

## Exact file inventory

### created (4)

- `mobile/docs/home-marketplace-refinement.md`
- `mobile/lib/features/home/widgets/home_book_shelf.dart`
- `mobile/lib/features/home/widgets/home_shortcuts.dart`
- `mobile/test/home_marketplace_test.dart`

### modified (8)

- `mobile/test/catalog_test.dart`
- `mobile/lib/core/widgets/main_shell.dart`
- `mobile/lib/features/home/home_screen.dart`
- `mobile/lib/features/home/widgets/home_header.dart`
- `mobile/lib/features/home/widgets/home_search_bar.dart`
- `mobile/lib/features/home/widgets/promo_banner.dart`
- `mobile/lib/features/home/widgets/section_header.dart`
- `mobile/test/home_screen_test.dart`

### removed (0)

None.
