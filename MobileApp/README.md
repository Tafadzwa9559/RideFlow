# Trivia mobile

**Your Journey. Your Choice.** Developed by MOrdec Solutions (Private) Limited.

This extends the existing Flutter Android/iOS project. The Dart package name and Android activity namespace remain `rideflow_mobile` for compatibility; store identifiers and display names use Trivia. No website or Django source files are modified.

## Run

Flutter 3.47.2 / Dart 3.13.2 was available during implementation.

```sh
flutter pub get
flutter run --dart-define=TRIVIA_DEMO=true
```

Demo is **enabled by default**, including release builds. A persistent banner identifies simulations. Verify a valid-format phone number using **123456**; this code exists exclusively in the demo repository. Onboarding, location selection, payment/currency selection, and explicit developer driver simulations are available. Passenger booking now requires a real backend road quote: demo mode does not invent a distance, fare or exchange rate and therefore does not submit a passenger request without one. See [the booking integration guide](../Backend/docs/booking.md) for the actual implemented Django endpoints, pricing configuration, exchange-rate verification, migration steps and test coverage.

In Account, switch to Driver, complete the application, or use **Developer demo: simulate approval**. Go online, open Requests, submit an offer, and use **Developer demo: simulate passenger selection** to exercise the driver trip lifecycle from Home. Going offline does not cancel an active trip. Switch modes only after finishing/cancelling a trip. Demo sessions, documents, saved places, and ride history are intentionally held in memory; onboarding completion persists across launches.

## Implemented mobile workflows

- Initialization, first-run onboarding with swipe/skip/indicators and reduced-motion handling, phone validation, resend countdown, OTP errors, profile setup, session expiration, logout.
- Interactive map with attribution, permission-aware foreground GPS, debounced search, bookmark/recent places for the session, map-pin selection, Standard/Comfort/XL, exact-cent fare validation.
- Passenger request/offers/confirmation, fixed agreed fare, valid lifecycle transitions, cancellation confirmations, history/status/date filters, trip summary, ratings and disputes.
- Backend quote adapter renders **road geometry, distance, duration, minimum fare and service availability only when returned by the API**. No straight-line route is presented as a road route. Demo shows endpoints without fabricated distance or travel times.
- Driver application with configurable document requirements, gallery image selection and multipart upload adapter; approval gating, foreground-location gating, online/offline, requests, counteroffers, driver trip controls, earnings periods.
- Backend-fed payment method/history views, notifications, safety trip-summary sharing, incident/support/contact forms, preferences and account deletion request.
- Secure token storage, HTTPS/WSS configuration checks, authenticated REST, session-expiration handling, WebSocket tickets/reconnect/heartbeat/resubscribe and authoritative refresh; polling fallback; lifecycle cleanup.

## Backend integration status

The Django backend now implements authenticated road quotes, configurable pricing and coverage, verified USD/ZiG exchange-rate records, payment/currency configuration, idempotent passenger bookings, trip retrieval/cancellation, payment records and profile restoration. The remaining broad API table below includes planned endpoints; **[Backend/docs/booking.md](../Backend/docs/booking.md) is authoritative for the implemented booking contract.** Real OTP delivery, dispatch/driver offers, mobile-money checkout, push delivery and operational support still need provider integration. No live-provider ride or payment test is claimed.

```sh
flutter run \
  --dart-define=TRIVIA_DEMO=false \
  --dart-define=TRIVIA_API_URL=https://api.example.com/mobile/v1 \
  --dart-define=TRIVIA_WS_URL=wss://api.example.com/ws/mobile/ \
  --dart-define=TRIVIA_PRIVACY_URL=https://example.com/privacy \
  --dart-define=TRIVIA_TERMS_URL=https://example.com/terms
```

These are example URLs; configure real service URLs after implementing and testing the contract. Initialization fails visibly if live networking is not configured securely. Invalid/expired sessions clear secure storage and return to authentication; this client currently requires OTP reauthentication rather than silent refresh.

### Proposed REST contract

Paths are relative to `TRIVIA_API_URL`. JSON amounts are **integer cents**, USD initially; dates are ISO-8601 UTC. The backend must check permissions on every endpoint and serialize errors without sensitive personal data. All list views need pagination added when implementing the backend; current adapter reads the first `results`/`items` page.

