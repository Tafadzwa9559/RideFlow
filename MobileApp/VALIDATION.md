# Validation record — 15 November 2026

| Check | Result |
|---|---|
| `flutter pub get` | Passed; compatible dependency versions resolved and lockfile updated. |
| `flutter analyze --no-pub` | Passed: **No issues found**. |
| `flutter test --no-pub` | Passed: **11 tests**. |
| Dart formatting | Passed; application and tests formatted. |
| Android manifest XML | Parsed successfully; Trivia label, internet/foreground location, no background location, backup disabled and cleartext disabled. |
| iOS Info.plist and icon catalog | Parsed/checked successfully; Trivia display name, foreground location/photo-library descriptions, all catalog images exist. This is configuration validation, not an Xcode build. |
| Android APK release | Attempted repeatedly; the build sessions were interrupted before Gradle returned a final result. No APK artifact was found. Release compilation remains unverified. |
| Android App Bundle release | Attempted; interrupted before a final result. No successful AAB is claimed. |
| iOS build / IPA signing | Not run: macOS/Xcode unavailable in this Linux environment. |
| Live ride / live OTP / payment / push | Not run: backend mobile endpoints and provider integrations are unavailable. |

The installed Flutter Snap launcher cannot start in the managed shell. Commands used the installed underlying executable `/home/taflowork/snap/flutter/common/flutter/bin/flutter` with access to its SDK cache. Android SDK platform 36 was missing and was installed; Gradle also installed platform 35 and CMake 3.22.1 for dependencies. Gradle heap/workers were reduced from the template defaults to fit this machine. Native builds were interrupted in earlier sessions; their partial output is not evidence of successful compilation.

The passing suite covers exact-cent fare parsing, invalid OTP rejection, approved-driver gating, invalid trip transitions, concurrent/duplicate offer selection, agreed fare immutability, passenger/driver switching, logout cleanup including an offline-network failure, driver counteroffer/selection simulation, active-trip preservation when offline, simulated earnings from completed driver trips, backend road-quote parsing, persisted onboarding completion, phone-entry validation and passenger layout at 320×640 with 1.5× text scaling. Flutter widget tests intentionally do not make real tile-network requests.

The final map-attribution adjustment was included in the passing analysis and 11-test run. Final tool output is retained in [verification/trivia-analysis-final.txt](verification/trivia-analysis-final.txt) and [verification/trivia-tests-final.txt](verification/trivia-tests-final.txt).

Required before launch: implement and verify the proposed backend contract, signed Android builds, physical Android/iPhone QA, production map/geocoding/routing/pricing services, payment checkout and reconciliation, APNs/FCM configuration, privacy/terms URLs, operational safety/support processes, secure document policy, Apple signing, TestFlight, App Store/Play review and a real staging ride. Do not publish a demo-mode artifact as the operational service.
