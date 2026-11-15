# Trivia route quotes, offers and payments

This change implements authenticated booking APIs in the existing Django `rides` and `payments` apps and connects the Flutter booking form. React, onboarding artwork, native identifiers, signing and icons are unchanged. Android's application label and both iOS display-name keys already read **Trivia**; an automated Flutter test checks those configurations. No device installation or native release build was performed for this change.

## What works

The Flutter draft resolves selected search/GPS/map-pin locations to coordinates, requests a road quote when pickup, destination, category or currency changes, displays distance/time, and fills an editable offer. The edit icon and “Suggested fare — you can change this amount” label explain the interaction. Changes to unrelated app state or payment choice preserve the typed offer. Route/category/currency changes clear the old offer, explain why if it was manually edited, and request a new suggestion. A stale asynchronous response cannot overwrite a newer route or currency. No numeric USD amount is simply relabelled as ZiG.

The form shows USD (`US$`) and Zimbabwe Gold (`ZiG`, API/storage code `ZWG`) and remembers currency preference on the device. It shows EcoCash, OneMoney, InnBucks, Cash — USD and Cash — ZiG, using neutral icons. Cash is paid directly to the driver and starts as `pending_cash`; booking never marks it paid. Mobile-money methods are visible/selectable, but requesting with an unavailable method is disabled, and the backend rejects it independently. Their supported currency lists are empty until an authorized gateway's capabilities are actually verified. Admin-enabling a row cannot enable an unimplemented gateway.

Submission is disabled for missing endpoints, an invalid/expired route quote, an invalid or out-of-bounds offer, unsupported currency, incompatible/unavailable payment, configuration failure or a request in progress. Backend-generated quotes belong to one passenger, expire, and may be used once. The passenger is locked while creating a ride; an idempotency key prevents duplicate retry bookings. Flutter keeps the same key for an uncertain retry of the same payload and creates a new key if the payload changes.

## Configure and run

From `Backend`, use the existing virtual environment and export settings (see [../.env.example](../.env.example)). `.env.example` documents variables; it is not automatically loaded. Set a real `DJANGO_SECRET_KEY`, production host names, and `DJANGO_DEBUG=false` for deployment. To use MySQL, explicitly set `DB_ENGINE=mysql` and the `DB_*` variables. The existing SQLite default is retained for local development and tests; no existing database was converted or production data migrated by this task.

```sh
.venv/bin/python manage.py migrate
.venv/bin/python manage.py createsuperuser
.venv/bin/python manage.py runserver
```

Before accepting live bookings:

