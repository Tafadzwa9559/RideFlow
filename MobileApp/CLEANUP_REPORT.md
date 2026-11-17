# Mobile code cleanup

Scope: `MobileApp` only, 17 November 2026. Backend and web application source,
API contracts, authentication, payment rules and database schemas are unchanged.

## Audit findings

The tracked mobile tree was reviewed for source structure, dependency/asset
references, documentation, platform configuration, tests and development clutter.
No irrelevant ChatGPT, OpenAI, GPT, Copilot or generated-code attribution text
was found. License text, map attribution and generated platform registrants were
retained.

The main cleanup opportunities were obsolete registration-draft code, no-op save
callbacks, unreachable driver UI branches, duplicated coordinate decoding, a large
account screen file, template comments and stale operational documentation. Package/web metadata also
contained generic project descriptions.

## Changes

- Removed restoration from an always-empty registration map and no-op draft saves.
  Local field/document state and the submitted payload are preserved. The single
  network submission method is now named `submitApplication`.
- Reused document-expiry controllers when requirements are loaded again, avoiding
  replacement of undisposed controllers and preserving local expiry edits.
- Removed unused date-of-birth branches: no such field exists in registration.
- Removed driver branches already excluded by the approved-driver guard, the
  wrapper reachable only from those branches, and a write-only offer map.
- Removed uncalled generic repository update/delete methods after searching both
  application and test references. Active endpoint mappings remain unchanged.
- Consolidated longitude/latitude geometry decoding for rides and quotes.
- Split account screens into `history.dart`, `resource.dart`, `support.dart` and
  `settings.dart`. `account.dart` exports those classes for existing consumers.
- Ordered source imports, fixed two existing test lints, replaced generic
  package/web descriptions, and removed unused analyzer-template prose and
  platform-template comments.
- Rewrote setup/architecture guidance, documented the existing debug-signing
  fallback accurately, and marked previous integration/build reports historical.
- Removed the empty root `.gitkeep`. Retained test fixtures, verification records,
  icon-generation tooling, launcher assets, platform scaffolding and configuration.
  Their build, test or maintenance roles remain useful.

No dependencies, credentials, signing behavior, branding, navigation, screen
text or API request/response fields were changed.

## Verification

Baseline and final results are recorded in [VALIDATION.md](VALIDATION.md).
The added registration widget test checks local editing followed by one confirmed
submission and the resulting submitted state. Existing tests are retained. Formatting and analysis pass, and all 49 tests pass.
Android debug build attempts were interrupted before completion; native
compilation, release signing and device acceptance remain unverified.