| Method and path | Request / response |
|---|---|
| POST `auth/otp/request/` | `{phone}`; backend sends and rate-limits a real OTP |
| POST `auth/otp/verify/` | `{phone, code}` → `{access, refresh?, user}` |
| GET / POST `me/` | User / update `{first_name,last_name,email}` |
| POST `auth/logout/` | `{refresh}`; revoke server session |
| GET `places/?q=…` | `{results: [Place]}`; configured geocoder |
| POST `routes/quote/` | `{pickup,destination,category}` → route quote below |
| GET / POST `rides/` | `{results:[Ride]}` / create `{pickup,destination,category,currency,quote_id,fare_cents,payment_method_id,idempotency_key}` |
| GET `rides/active/` | `{ride: Ride|null}`; return assigned driver trips too |
| GET `rides/{id}/offers/` | `{results:[Offer]}` |
| POST `rides/{id}/accept/` | `{offer_id}` → authoritative Ride; atomic, idempotent assignment |
| POST `rides/{id}/status/` | `{status}` → Ride; role-based state transitions |
| POST `rides/{id}/offers/` | `{fare_cents}`; eligible approved online driver only |
| GET `driver/requirements/` | `{documents:[{key,label}]}`; applicable requirements from platform policy |
| POST `driver/application/` | multipart make, model, year, colour, registration, seats + required document files → `{status}` |
| POST `driver/availability/` | `{online}`; backend checks approval/location/service area; use server-side availability leases |
| POST `driver/location/` | `{latitude,longitude,timestamp}`; validate age, accuracy and ownership server-side |
| GET `driver/requests/` | `{results:[Ride]}` |
| GET `driver/earnings/?period=today\|week\|month` | `{gross_cents,commission_cents,net_cents,trips,payout_status}` |
| GET `payments/methods/`, `payments/history/`, `notifications/` | `{items:[{id?,name?,title?,description?}]}` |
| POST `me/preferences/` | `{trip_notifications}` |
| POST `safety/contacts/`, `safety/incidents/`, `support/tickets/` | `{message,name?}` |
| POST `rides/{id}/review/`, `rides/{id}/dispute/` | `{message,rating?}` |
| POST `me/deletion-request/` | deletion request, processed by backend retention policy |
| GET `realtime/ticket/` | `{ticket}`; short-lived single-use WebSocket credential |

`Place`: `{name,latitude,longitude}`.

`Offer`: `{id,driver_name,vehicle,registration,fare_cents,rating?,pickup_minutes?,verified}`.

`User`: `{first_name,last_name,phone,driver_status}`. Driver statuses: `draft`, `submitted`, `underReview`, `approved`, `rejected`, `suspended`. A real adapter may translate snake_case backend enum names.

`Ride`: `{id,pickup:Place,destination:Place,fare_cents,category,status,created_at,driver:Offer|null,payment_status}`. Statuses: `searching`, `assigned`, `arriving`, `arrived`, `inProgress`, `completed`, `cancelled`. Optional `route_geometry` is an array of `[longitude,latitude]` road coordinates. Optional `driver_location:Place` and `location_updated_at` drive the assigned-vehicle marker; positions older than two minutes or implausibly in the future are hidden. Agreed fare can change only as part of initial authoritative offer selection. Backend must reject invalid/duplicate transitions, concurrent selections and fare tampering.

Route quote: `{geometry:[[longitude,latitude],…],distance_metres,duration_seconds,service_available,minimum_fare_cents,suggested_fare_cents?}`. Geometry and duration must come from a road routing provider. Quote validity, geographic coverage, category capacity, minimums, currency and booking eligibility must be checked again by the backend on submission.

WebSocket client sends `{type:authenticate,ticket}`, waits for `{type:authenticated}`, then sends `{type:subscribe,channel:user}`. Heartbeats are `{type:ping}` / `{type:pong}`. Events cause a full active-ride/offers/history refresh, including after reconnect; they never directly authorize assignment or payments. Exponential retry caps at 30 seconds. Polling refreshes every 15 seconds while foregrounded. Backend must support the documented heartbeat and ticket protocol before configuring the URL.

## Maps, privacy and remaining integrations

OpenStreetMap standard tiles are used for low-volume development with visible attribution and a package user agent. For launch, configure an appropriately licensed/capacity-provisioned provider using `TRIVIA_MAP_TILES`, review its usage/privacy terms, and run real-device network tests. No offline map cache or provider SLA is supplied. Demo location search uses explicitly identified example Zimbabwean landmarks, not confirmed service areas. Geocoding for live mode is backend-fed.

Foreground GPS is requested on demand. Live drivers must grant location permission before going online. Updates are distance-filtered and stop when offline, paused or logged out. Pausing requests offline availability; the backend must expire stale availability if the request cannot reach it. No background location/dispatch implementation is claimed. Navigation deep links, driver phone/chat, production push, payment-provider checkout, tax receipts, payout transaction pagination, profile photographs and persisted saved-address management remain integration work. The current trip-sharing action shares a text summary, not a live tracking URL. No SOS dispatch is implemented.

The booking form now supports USD cash and ZiG cash, with EcoCash, OneMoney and InnBucks visible but unavailable until an authorized gateway is integrated. No card provider is assumed operational. Payment methods/history must be supplied by the backend; this version displays them and does not initiate checkout or collect card details. Enabled methods can be selected from booking and their backend ID and currency are submitted with the ride. Provider checkout and payment hand-off still require the final payment API. Notification settings are an in-app preference; no APNs/FCM device registration is implemented. Safety/support demo forms do not contact any real recipient.

