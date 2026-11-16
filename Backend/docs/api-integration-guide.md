# Trivia REST integration guide

Trivia — Your Journey. Your Choice. Developed by MOrdec Solutions (Private) Limited for Zimbabwe.

## Setup and documentation

Use Python 3.12 and the pinned `requirements.txt`. MySQL is the default and production database; SQLite is confined to explicit test settings. Provision MySQL and Redis, copy `.env.example` to `.env`, fill generated secrets and real connection values, and export the values before native commands. Django does not automatically load `.env`; Docker Compose does.

```sh
cd Backend
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
set -a
. ./.env
set +a
.venv/bin/python manage.py migrate
.venv/bin/python manage.py createsuperuser
.venv/bin/daphne -b 127.0.0.1 -p 8000 rideflow.asgi:application
# In separate terminals with the same exported environment:
.venv/bin/celery -A rideflow worker --loglevel=INFO
.venv/bin/celery -A rideflow beat --loglevel=INFO --schedule=/tmp/trivia-beat
```

`docker compose up --build` provides MySQL, Redis, migration job, Daphne, worker and one Beat scheduler. Full environment, storage and production configuration are described in [the backend README](../README.md). No provider credentials, operational cities or commercial fare rates are seeded. Configure explicit enabled service areas/pricing and driver/vehicle document requirements first. Phone OTP requires `SMS_PROVIDER`; routing/geocoding require licensed HTTPS OSRM/Nominatim-compatible services. An unconfigured provider fails instead of inventing data.

| Documentation | Local URL |
|---|---|
| Swagger UI | `http://localhost:8000/api/docs/` |
| ReDoc | `http://localhost:8000/api/redoc/` |
| OpenAPI | `http://localhost:8000/api/schema/` |
| WebSocket protocol | `http://localhost:8000/api/websockets/` |

All four routes require a staff account. For browser navigation, sign in to Django admin first; its CSRF-protected session permits opening the documentation. Then use Swagger **Authorize** with a separately obtained JWT access token to test that account's permitted APIs. Opening Swagger grants no extra privileges. JWT tokens are never hardcoded or persisted by Swagger UI configuration. The exported [OpenAPI artifact](openapi.yaml) contains typed schemas, operation names/tags, examples, filters, status codes, JWT security and role descriptions. [WebSocket protocol and events](websockets.md) are separate from HTTP OpenAPI.

## Identity and profiles

Passengers and drivers share one account. Normalize phones to E.164; Zimbabwe is the default region (`0771234567` → `+263771234567`). Request/verify/resend OTP through `auth/otp/request/`, `auth/otp/verify/`, `auth/otp/resend/`. OTPs expire in five minutes, have five attempts, a 60-second resend cooldown and per-IP throttles. Development codes are available only in the explicitly enabled local provider's process memory, never REST or logs.

Set `Authorization: Bearer ACCESS_TOKEN` for authenticated APIs. Refresh through `auth/token/refresh/`; persist the rotated refresh token and discard the old one. Both logout and logout-all retain the established security behavior of revoking every session for the phone account and removing registered devices. A phone identity's revoked access tokens fail immediately. GET `auth/me/` or `users/me/`; PATCH `users/me/` updates names/email. Phone identity changes require fresh OTP and are not an arbitrary profile field.

`users/me/preferences/` stores `language` (`en`, `sn`, `nd`), push/marketing flags and trip-sharing permission. Disabling push suppresses the optional push adapter; disabling trip sharing blocks new grants. Language is a preference, not a claim that all response messages have been translated. Avatar uploads use multipart `file`, decoded JPEG/PNG only, up to 5 MiB/25 million pixels. Avatar GET is private and uncached; DELETE removes the active reference. Old blobs follow operator retention policy.

Saved places and emergency contacts are owned paginated resources under `users/me/`. Their detail GET/PATCH/DELETE enforce ownership. Contacts normalize E.164 phones. No emergency-services dispatch is connected.

## Driver onboarding and vehicles

POST `drivers/applications/` starts/saves a draft; GET/PATCH `drivers/applications/me/` resumes it. Existing model enum values remain `draft`, `submitted`, `underReview`, `approved`, `rejected`, `suspended`; no registration is `notRegistered`. Uppercase status labels from the requirements are presentation concepts, not a second set of wire enums.

