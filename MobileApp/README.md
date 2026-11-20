# Trivia mobile

Flutter passenger and driver application for Trivia, maintained by MOrdec
Solutions (Private) Limited. The Dart package name remains `rideflow_mobile`.

## Setup

Use Flutter with Dart compatible with the `^3.13.2` SDK constraint in
`pubspec.yaml`. The previous integration used Flutter 3.47.2 / Dart 3.13.2.
Keep `pubspec.lock` under version control for reproducible dependency resolution.

```bash
cd MobileApp
flutter pub get
flutter run
```

The default backend origin is `https://trivia-backend-bze2.onrender.com`.
To use another deployment:

```bash
flutter run --dart-define=TRIVIA_API_BASE_URL=https://your-backend.example
```

Normal builds require an HTTPS origin, with no credentials, query, fragment or API path.
The client appends `/api/v1/` and derives the WSS notification URL from the origin.

| Build setting | Purpose | Default |
|---|---|---|
| `TRIVIA_API_BASE_URL` | Backend origin (HTTPS in normal builds) | Deployed Trivia origin above |
| `TRIVIA_DEVELOPMENT_BUILD` | Opt in to local origins in debug mode | `false` |
| `TRIVIA_MAP_TILES` | Tile URL template | OpenStreetMap standard tiles |
| `TRIVIA_PRIVACY_URL` | HTTPS privacy policy URL | Unconfigured |
| `TRIVIA_TERMS_URL` | HTTPS terms URL | Unconfigured |

Configure policy URLs and a map provider appropriate for production traffic.
Keep map attribution visible. Do not place backend secrets in Dart defines.

## Source layout

| Directory | Responsibility |
|---|---|
| `lib/app/` | Application shell, shared controller and theme |
| `lib/core/` | Configuration, HTTP repository, realtime updates, errors and map widget |
| `lib/features/entry/` | Onboarding, OTP sign-in and profile setup |
| `lib/features/passenger/` | Location selection, booking draft and trip presentation |
| `lib/features/driver/` | Registration, document selection, requests and earnings |
| `lib/features/account/` | Account, history/receipts, resource lists, support and settings |
| `lib/shared/` | Domain models, formatting and reusable widgets |
| `test/` | Contract, controller and widget tests; synthetic fixtures in `support/` |
| `tool/` | Local signing environment helper |

`AppController` coordinates session and trip state through `TriviaRepository`.
`ApiRepository` implements the backend contract with Dio and platform secure
storage. Riverpod provides the shared controller; screens use Flutter navigation
and listen to controller updates. Keep fixture repositories inside `test/`.

## Integration behavior

Authentication uses OTP and server-issued JWTs with rotating refresh tokens.
Quotes, fare limits, booking methods, offers, trip state, driver requirements
and earnings come from the backend. Driver operation requires backend approval.
Registration entries and selected documents remain on the current screen until
submission; they are not durable partial drafts.

Passengers pay drivers directly in USD using cash, EcoCash or OneMoney.
The application does not collect or verify funds. Earnings represent completed
trip fares rather than verified receipts or payouts.

Realtime notifications use first-frame JWT authentication at
`/ws/v1/notifications/`, heartbeat/reconnect and REST reconciliation. Foreground
polling provides a fallback. Driver location uses foreground device permissions,
fresh fixes and throttled uploads. A default map center is only a viewport.

The local contract is documented in [the backend OpenAPI file](../Backend/docs/openapi.yaml)
and [the integration matrix](API_INTEGRATION_MATRIX.md). Code wiring does not
establish deployed parity. See [known API gaps](MISSING_API_ENDPOINTS.md).

## Development checks

Run from `MobileApp`:

```bash
dart format lib test
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Tests use isolated fixtures and HTTP adapters. Validate real SMS, native secure
storage, document uploads, GPS, WSS reconnects and complete trips on staging
accounts and physical devices. See [current validation](VALIDATION.md) and
[cleanup details](CLEANUP_REPORT.md). Earlier integration and Android artifact
investigations are historical records, not current build guarantees.

## Android release

Application ID: `com.mordecsolutions.trivia`. Internet and foreground coarse/fine location only. Cleartext networking and Android backup are disabled. Original launcher icon source is `tool_icons.py`; rebuild with Pillow if needed. No signing secrets are committed.

The current Gradle configuration uses the local debug keystore when production signing credentials are absent. That APK is suitable for local testing only. For distribution, supply all four variables through your CI secret store or a private local environment:

- `TRIVIA_KEYSTORE`: absolute path to upload keystore.
- `TRIVIA_STORE_PASSWORD`, `TRIVIA_KEY_ALIAS`, `TRIVIA_KEY_PASSWORD`.

Partial signing configuration fails validation. Verify that `TRIVIA_KEYSTORE` points to an existing file; a missing file currently falls back to debug signing. Check the resulting certificate before distributing a release.

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

Use Play App Signing, reserve the application ID, supply production URLs and privacy/terms, and verify the production API origin for the store build. Update version/build number; test a signed build, permissions and startup on target Android devices before publishing.

## iOS release (requires macOS)

Bundle ID: `com.mordecsolutions.trivia`; minimum deployment target 15.0. Info.plist contains foreground-location and photo-library usage descriptions. No background location entitlement is added. Launcher artwork includes all existing icon-catalog sizes and the 1024px store icon. HTTPS remains required; ATS exceptions are not added.

On macOS, install compatible Flutter/Xcode/CocoaPods tooling as required by your selected Flutter native dependency manager, resolve dependencies, open Runner in Xcode, select an Apple Developer team, reserve the bundle ID and configure development/distribution certificates and provisioning profiles. Verify secure-storage Keychain access and plugin integration on a physical iPhone. Configure APNs capabilities, entitlements and device-token backend registration **only when push is implemented**. Review privacy manifests, App Privacy disclosures, store assets and transport policies.

```sh
flutter build ios --dart-define=TRIVIA_API_BASE_URL=https://trivia-backend-bze2.onrender.com
flutter build ipa --dart-define=TRIVIA_API_BASE_URL=https://trivia-backend-bze2.onrender.com
```

Archive/sign on macOS, upload through App Store Connect and test through TestFlight. iOS compilation and signing require macOS and Xcode.

## Local development authentication

Use [the isolated backend OTP setup](../Backend/docs/development-otp.md), then run
`bash tool/run-development.sh` from `MobileApp`. Only opted-in debug builds can
use a local HTTP origin. The login/OTP screens and real API workflow are unchanged;
normal builds continue using the public HTTPS origin.

The shared `TriviaMap` uses raster tiles across Flutter platforms. OpenFreeMap's
[public styles](https://openfreemap.org/quick_start/) require a vector renderer.
For a production raster service, set `TRIVIA_MAP_TILES` to a licensed HTTPS
XYZ template and set `TRIVIA_MAP_TILE_ATTRIBUTION` and
`TRIVIA_MAP_TILE_ATTRIBUTION_URL` to the provider’s required credit. The default follows the [OSM standard tile policy](https://operations.osmfoundation.org/policies/tiles/)
and is subject to its capacity and availability. Flutter web GPS requires HTTPS
(or localhost) and browser permission.
