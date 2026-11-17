# Trivia mobile

**Your Journey. Your Choice.** MOrdec Solutions (Private) Limited.

The existing Flutter screens, navigation, branding and assets are retained. Application data uses the deployed HTTPS backend through Dio; there is no runtime demo repository, fake OTP, driver simulation or fictional fare fallback. Deterministic synthetic fixtures exist only under test/ and are not imported by lib/.

## Run

Flutter 3.47.2 / Dart 3.13.2 were available for this integration.

```bash
flutter pub get
flutter run --dart-define=TRIVIA_API_BASE_URL=https://trivia-backend-bze2.onrender.com
```

That origin is the default. The client appends `/api/v1/`; supply an origin, not a duplicate API path. Overrides must use HTTPS. Privacy/terms and licensed map tiles remain configurable using TRIVIA_PRIVACY_URL, TRIVIA_TERMS_URL and TRIVIA_MAP_TILES. Prior TRIVIA_DEMO/TRIVIA_API_URL/TRIVIA_WS_URL settings are removed; no flag can enable simulated application data.

## Data and contracts

- OTP endpoints issue real JWTs; platform secure storage retains access/refresh tokens. Concurrent expired requests share a rotating refresh attempt. Revoked sessions clear credentials, while network failures preserve the session for retry. Logout uses the backend's all-session invalidation.
- Quotes, road geometry, USD fare limits, payment options, requests, offers, history, availability and earnings come from documented APIs. No route/fare is invented when providers fail. Cash/EcoCash/OneMoney are offline preferences; no gateway, digital payment verification, commission or payout is invented.
- Driver onboarding uses real requirements, application drafts, scoped multipart images/expiry dates and submit confirmation. Only administrator-approved backend status enables driver operation. Partial form entries remain screen-local until submission and are not falsely presented as saved to the backend.
- Actual GPS requires foreground permission. Uploads are limited to at least three seconds apart; a 30-second heartbeat acquires fresh device positions while online. Map fallback center is a viewport, never a location fix or driver. Old/missing trip coordinates are hidden.
- Native authenticated WSS uses `/ws/v1/notifications/`, first frame `{token: accessJWT}`, `connection.ready`, ping/pong and REST reconciliation on events/reconnect. No ticket endpoint or subscribe payload is invented. Foreground polling provides resync fallback.
- History/notifications have load-more support and empty/error/retry states. Saved places and preferences use owner APIs. Account deletion is disabled because no documented endpoint exists. Assigned driver summary after app restart requires an additional backend response field; unavailable details are never fabricated.

[MOCK_DATA_AUDIT.md](MOCK_DATA_AUDIT.md), [API_INTEGRATION_MATRIX.md](API_INTEGRATION_MATRIX.md), [MISSING_API_ENDPOINTS.md](MISSING_API_ENDPOINTS.md), [INTEGRATION_REPORT.md](INTEGRATION_REPORT.md).

The live OpenAPI URL redirects to staff login; the checked-in Backend/docs/openapi.yaml and actual Django handlers are the integration contract used here. Deployed parity is unverified. Read-only checks found `/health/` 200, `/ready/` 503 and unauthenticated `/api/v1/users/me/` 401. No production OTPs, rides or user records were created to test this change.

## Validation

```bash
flutter analyze
flutter test
flutter build apk --release
```

See INTEGRATION_REPORT.md for actual results. Client tests use isolated fixtures/HTTP adapters, not production credentials. Live OTP, GPS, native WSS, multipart uploads, complete passenger/driver trips, provider delivery and device storage require staging accounts and real-device acceptance. OpenStreetMap tiles retain attribution/user agent; configure a licensed provider appropriate to production traffic.

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

Use Play App Signing, reserve the application ID, supply production URLs and privacy/terms, and verify the production API origin for the store build. Update version/build number; test a signed build, permissions and startup on target Android devices before publishing.

## iOS release (requires macOS)

Bundle ID: `com.mordecsolutions.trivia`; minimum deployment target 15.0. Info.plist contains foreground-location and photo-library usage descriptions. No background location entitlement is added. Launcher artwork includes all existing icon-catalog sizes and the 1024px store icon. HTTPS remains required; ATS exceptions are not added.

On macOS, install compatible Flutter/Xcode/CocoaPods tooling as required by your selected Flutter native dependency manager, resolve dependencies, open Runner in Xcode, select an Apple Developer team, reserve the bundle ID and configure development/distribution certificates and provisioning profiles. Verify secure-storage Keychain access and plugin integration on a physical iPhone. Configure APNs capabilities, entitlements and device-token backend registration **only when push is implemented**. Review privacy manifests, App Privacy disclosures, store assets and transport policies.

```sh
flutter build ios --dart-define=TRIVIA_API_BASE_URL=https://trivia-backend-bze2.onrender.com
flutter build ipa --dart-define=TRIVIA_API_BASE_URL=https://trivia-backend-bze2.onrender.com
```

Archive/sign on macOS, upload through App Store Connect and test through TestFlight. **No iOS compilation or IPA signing is possible or claimed from this Linux session.**
