# Admin /admin/me local runtime investigation

The actual Next.js dev client contains API base http://127.0.0.1:3000/api/v1 and constructs http://127.0.0.1:3000/api/v1/admin/me. Its process started after admin/.env.local was updated. No missing/duplicated prefix, wrong port, or stale API origin was found. Firebase Web initialization and backend /admin/me schema/role/status projections agree. Backend authorization remains the verified Firebase UID lookup of persisted ACTIVE AdminUser.

## Reproduced cause

AdminApi stored browser fetch in a property and called this.transport(...). The property call supplies the AdminApi object as the native function receiver. Native Window.fetch rejects that receiver with TypeError: Illegal invocation. AdminApi then converted that client-side exception to its safe 503 ApiError, and SessionProvider displayed its generic backend-access message. This was not an HTTP 503, backend 401/403/404, or a 200 parsing/state mismatch: no HTTP response existed.

A headless Edge probe ran the actual AdminApi source from the localhost:3001 origin against the existing backend. It used an intentionally invalid, nonsecret probe credential; no real Firebase session/token/password was inspected or logged. Safe observations:

| Stage  | Host/path                       | Token acquired | HTTP status | Fixed category                  |
| ------ | ------------------------------- | -------------- | ----------- | ------------------------------- |
| Before | 127.0.0.1:3000 /api/v1/admin/me | true           | none        | native-fetch-illegal-invocation |
| After  | 127.0.0.1:3000 /api/v1/admin/me | true           | 401         | http-response                   |

The post-fix 401 is expected for the deliberately invalid probe credential. It proves native transport now reaches the real backend and invalid credentials remain rejected; it is not a claim that the owner's valid Firebase account was rejected. Real-account confirmation requires clicking Try Again after restart; no password or token needs to be shared.

## Minimal change and regression

Invoke the transport with globalThis as the receiver through transport.call(globalThis, ...). This is Window in the browser and works with Node/test transports. URL construction, fetch options, token acquisition, one forced refresh after HTTP 401, no-store policy, Firebase verification, CORS, persisted role checks, and password visibility are unchanged.

Two receiver-sensitive tests failed against the original code (safe 503 rejection), then passed after the fix. They cover default browser transport and the one-refresh retry. Earlier Node/arrow-function mocks ignored this binding; the earlier browser UI fixtures also replaced window.fetch with an arrow function, masking native behavior.

No production diagnostics were added. Temporary isolated browser probes/logs are ignored under .qa and contain only safe operation/host/path/status/category/token-presence observations. No backend or mobile code changed.

## Final validation

- Admin tests: 94 passing tests in 6 files, including the two receiver regressions.
- Lint, typecheck, production build and browser-bundle audit: passed; 11 browser files scanned, no server credential markers.
- Backend code unchanged; backend tests were not required/rerun.
- Next.js dev process fully restarted on port 3001 after validation. Served client verified to contain the configured API URL and global receiver fix. Existing backend health remains 200.
- Remaining owner verification: retry the existing real Firebase admin session in the refreshed browser tab. No new configuration/provisioning step is required for this fix.

Changed files: admin/src/lib/api.ts, admin/test/fetch-binding.test.ts, and this investigation report. No temporary production diagnostics or dependencies were added.
