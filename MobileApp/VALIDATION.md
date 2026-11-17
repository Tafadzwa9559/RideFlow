# Mobile validation — 17 November 2026

Checks apply only to `MobileApp`. No production OTP, ride, payment, upload or
user mutation was performed. All test records are synthetic.

## Baseline

An unchanged copy of the tracked mobile application was extracted from `HEAD`
into `/tmp/mobile-cleanup-baseline/MobileApp` for comparison.

- Analyzer: two existing `curly_braces_in_flow_control_structures` findings in
  `test/api_repository_test.dart`, lines 203 and 209. Both are fixed in this cleanup.
- The initial baseline test process was interrupted before completion. After
  cleanup, all 48 existing tests and the new registration test passed.
- The normal Snap Flutter launcher could not start in this shell. The underlying
  installed SDK required cache access outside the workspace; checks used that SDK
  with approved access. This is an environment limitation, not an application error.

## Cleanup verification

| Check | Result |
|---|---|
| Dart formatting | Passed: 32 application/test files, no further changes required |
| Existing tests after initial refactor | Passed: 48 tests |
| Final analyzer | Passed: no issues found |
| Final suite including registration flow | Passed: 49 tests, run with `--concurrency=1` |
| Android debug APK | Attempted; sessions interrupted during `assembleDebug` before a final result. Compilation remains unverified |
| Tracked XML, plist and JSON | Parsed successfully |
| iOS asset catalogs | Referenced images exist |
| Onboarding asset references | All bundled images referenced by the entry screen |
| Signing helper | `bash -n tool/signing-env.sh` passed |
| Diff whitespace | `git diff --check` passed |
| AI attribution scan | No irrelevant references found in tracked mobile files |

The registration flow test exercises local edits, explicit submission, payload
preservation and confirmed submitted status. Existing contract, fare, session,
driver gating, booking, branding, onboarding and layout tests remain in place.

## Limits

The Android build attempts did not return a final compiler result. Gradle emitted
a Java native-access warning; no terminating application build error was captured.
No new debug APK was produced. The existing release APK predates this cleanup.

Android release signing and physical-device installation were not run. The current Gradle configuration permits debug-key fallback for
release builds; check the signing certificate before distribution. No signing
policy or credentials were changed during cleanup.

iOS compilation and signing require macOS/Xcode and were not run. Staging and
device acceptance are still required for SMS, secure storage, location,
notification reconnects, document uploads and complete passenger/driver trips.
Earlier raw validation output remains under `verification/`; it records previous
revisions rather than the results of this cleanup.