Supply legal/licence details and a vehicle, then upload configured driver documents as multipart `requirement,file,expires_on?`. GET the document collection or private attachment; DELETE documents only in draft. POST `submit/`. Staff with `drivers.review_driver` review applications through approve/reject/request-changes actions. Rejection/change reasons appear in the applicant's paginated review history. Self approval is prohibited. Submission never grants operational eligibility.

`drivers/me/profile/` is a private verification profile. Revising an approved profile before an active assignment returns it to draft/offline and requires a fresh review. Profile changes during an assigned trip are rejected. General account names/email can be updated independently through `users/me/`.

Multiple vehicles are supported under `drivers/me/vehicles/`. A migration preserves each existing driver's selected vehicle. New/edited vehicles are unapproved; edits invalidate approval and take an affected active vehicle offline. Vehicle documents have separate configured `scope=vehicle`, private attachments and review requirements. Activate only an approved owned vehicle on an approved account. Activation takes the driver offline until fresh location/eligibility checks pass. A pending offer belongs to its original vehicle: selection fails if the driver switched vehicles. DELETE archives vehicles and preserves historical trip/offer foreign keys. Vehicles cannot be edited, archived or switched during an active assignment.

Publish `drivers/me/location/` with decimal coordinates, then POST `go-online/`. Driver approval, active approved vehicle, licence/doc validity, no active conflicting assignment and location freshness are checked. GET availability/current-trip/request lists and details. Pending/suspended/unapproved drivers cannot operate. Location updates are rate limited and never accept another user's identity.

## Example passenger and driver journey

All values below are illustrative development inputs, not live route estimates or approved market prices. Use real provider responses and operator-enabled coverage. `ACCESS_TOKEN`, `QUOTE_UUID`, `RIDE_UUID`, `OFFER_ID` and `BOOKING_UUID` are placeholders. Reuse the same booking UUID and unchanged body on a network retry.

```sh
# Request OTP; verification code is supplied through the configured SMS provider.
curl -X POST http://localhost:8000/api/v1/auth/otp/request/ \
  -H 'Content-Type: application/json' -d '{"phone":"+263771234567"}'
curl -X POST http://localhost:8000/api/v1/auth/otp/verify/ \
  -H 'Content-Type: application/json' -d '{"phone":"+263771234567","code":"CODE_FROM_SMS"}'

# Road quote and suggested fare (server supplies quote ID, limits and expiry).
curl -X POST http://localhost:8000/api/v1/fares/estimate/ \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' \
  -d '{"pickup":{"name":"Harare CBD","latitude":-17.8292,"longitude":31.0522},"destination":{"name":"Borrowdale","latitude":-17.765,"longitude":31.08},"category":"Standard","currency":"USD"}'

# Passenger adjusts fare within the returned limits and chooses a direct-payment method.
curl -X POST http://localhost:8000/api/v1/rides/ \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' \
  -d '{"quote_id":"QUOTE_UUID","idempotency_key":"BOOKING_UUID","pickup":{"name":"Harare CBD","latitude":-17.8292,"longitude":31.0522},"destination":{"name":"Borrowdale","latitude":-17.765,"longitude":31.08},"category":"Standard","currency":"USD","fare_cents":800,"payment_method_id":"ecocash","payment_preference":"ecocash","passenger_note":"Please call at the entrance."}'

# Eligible driver uses their own JWT, never a client-supplied driver ID.
curl -X POST http://localhost:8000/api/v1/rides/RIDE_UUID/offers/ \
  -H 'Authorization: Bearer DRIVER_ACCESS_TOKEN' -H 'Content-Type: application/json' \
  -d '{"decision":"counteroffer","fare_cents":900,"pickup_minutes":8}'

# Passenger compares offers and explicitly selects one.
curl http://localhost:8000/api/v1/rides/RIDE_UUID/offers/ -H 'Authorization: Bearer ACCESS_TOKEN'
curl -X POST http://localhost:8000/api/v1/rides/RIDE_UUID/select-offer/ \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' -d '{"offer_id":12}'

# Assigned driver progresses the trip in order.
curl -X POST http://localhost:8000/api/v1/rides/RIDE_UUID/driver-en-route/ -H 'Authorization: Bearer DRIVER_ACCESS_TOKEN'
curl -X POST http://localhost:8000/api/v1/rides/RIDE_UUID/arrived/ -H 'Authorization: Bearer DRIVER_ACCESS_TOKEN'
curl -X POST http://localhost:8000/api/v1/rides/RIDE_UUID/start/ -H 'Authorization: Bearer DRIVER_ACCESS_TOKEN'
curl -X POST http://localhost:8000/api/v1/rides/RIDE_UUID/complete/ -H 'Authorization: Bearer DRIVER_ACCESS_TOKEN'

# Receipt is a trip summary, never evidence of a collected fare.
curl http://localhost:8000/api/v1/rides/RIDE_UUID/receipt/ -H 'Authorization: Bearer ACCESS_TOKEN'
curl -X POST http://localhost:8000/api/v1/rides/RIDE_UUID/ratings/ \
  -H 'Authorization: Bearer ACCESS_TOKEN' -H 'Content-Type: application/json' -d '{"score":5,"comment":"Thank you"}'
```

