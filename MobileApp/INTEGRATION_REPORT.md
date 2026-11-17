# Trivia Flutter integration report

Historical integration record. Signing behavior has changed since this report: current Gradle configuration allows debug signing when production credentials are unavailable. See README.md and VALIDATION.md for current guidance.

## Implementation scope

Modified MobileApp only. Existing screen structure, branding, navigation, onboarding assets and platform signing policy retained. No Django endpoints or React modules were changed. No production writes, OTP dispatch, driver approval or ride creation were performed during verification.

## Removed application simulations

Removed the runtime DemoRepository, demo-enabled default and configuration flags, fixed OTP text, sample landmark search results, fictional road-distance/fare quotes, simulated driver identities/offers/selection/approval, synthetic history/notifications/earnings and no-op backend writes. Synthetic fixtures moved exclusively into test/support for deterministic offline tests; they are not imported by application code.

Legitimate constants retained: category/payment/status enums, UI assets/themes, initial map viewport and debounce/reconnect/OTP countdown timers. User-entered draft fields and recent actual selections are local UI state, not fabricated backend records.

## APIs and behavior

- Default production origin, API prefix and HTTPS validation; Dio GET/POST/PATCH/PUT/DELETE, multipart, timeouts, trusted-origin validation, nested backend errors and secure token storage.
- Real OTP/profile and rotating JWT flow, single-flight refresh/replay, revocation handling, network-error credential retention and HTTP 204 logout handling.
- Server-fed quote/payment configuration; real booking UUID/idempotency keys, exact-cent limits, offline payment preference and pickup notes. Double taps blocked and uncertain retry reuses the booking key.
- Actual active rides/offers, passenger-selected real offer IDs, backend lifecycle commands, terminal expired state, real authorized tracking with decimal GPS/freshness and no simulated movement.
- Requirement-driven driver draft/document/vehicle upload/submit flow, expiry inputs, backend availability confirmation, real requests/decline/counteroffers and server earnings values. No driver self-approval, invented commission or payout.
- Owner history/notification pagination, saved places, support/safety/ratings/contact payload mappings and backend preferences. Unsupported deletion disabled and documented.
- Native WSS uses documented first-frame JWT/connection.ready and same-origin Origin header, with heartbeat, reconnect and authoritative REST resync. Real GPS uploads are throttled and use actual foreground fixes/heartbeat; hardware behavior unverified.

## Files modified

lib/core/{config,repository,realtime,api_error}.dart; lib/app/{app,controller}.dart; lib/shared/{models,widgets}.dart; passenger home/booking controller/fields; driver home/registration; account and entry screens. Existing tests updated to import test-only fixtures; added api_repository_test.dart and test/support/fixture_repository.dart. README and the four required reports updated. Pubspec dependencies, platform signing keys and backend source were preserved.

## Verification and limits

- `flutter pub get`: passed; no package upgrades performed. The tool reported newer versions outside existing constraints.
- Initial `flutter analyze`: identified references left from simulation removal, then lint fixes applied. Final results recorded below.
- New HTTP adapter tests: initial five passed (origin/OTP/server tokens, concurrent refresh, revoked refresh, empty history/untrusted pagination origin and backend fare/GPS/expired parsing). Additional network-retention/logout tests and the full suite are included in final results.
- Existing booking UI test exposed a horizontal text overflow and an outdated single-TextField selector after the notes field. The form retains the layout with flexible text; the test targets the fare controller. Widget fixtures now initialize secure storage explicitly to avoid awaiting unavailable native plugins.
- `flutter build apk --release --no-pub`: failed at existing signing validation. Required TRIVIA_KEYSTORE, TRIVIA_STORE_PASSWORD, TRIVIA_KEY_ALIAS and TRIVIA_KEY_PASSWORD were not configured. No replacement key, debug signing or unsigned success claim was introduced. Tooling also warned about Android SDK XML version mismatch.
- iOS build not run: this Linux environment cannot perform Xcode/IPA signing.
- Live read-only probes: `/health/` 200, `/ready/` 503, `/api/v1/users/me/` 401 without credentials. These confirm reachability/auth boundary, not successful customer workflows.
- Live schema `/api/schema/`: 302 to staff login; following returns HTML. Full local OpenAPI was used; deployed parity is unverified.

Real-device authentication/SMS, driver verification/uploads, road-provider pricing, bookings/offers/assignment/trip completion, GPS/native WSS and push delivery remain unverified live. They require a ready deployment and safe staging accounts. Missing contract gaps are listed in MISSING_API_ENDPOINTS.md; no unavailable feature is replaced with invented records.