## Verification

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

See [VALIDATION.md](VALIDATION.md) for the actual command outcomes and limitations. Automated tests cover critical state transitions and entry validation. Real-device GPS, tile rendering, accessibility/text scaling, live backend behavior, payment providers, push delivery and a complete live ride need a staging environment and device QA.

## Android release

Application ID: `com.mordecsolutions.trivia`. Internet and foreground coarse/fine location only. Cleartext networking and Android backup are disabled. Original launcher icon source is `tool_icons.py`; rebuild with Pillow if needed. No signing secrets are committed.

Release builds fail if signing credentials are absent; unsigned APKs cannot be installed on Android. Supply these variables through your CI secret store or a private local environment:

- `TRIVIA_KEYSTORE`: absolute path to upload keystore.
- `TRIVIA_STORE_PASSWORD`, `TRIVIA_KEY_ALIAS`, `TRIVIA_KEY_PASSWORD`.

For a local build using an existing key, run `source tool/signing-env.sh` in an
interactive Bash terminal from MobileApp. It prompts for an absolute keystore
path, alias, and hidden passwords, and exports all four variables in that same
shell without writing secrets to disk. Run the Flutter build in that shell.
Gradle does not expand a literal `~` in the keystore path. After building, run
`unset TRIVIA_KEYSTORE TRIVIA_KEY_ALIAS TRIVIA_STORE_PASSWORD TRIVIA_KEY_PASSWORD`.

Use the original signing key for updates to existing installations. A Play upload key may differ from the Play app signing key; a locally signed APK must match the installed app's signing certificate to preserve its data through an update. Never uninstall an existing app to work around a certificate mismatch without the owner's approval.

If this is the first release and no key exists, create one interactively outside the repository (password prompts keep secrets out of shell history):

```bash
mkdir -p "$HOME/.trivia-signing"
chmod 700 "$HOME/.trivia-signing"
keytool -genkeypair -v -keystore "$HOME/.trivia-signing/trivia-release.jks" \
  -alias trivia -keyalg RSA -keysize 3072 -validity 10000
chmod 600 "$HOME/.trivia-signing/trivia-release.jks"
```

Enter the verified publisher identity, MOrdec Solutions (Private) Limited, when prompted. Back up the key and credentials securely; losing them can prevent future updates. Set the four environment variables above without committing them or pasting passwords into logs/chat. Do not create a replacement key for an already released app.

Build a universal APK with `flutter build apk --release`. Verify it before transfer:

```bash
unzip -t build/app/outputs/flutter-apk/app-release.apk
"$ANDROID_HOME/build-tools/37.0.0/apksigner" verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
"$ANDROID_HOME/build-tools/37.0.0/zipalign" -c -P 16 4 build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Use the installed build-tools version if different. Confirm v2 or newer signature verification succeeds, and compare certificate fingerprints with any previously installed release. Android's launcher shows Trivia; the publisher name is configured separately in store listings and the signing certificate.

Use Play App Signing, reserve the application ID, supply production URLs and privacy/terms, and verify that **demo mode is false** for the store build. Update version/build number; test a signed build, permissions and startup on target Android devices before publishing.

## iOS release (requires macOS)

Bundle ID: `com.mordecsolutions.trivia`; minimum deployment target 15.0. Info.plist contains foreground-location and photo-library usage descriptions. No background location entitlement is added. Launcher artwork includes all existing icon-catalog sizes and the 1024px store icon. HTTPS remains required; ATS exceptions are not added.

On macOS, install compatible Flutter/Xcode/CocoaPods tooling as required by your selected Flutter native dependency manager, resolve dependencies, open Runner in Xcode, select an Apple Developer team, reserve the bundle ID and configure development/distribution certificates and provisioning profiles. Verify secure-storage Keychain access and plugin integration on a physical iPhone. Configure APNs capabilities, entitlements and device-token backend registration **only when push is implemented**. Review privacy manifests, App Privacy disclosures, store assets and transport policies.

```sh
flutter build ios --dart-define=TRIVIA_DEMO=false --dart-define=TRIVIA_API_URL=https://YOUR_API/mobile/v1
flutter build ipa --dart-define=TRIVIA_DEMO=false --dart-define=TRIVIA_API_URL=https://YOUR_API/mobile/v1
```

Archive/sign on macOS, upload through App Store Connect and test through TestFlight. **No iOS compilation or IPA signing is possible or claimed from this Linux session.**

## Reference

The passenger-proposed fare, comparison and driver-selection sequence was checked against the official [inDrive passenger guide](https://indrive.com/help/passengers/how-to-request-an-indrive-ride) and [driver guide](https://blog.indrive.com/en-ro/article/drivers-101-how-to-use-our-app). Trivia uses its own emerald/white interface, original illustration and launcher artwork, and bundled OFL-licensed Inter font.