1. Configure `TRIVIA_ROUTING_URL` with an HTTPS OSRM-compatible service covering the intended roads. The adapter uses the documented [OSRM driving route API](https://project-osrm.org/docs/v26.4.0/http), full GeoJSON geometry, provider distance and provider duration. There is no straight-line pricing fallback. It rejects no-route, malformed geometry, nonpositive distance/time, and excessive road snapping. `TRIVIA_GEOCODING_URL` optionally supplies a provisioned Nominatim-compatible search service. Without it, live search reports unavailability; GPS and map-pin selection remain possible. No public routing/geocoding demo endpoint is used by default.
2. In Django admin, create and explicitly enable **Pricing zones** and **Pricing configurations** for each supported category. Zones are rectangular geographic bounds; both endpoints and every returned route coordinate must be inside the selected zone. Higher priority wins if zones overlap. No operational city, coverage or commercial rate is seeded.
3. Set base fare, distance/minute rates, optional booking fee, minimum/maximum offer and currency-specific rounding increments. All monetary pricing parameters except the ZiG rounding increment are denominated in USD. Optional time adjustments use Africa/Harare local hours, including overnight windows; highest priority wins. The formula is `(base + kilometres × per_km + minutes × per_minute) × time_multiplier + booking_fee`, then conversion if needed, rounding, and minimum enforcement. Routes exceeding the maximum are rejected, not silently underpriced.
4. For ZiG, a staff verifier must create an **Exchange rate** record using a current authoritative publication such as the [RBZ rates page](https://www.rbz.co.zw/index.php/13-daily-exchange-rates/16-rates). Supply the actual USD-to-ZWG value, HTTPS source, observation time and expiry; admin records the verifier and verification time. Source host allowlisting, staff verification, freshness and expiry are enforced. Records are immutable; corrections use new records. No rate from a web search or test fixture is used as production configuration. The verified value is cached for at most five minutes, never beyond its validity window; database identity/verification/freshness is rechecked before use so revocation or a newer rate cannot be hidden by cache. Quotes and rides retain the exact rate and observation timestamp used. Missing/stale rates fail with HTTP 503 and a useful message. An updated rate invalidates an older conversion quote at booking.
5. Configure a real authentication/OTP integration that issues the same JWTs accepted by the API. The existing Flutter OTP endpoints are still provider integration work. Staging accounts can obtain JWTs through `/auth/token/`; there is no hardcoded account or production authentication shortcut. `/me/` supports an authenticated standard Django user; the current adapter uses username as the phone identifier, so the identity integration must enforce that convention or replace the adapter with the actual verified phone field.
6. Point the mobile app at the deployed API: `--dart-define=TRIVIA_DEMO=false --dart-define=TRIVIA_API_URL=https://YOUR_HOST/mobile/v1`. HTTPS termination and provider credentials belong on the backend. **Demo mode intentionally has no fabricated road quote and cannot submit a passenger booking without a valid quote.** Existing explicit developer driver-trip simulations and repository tests remain separate.

Driver dispatch, real offer acceptance, agreed-fare/payment reconciliation, mobile-money checkout/webhooks, APNs/FCM and live driver tracking still require their corresponding integrations. Creating a persisted `searching` ride is not a claim that a vehicle has been dispatched. The offers endpoint returns no offers until dispatch is implemented. No mobile-money initiation endpoint or fake payment-success response is supplied.

## Database changes

The previously empty model modules are reused. New records are:

- `rides.PricingZone`: enabled rectangular service bounds.
- `rides.PricingConfiguration`: category, USD base/per-km/per-minute/booking fee, minimum/maximum, USD/ZWG rounding, priority and update timestamp.
- `rides.TimeAdjustment`: local-hour multiplier windows and priority.
- `rides.FareQuote`: passenger, pickup/destination coordinates and labels, category, currency, actual road distance/duration/geometry/provider, pricing snapshot, suggested/minimum/maximum cents, audited exchange-rate value/timestamp, creation and expiry.
- `rides.Ride`: passenger, protected one-to-one quote reference, offered fare, nullable agreed fare, actual currency, status, idempotency key and request fingerprint. Quote fields are normalized behind a protected immutable API reference rather than duplicated or recalculated in Flutter. A driver has not agreed to the offered fare merely because a booking exists.
- `payments.PaymentMethod`: stable method code, kind, supported currency list and enabled flag.
- `payments.ExchangeRate`: verified USD/ZWG rate and its evidence, validity and verifier.
- `payments.Payment`: protected one-to-one ride reference, method, amount, currency and status.

Migrations: `rides/0001_initial`, `payments/0001_initial`, `payments/0002_initial`, `payments/0003_payment_options`. The last migration adds five method records without overwriting existing operator configuration. It seeds no pricing or exchange-rate values. The empty duplicate scaffold `tests.py` modules were removed in favour of the existing `tests/` packages to fix Django test discovery. No production migration was executed.

## API contract

All paths below are relative to `/mobile/v1/`. All booking/configuration endpoints require JWT Bearer authentication or a valid CSRF-protected Django session. Quote/search endpoints are scoped to 30 requests/minute per authenticated user. IDs are UUIDs, dates are ISO-8601, prices in API integer-cent fields use the selected currency's hundredths, and decimal amount fields are strings. Coordinates must be finite/in range and are normalized to six decimal places. The server rejects fabricated client distance/pricing: the booking references a server-created quote, not passenger-supplied route metrics.

| Endpoint | Behavior |
|---|---|
| POST `routes/quote/` | `{pickup,destination,category,currency}` → road quote, distance/metres/km, time/seconds/minutes, currency, suggestion, limits, pricing snapshot, optional rate/timestamp and expiry. |
| GET `places/?q=...` | Coordinate-backed search suggestions from configured geocoder. |
| GET `currencies/` | USD and ZWG metadata, display symbols, default USD. |
| GET `payments/methods/` | Five methods with kind, verified supported currencies, enabled/operational status and explanation. |
| GET `exchange-rates/` | Current verified USD/ZWG value, source and observation/verification/expiry timestamps, or 503. |
| POST `rides/` | Create with `{pickup,destination,category,currency,quote_id,fare_cents,payment_method_id,idempotency_key}`; 201 on first creation, 200 on identical retry. Changing a used key's payload is rejected. A second active ride is rejected even with a new key. |
| GET `rides/`, `rides/{id}/`, `rides/active/` | Passenger-owned trip records, normalized quote fields, offered/agreed/current fare, currency, selected payment name/code and actual payment status. List currently caps at 100 records; pagination remains future work. |
| POST `rides/{id}/status/` | Passenger cancellation before trip start only. No client-authoritative completion, assignment or payment status changes. |
| GET `rides/{id}/offers/` | Owned ride check; returns an empty list until real dispatch integration exists. |
| GET `payments/history/` | Passenger-owned records with method, amount, currency and status; never a fabricated successful transaction. |
| GET/POST `me/` | Authenticated profile read/update needed by the existing Flutter session restoration. |
| POST `auth/token/`, `auth/token/refresh/` | Standard existing-account SimpleJWT authentication; real OTP delivery is separate. |

A `Place` is `{name, latitude, longitude}`. Categories are `Standard`, `Comfort`, `XL`. Quotes include `id`, `geometry: [[longitude,latitude],...]`, `distance_metres`, `duration_seconds`, `suggested_fare_cents`, `minimum_fare_cents`, `maximum_fare_cents`, `currency`, `pricing_configuration`, `exchange_rate`, `exchange_rate_timestamp`, `expires_at` and `service_available`. Use stable payment IDs `cash-usd`, `cash-zwg`, `ecocash`, `onemoney`, `innbucks`. Mobile-money IDs are not operational in the current implementation.

## Verification

```sh
# Backend
.venv/bin/python manage.py check
.venv/bin/python manage.py makemigrations --check --dry-run
.venv/bin/python manage.py test rides payments --noinput
# MobileApp
flutter pub get
flutter analyze
flutter test
```

Django tests use a separate SQLite test database and explicit deterministic road/rate fixtures; they never hit live providers or alter production data. They cover formula/rounding, time adjustment/fee, conversion and audit data, missing/stale/unverified/untrusted rates, route/provider failures, coverage, limits, tampering, quote expiry, changed pricing, authentication/ownership, unpaid cash, gateway unavailability, cancellation and duplicate request keys. MySQL concurrency under load and end-to-end live provider/OTP/payment/device testing still need a provisioned staging environment. Native labels are checked from platform configuration, not by claiming a new installation was tested.
