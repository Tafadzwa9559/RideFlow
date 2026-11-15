# Existing project audit

Audit performed before implementation, 15 November 2026.

- `MobileApp` already contained Android and iOS projects. No project regeneration was needed.
- `lib/main.dart` was the only Dart source. It contained RideFlow branding, pickup/destination text fields, three ride choices and a preview dialog. Other navigation destinations showed “coming soon”. There were no models, routing, state providers, services, repositories or assets.
- `test/widget_test.dart` referenced the nonexistent starter `MyApp` counter and could not test the existing app.
- Existing dependencies included Riverpod, Dio, secure storage, preferences, Geolocator and Intl. These were retained. Unused GoRouter and Cupertino Icons were removed; imperative Navigator routes and one Riverpod-provided controller keep navigation/state consistent without a second state-management framework.
- Maps, coordinates, WebSockets, document-photo selection, native link opening and native sharing added only the packages needed for those features. The sharing package version was adjusted to resolve the secure-storage dependency’s Win32 version requirement.
- Existing SDK constraint is Dart 3.13.2. Installed underlying SDK reports Flutter 3.47.2 / Dart 3.13.2. The Snap launcher cannot run in the session; commands use the underlying Flutter SDK executable with permission to update tool caches.
- Native platform files were present. Android used the template display name and debug release signing; iOS used the template display name and store bundle ID. Both had Flutter template launcher artwork and no location permission descriptions. These were reviewed and updated in place.
- iOS already uses Flutter’s Swift Package Manager integration and a 15.0 deployment target. A separate CocoaPods scaffold was not generated over that configuration.
- Android SDK platform 36, required by this Flutter SDK, was missing and was installed during validation. Existing Gradle memory defaults exceeded the machine’s practical capacity; heap and worker limits were reduced for build stability.
- Backend API modules were inspected read-only. The mobile endpoint files were empty and the main URL configuration only registered Django admin. The mobile API adapter is therefore a documented proposed contract, not a verified live integration.
- No `Backend` or `WebApp` files were edited.

The replacement is feature-organized under `app`, `core`, `features` and `shared`. Demo and API repositories share one interface. The demo uses explicit labels and manual trip progression; it never sends a dispatch or payment request.
