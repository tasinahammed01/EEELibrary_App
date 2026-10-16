# Authentication feedback UX validation

Authentication remains Firebase-backed and backend-authoritative. Changes concern presentation, contextual messages and safe feedback metadata. No backend, dependency, Android configuration, transport, token retry, routing, hero asset or database change was made.

## Feedback strategy

| Situation | Experience |
| --- | --- |
| Invalid email/password credentials | Inline form error: Email or password is incorrect. |
| Local validation | Existing field-level validators and focus behavior remain. |
| Connection failure | Rounded, non-blocking warning banner: We couldn't connect to EEELibrary. Check your connection and try again. |
| Fresh login/verification or unconfirmed restoration receives persistent 401 | Neutral sign-in-completion feedback; never claims an established session expired. Existing one-refresh retry and sign-out cleanup remain. |
| Backend-confirmed session later becomes invalid, or genuine Firebase session loss | Your session expired. Please sign in again. The app shell receives an accessible floating SnackBar with Sign In, keeping guest browsing available. Login also shows the contextual inline message. |
| Backend 503 | Existing Account Access screen: Temporarily unavailable, with safe explanation and Try again. |
| 403 / DISABLED / SUSPENDED / Firebase-disabled account | Dedicated safe Account Access UI. Firebase-disabled sign-in failures now also reach that presentation instead of remaining on Login. No application identity is granted. |
| Backend 409 | Dedicated account-conflict heading and safe existing message, without identity/collision details. |
| Reset email success | Accessible blue success banner, with the same generic confirmation for an unknown account. |
| Verification sent/resend | Calm success banner and existing cooldown/check/sign-out actions. An unverified manual check uses an informational notice. |
| Google cancellation | Quiet cancellation; no dialog or scary banner. |
| Google credential failure | Google-specific completion message, without blaming email/password fields. |

Network banners do not duplicate the primary form action with an extra Retry button. The existing backend status retry remains useful for a new backend confirmation. No passwords are retained to implement automatic retries.

## Visual and accessibility behavior

Reusable AuthFeedback uses existing spacing/radius/color tokens plus Material 3 semantic error colors. Icons are decorative and excluded from screen-reader speech; text is in a live region. Expanded text wraps without truncation. AnimatedSize uses Material's theme animation duration and switches to zero for reduced motion. Success uses the existing blue tint and notices use warm gold in light mode. Theme color pairs are used in dark mode. The application still has its existing light theme; a complete dark app theme was not introduced.

Floating SnackBar styling is centralized in AppTheme (navy, white, gold action, existing rounded shape). The app-owned listener announces established-session loss once, guards deferred callbacks after disposal, removes its listener on disposal and hides the old expiry notice when a new auth operation starts. No additional auth service, state framework, polling, token storage or route guard was added.

## Exact files created

- `mobile/lib/features/auth/widgets/auth_feedback.dart`
- `mobile/test/auth_feedback_test.dart`
- `mobile/docs/auth-feedback-validation.md`

## Exact files modified

- `mobile/lib/features/auth/auth_status_screen.dart`
- `mobile/lib/features/auth/domain/auth_models.dart`
- `mobile/lib/features/auth/presentation/auth_controller.dart`
- `mobile/lib/features/auth/verification_screen.dart`
- `mobile/test/support/auth_fakes.dart`
- `mobile/lib/app/app.dart`
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/lib/features/auth/login_screen.dart`
- `mobile/lib/features/auth/register_screen.dart`
- `mobile/lib/features/auth/widgets/auth_widgets.dart`

No files deleted. The test fake gained only a Google-failure hook for deterministic provider UX coverage; production Firebase integration is unchanged.

## Validation

- `dart format .`: completed.
- `flutter analyze`: No issues found.
- `flutter test`: **248 passed**, including the previous 211 tests and 37 new feedback regressions.
- `flutter build apk --debug`: passed. APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. The documented Windows Kotlin workaround was applied only to the build process via GRADLE_OPTS; no permanent Gradle/Kotlin setting or package version changed.

The new tests cover real form submission feedback, network banner, neutral fresh login/verification/restoration 401s, genuine established-session SnackBar and Sign In navigation, 403/409/503 status UI and retry, disabled/suspended DTOs, Firebase-disabled UI, generic reset success, verification send/resend cooldown, quiet Google cancellation and contextual Google credential failure. Fifteen layout cases exercise actual feedback at 320/360/390 widths with 2x text and keyboard insets. Six light/dark component cases verify live-region semantics, reduced motion and text contrast of at least 4.5:1.

## Security and remaining manual verification

Raw exceptions, backend bodies/stacks, tokens, passwords and Authorization headers are never used in feedback. Existing sanitized error mapping, backend ACTIVE checks, single forced refresh retry, denial states, explicit sign-out behavior and backend authority remain. Message classification is presentation metadata and cannot authenticate a user. No new credential logging was added.

This UX task did not perform real-account sign-in or alter the previously diagnosed Windows clock configuration. On a physical Android device, manually verify TalkBack announcement timing and the visual banners/SnackBar after the documented time synchronization and real-account setup. Automated tests validate semantics and layout, not actual email delivery or Google OAuth.
