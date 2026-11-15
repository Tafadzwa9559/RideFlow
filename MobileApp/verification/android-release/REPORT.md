# Trivia Android installation investigation

## Follow-up signing setup

Rechecked the configuration following the missing-credentials build report.
No TRIVIA signing variables are available. No key was found in the project,
`.android`, or Documents/Downloads (the latter searched to depth five).
No signing file is tracked in Git. No new key was generated.

Added `tool/signing-env.sh`, an interactive Bash helper to source in the build
shell. It loads an existing key path, alias and hidden passwords into the four
environment variables without persisting secrets. `bash -n` and diff whitespace
checks passed. README documents its use. Existing ignore rules are sufficient.

Installed Flutter's `gradle_utils.dart` confirms the project's Gradle 9.3.1,
AGP 9.1.0, Kotlin 2.4.0, compile/target SDK 36 and minimum SDK 24 match its
template defaults. No version or dependency changes were needed to address the
missing signing inputs. Native-access, newer-package and SDK XML warnings were
not the terminating error in the recorded build.

ADB was rechecked: no devices connected. No release APK exists at the expected
output path. Rebuilding/signature verification remains dependent on an existing
key or explicit approval to create a first-release key. The clean/get/analyze
and failed release results below are from the preceding investigation; they
were not repeated for this documentation/helper-only follow-up.

## Confirmed cause in the supplied artifact

The existing `build/app/outputs/flutter-apk/app-release.apk` was unsigned.
Android build-tools 37.0.0 `apksigner verify --verbose --print-certs` exited 1:

```text
DOES NOT VERIFY
ERROR: Missing META-INF/MANIFEST.MF
```

The original Gradle release configuration explicitly selected `null` signing when
`TRIVIA_KEYSTORE` was absent. No TRIVIA signing environment variables were set.
This produces a ZIP/APK that can pass integrity checks but cannot be installed.
The phone's exact installation error code was not captured: no ADB device is
connected. Other device-specific failures cannot be excluded until installation.
The original artifact's SHA-256 is recorded in `original-apk.sha256`.

## Inspection and original artifact validation

Reviewed app/root/settings Gradle Kotlin files, Gradle properties/wrapper,
main/debug/profile manifests, MainActivity, pubspec, local SDK paths, signing
ignore rules, and existing release documentation.

- Application ID: `com.mordecsolutions.trivia` (preserved).
- Launcher label: `Trivia` (preserved).
- MainActivity: `com.mordecsolutions.rideflow_mobile.MainActivity`; matches the
  source namespace. The namespace need not equal the application ID.
- Version: `1.0.0`, code `1` (preserved; existing device version unknown).
- Minimum SDK: 24 (Android 7.0); target/compile SDK: 36 (preserved).
- Native ABIs: arm64-v8a, armeabi-v7a, x86_64; no custom ABI restrictions found.
- `unzip -t`: passed, no compressed-data errors.
- `zipalign -c -P 16 4`: exited 0 (passed).
- `aapt dump badging`: parsed successfully, including launcher activity.
- No conflicting launcher/manifest declarations identified in the inspected files.
- Native libraries are present; runtime plugin behavior remains untested.
- No tracked `.jks`, `.keystore`, or `key.properties` found. Ignore rules cover
  these files. No release key found in the project or local `.android` directory.

## Changes

Only signing configuration, release documentation, and these investigation
records were changed for this task. Existing unrelated work was preserved.

- `android/app/build.gradle.kts`: always selects production signing for release;
  explicitly enables v2/v3; fails release task graphs with missing credentials or
  a nonexistent keystore instead of emitting unsigned release artifacts.
- `README.md`: secure first-release key creation, existing-key update requirement,
  signing environment variables, validation commands, and publisher identity.
- Existing ignore rules already exclude signing material; no keys generated.
- No UI, business logic, identity, SDK, dependency, or ABI changes made.

## Environment and verification

- Flutter 3.47.2 stable; Dart 3.13.2.
- Gradle wrapper 9.3.1; Android Gradle plugin 9.1.0; Kotlin declaration 2.4.0.
- Java used by Flutter: Android Studio JBR 25.0.4. Shell Java: OpenJDK 17.0.21.
  Android Java/Kotlin bytecode target remains 17.
- SDK installed: 37.0; build-tools 36.0.0 and 37.0.0 available.
- `flutter doctor -v`: completed; warns of some unaccepted Android SDK licenses.
  Snap launcher could not run in this environment; commands used the SDK's
  absolute `bin/flutter` path with cache access.
- `flutter clean`: passed; removed the previous unsigned build output.
- `flutter pub get`: passed.
- `flutter analyze`: passed, no issues found.
- `flutter build apk --release`: attempted after clean; Gradle compiled the
  updated build script and failed at the intentional credential check (exit 1,
  approximately 121 seconds):

  ```text
  Release signing credentials missing: TRIVIA_KEYSTORE, TRIVIA_STORE_PASSWORD,
  TRIVIA_KEY_ALIAS, TRIVIA_KEY_PASSWORD.
  ```

  This verifies the unsigned-release prevention, not a completed APK build.
  The build also warned about SDK XML version 4 versus tooling support for 3;
  this was not the terminating error. No SDK downgrade was made.
- `adb devices`: succeeded with an empty device list. Samsung/physical Android
  installation and installed signing-certificate comparison remain unverified.

## Required release inputs

Provide the existing release keystore and securely configured `TRIVIA_KEYSTORE`,
`TRIVIA_STORE_PASSWORD`, `TRIVIA_KEY_ALIAS`, and `TRIVIA_KEY_PASSWORD`. If no key
exists and this is the first release, use the interactive procedure in README.
Never replace an established signing identity without investigating update
compatibility. Do not uninstall or clear app data to bypass an update failure.

The intended final output is
`MobileApp/build/app/outputs/flutter-apk/app-release.apk`. A signed final artifact
has not been produced or verified. After credentials are supplied, rebuild and
repeat ZIP integrity, badging, signature, ABI, alignment, and physical install
checks against the new artifact.