Wire lifecycle: `searching → assigned → arriving → arrived → inProgress → completed`; cancellation before start and request expiry are terminal. Offers available is represented by pending valid offer records while the request remains `searching`; Flutter's existing ride enum is preserved. Fare locks on selection. Repeated identical selection/completion is safe; invalid transitions are rejected. Quote IDs and actual route inputs must match. Do not send invented distances or pricing; backend recalc/snapshots remain authoritative.

Payment IDs remain `cash-usd`, `ecocash`, `onemoney`; preferences `cash`, `ecocash`, `onemoney`. Only USD booking is accepted. The uppercase ECOCASH/ONEMONEY/CASH and proposed_fare JSON examples in the request describe business concepts; the established mobile contract uses `payment_method_id` and integer `fare_cents`. Receipts explicitly return `platform_processed_payment=false` and `payment_receipt_verified=false`. Earnings are agreed trip values, with no invented commission or verified settlement. There is no Pay Now, gateway, wallet or charging endpoint.

## Lists, filtering and errors

Paginated collections use `{count,next,previous,results}`, default page size 50, `?page=2`. Generic resources use documented `search` and allowlisted `ordering` (prefix `-` for descending). Admin rides filter status, passenger, assigned_driver, category, service_area and ISO created_after/created_before; drivers/applications filter status, availability, category and submission dates; notifications filter unread/type/created dates. Invalid filters return field errors. Place/category/requirement choices and bounded summary rows use `results`; payment metadata uses the established `items` key. Timelines use `after` event cursor and return at most 200 records. The schema distinguishes these shapes.

```json
{
  "errors": ["The offered vehicle is no longer active."],
  "code": "VEHICLE_NOT_APPROVED",
  "field_codes": ["VEHICLE_NOT_APPROVED"],
  "request_id": "example-correlation-id"
}
```

400 is validation, 401 invalid/expired/revoked authentication, 403 insufficient permission/eligibility, 404 an absent or nonvisible object, 409 a stale quote/conflict where implemented, 429 throttling/cooldown, 503 missing/unavailable provider. Existing ride transition validation continues to use 400, with machine codes such as INVALID_RIDE_STATUS, OFFER_EXPIRED and RIDE_ALREADY_ASSIGNED; do not infer a code only from HTTP status. Field codes retain DRF's specific validators. No 422 convention is introduced. Request IDs appear in headers/logs without tokens, OTPs or document contents.

## React administration

Use a staff JWT/session and explicit model permissions. Staff alone does not grant driver verification, reports, personal data or configuration access. Review actions require `drivers.review_driver`; dashboards/reports require `drivers.operate_platform`; passenger updates/status require `auth.change_user`; resource reads/edits require the corresponding model permission. Pricing/service-area/document-requirement changes and review/suspension/resolution actions create audits. Configuration DELETE disables the row instead of destroying quote/history dependencies. Driver/vehicle/account actions use business services; do not PATCH authoritative ride state or approval flags through generic resources.

Admin resources: passengers, drivers, driver-applications, vehicles, rides, offers, pricing-rules, service-areas, document-requirements, disputes and audit-logs. Dashboard analytics use actual rows. Reports paginate rides, drivers, passengers or completed agreed fares. Sensitive support messages and verification details require their own permissions. Administrative group/permission assignment remains in Django admin with its built-in audit log; no unrestricted role-management API exists.

## Compatibility with existing frontends

Frontend code was inspected read only. `/mobile/v1/` shares the same handlers. Existing `me/`, `driver/application/`, `driver/availability/`, `driver/requests/`, `routes/quote/`, `rides/{id}/accept/`, `arriving/`, `events/`, `locations/saved/`, `safety/contacts/` and earlier admin aliases remain compatibility paths. Their implementations are not counted twice in the canonical endpoint report. Preferred new resource paths are in OpenAPI.

Flutter's legacy multipart `driver/application/` submits registration fields/files together. The secure backend draft API accepts structured JSON details and separately configured document uploads, then explicit submit. Integrate that sequence; do not silently self-approve or infer document requirements from filenames. Flutter's `status.name`, `Standard/Comfort/XL`, integer cents and direct-payment preference casing remain stable. Mobile code referring to unsupported historical currencies/methods must use current metadata. Native background location and push permission handling remain client responsibilities.

React should use the protected documentation, explicit staff roles, paginated resource shapes and action endpoints. Handle rejected applications with reasons, suspended eligibility and 409/429/503 retries explicitly. Reconnect sockets using the [documented event IDs/sequences](websockets.md); use REST snapshots after a gap. Do not count WebSocket publication as device delivery or direct payment as verified funds.

## Validation commands

```sh
DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py test accounts drivers rides core --noinput
DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py makemigrations --check --dry-run
DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py spectacular --file docs/openapi.yaml --validate
# Use disposable MySQL credentials/configuration, never a production test database.
DJANGO_SETTINGS_MODULE=rideflow.mysql_testing .venv/bin/python manage.py test accounts drivers rides core --noinput --keepdb
DJANGO_SETTINGS_MODULE=rideflow.production .venv/bin/python manage.py check --deploy
```

Real SMS/maps/push credentials, live Redis fan-out/failover, HTTPS ingress, monitoring, backups/restores, device integration, load tests and final legal review remain launch work. Docker configuration is provided but was not built here. No production database migration or public deployment is claimed.

### Compatibility route details

These paths retain their established handlers but are excluded from distinct-operation totals and, where redundant, from the preferred schema:

| Compatibility operation | Preferred resource/action |
|---|---|
| GET/POST `me/` | GET `auth/me/`, PATCH `users/me/` |
| GET/POST `driver/application/` | `drivers/applications/me/` draft plus separate documents and submit |
| POST `driver/availability/` with `online` boolean | `drivers/me/go-online/` / `go-offline/` |
| GET `driver/requests/`, `driver/trips/`, `driver/earnings/` | Corresponding `drivers/me/` resources |
| GET `driver/requirements/` | GET `drivers/document-requirements/` |
| GET `driver/documents/{id}/` | GET `drivers/applications/me/documents/{id}/` for owner; authorized staff retain the private reviewer handler |
| POST `rides/{id}/accept/` | POST `rides/{id}/select-offer/` |
| POST `rides/{id}/status/` with `status` and optional `reason` | Explicit `driver-en-route/`, `arrived/`, `start/`, `complete/`, `cancel/` actions |
| POST `rides/{id}/arriving/` | POST `rides/{id}/driver-en-route/` |
| GET `rides/{id}/events/?after=N` | GET `rides/{id}/timeline/?after=N` |
| GET/POST/DELETE `locations/saved/`, `safety/contacts/` | Owned saved-place/emergency-contact resource APIs |
| POST/DELETE `notifications/devices/` with token | POST `devices/register/`, DELETE `devices/{id}/` |
| Earlier `admin/pricing/`, `admin/audit/`, `admin/users/`, `admin/tickets/`, `admin/overview/` | Pricing rules, audit logs, passengers, disputes and dashboard resources |
| POST `admin/vehicles/{id}/review/` with `approved` boolean | Explicit vehicle approve/reject actions |

For schema-visible aliases such as OTP resend, logout-all, route quotes and status reads, `x-alias-of` identifies the same semantic operation directly in OpenAPI. Both logout URLs revoke all sessions; there is no narrower logout claim. Compatibility endpoints retain authorization and validation and never grant a payment gateway or driver approval shortcut.
