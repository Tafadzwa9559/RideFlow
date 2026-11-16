# Trivia backend

Your Journey. Your Choice. — MOrdec Solutions (Private) Limited.

Modular Django monolith for Zimbabwe urban rides. MySQL is authoritative; Redis carries Channels events, cache and Celery messages. USD fares and exactly Cash, EcoCash and OneMoney **direct-payment preferences** are supported. Trivia never collects or verifies passenger fare payments. Existing Django user identities and migration history are retained.

Complete REST resources, Swagger/ReDoc, cURL workflow and compatibility notes: [API integration guide](docs/api-integration-guide.md). WebSocket protocol: [docs/websockets.md](docs/websockets.md).

## Local setup

Python 3.12, MySQL 8+, Redis and system MySQL client development headers are required.

```sh
cd Backend
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
# Set a generated DJANGO_SECRET_KEY and database passwords in .env.
# Export environment values yourself for native commands; Django does not load .env.
set -a
. ./.env
set +a
.venv/bin/python manage.py migrate
.venv/bin/python manage.py createsuperuser
.venv/bin/daphne -b 127.0.0.1 -p 8000 rideflow.asgi:application
# Separate terminals with the same exported environment:
.venv/bin/celery -A rideflow worker --loglevel=INFO
.venv/bin/celery -A rideflow beat --loglevel=INFO --schedule=/tmp/trivia-beat
```

Alternatively, after setting `.env`, `docker compose up --build` starts MySQL, Redis, migration job, Daphne, worker and Beat. Only the API binds to loopback; database and broker have no published ports. Containers run the application as a non-root user. Put an HTTPS reverse proxy in front of Daphne; serve collected static files separately and never serve private media from the web server. Docker configuration is supplied but has not been built in this environment.

## Configuration before bookings

No commercial fares or enabled cities are seeded. In `/admin/` or authorized configuration APIs create a rectangular service area and pricing for `Standard`, `Comfort` or `XL`, then explicitly enable them. All prices are administrator policy, never claimed Zimbabwe market rates. Formula: `(base + kilometres × per_km + minutes × per_minute) × time_multiplier + booking_fee`, rounded to configured USD increment and clamped at the minimum; routes over the maximum fail. Time bands use Africa/Harare. Quotes preserve pricing snapshots/version and expire if the policy changes. Routing uses the configured HTTPS OSRM-compatible provider and validates returned geometry, duration, distance and road snap; there is no straight-line fare fallback. Geocoding uses an optional HTTPS Nominatim-compatible provider. Proximity matching uses spherical distance only to find nearby drivers, never to price a journey.

Configure `SMS_PROVIDER` as a dotted class path implementing `send(phone, code)`. It must durably accept delivery or raise; no production SMS vendor is fabricated. OTP delivery is synchronous so plaintext OTPs need not be stored in Redis or a database outbox. OTPs are hashed, expire in five minutes, allow five attempts, and have a 60-second resend cooldown, with additional per-IP request/verification limits. For local development only, explicitly set `DJANGO_DEBUG=true`, `TRIVIA_LOCAL_OTP=true`, and `SMS_PROVIDER=accounts.services.authentication.LocalSMS`. Its `messages` dictionary is process-local and inspectable in Python; codes are never returned by REST or logged. Production settings reject this adapter. Multi-process local runs should use a real testing SMS provider.

Configure enabled document requirements in Django admin before accepting applications. **No document is claimed to be legally required merely because a competitor requests it.** The operator must approve requirements. Personal/licence/vehicle details are mandatory. Submitted applications are never self-approved. Driver review permission is `drivers.review_driver`; operations permission is `drivers.operate_platform`. Use Django Groups and model permissions for support, verification and operations roles; interface mode carries no authority. Superusers manage administrative accounts and group membership in Django admin, whose built-in LogEntry records these changes.

Driver uploads accept decoded JPEG/PNG images up to 5 MiB and 25 million pixels; PDF uploads are deliberately not supported. Files use opaque keys under `PRIVATE_MEDIA_ROOT`; no public URL exists. Only the applicant and authorized reviewers can download them. Old replaced files require the retention procedure described below. Before online status, drivers need approved application/vehicle, valid licence and required documents, no active assignment and recent location. Pending, rejected and suspended drivers cannot operate.

## API

Canonical base: `/api/v1/`. `/mobile/v1/` uses the same handlers for existing Flutter contracts. OpenAPI: [docs/openapi.yaml](docs/openapi.yaml); staff-only live `/api/schema/` and `/api/docs/`. Bearer JWT authentication is the mobile default; Django sessions require CSRF protection. Phone identities extend `auth.User` rather than replacing an established user table. Phone numbers normalize to E.164 with Zimbabwe as default region. Logout revokes all sessions for the phone account; refresh rotation blacklists used refresh tokens. Access tokens last 10 minutes and refresh tokens seven days by default.

Existing mobile field names and enum casing are preserved: `Standard`, `Comfort`, `XL`; ride states `searching`, `assigned`, `arriving`, `arrived`, `inProgress`, `completed`, `cancelled`, `expired`; preferences `cash`, `ecocash`, `onemoney`. `cash-usd` is the stable existing cash method ID. Prices use integer cents or decimal strings. No uppercase duplicate enums or alternate request schemas are silently accepted.

| Resource | Endpoints and behavior |
|---|---|
| Identity | POST `auth/otp/request/`, `auth/otp/verify/`, `auth/token/refresh/`, `auth/logout/`; GET `auth/me/`; GET/PATCH/POST `me/`, PATCH `users/me/`. No password token shortcut. |
| Onboarding | GET/PATCH/POST `drivers/applications/me/`; POST `drivers/applications/me/documents/` (multipart `requirement,file,expires_on`), `drivers/applications/me/submit/`; GET `drivers/me/verification-status/`; GET `driver/requirements/`; GET `driver/documents/{id}/`. Existing `driver/application/` maps to the same draft service. Submission is explicit. |
| Availability | POST `drivers/me/location/` (`latitude,longitude` decimal coordinates), `drivers/me/go-online/`, `drivers/me/go-offline/`; mobile compatibility `driver/location/`, `driver/availability/` (`online` boolean). Location updates are limited to one every three seconds. |
| Pricing | POST `routes/quote/` or `fares/estimate/` with `pickup,destination,category,currency`; GET `places/?q=`, `service-areas/`, `currencies/`, `payments/methods/`. A place is `{name,latitude,longitude}`. |
| Booking | POST `rides/` with quote fields plus `quote_id,idempotency_key,fare_cents,payment_method_id,passenger_note`; optional `payment_preference` must match method. An identical key/payload returns the existing ride; changed payload fails. One active passenger booking. GET `rides/`, `rides/active/`, `rides/{uuid}/`. |
| Driver discovery | GET `drivers/me/requests/` or `driver/requests/`: fresh, approved, online drivers see matching category/coverage/proximity requests. No passenger identity document or phone is exposed. |
| Negotiation | POST `rides/{uuid}/offers/` with `{decision: accept|counteroffer|decline, fare_cents?, note?, pickup_minutes?}`. Identity comes from JWT. GET offers is passenger-owner only. POST `offers/{integer}/withdraw/`; POST `rides/{uuid}/accept/` or `select-offer/` with integer `offer_id`. Legacy offer primary keys are retained. |
| Trip | Assigned driver POST `rides/{uuid}/arriving/`, `arrived/`, `start/`, `complete/`; participant POST `cancel/` before trip start; compatibility `status/` takes `{status,reason?}`. No arbitrary state updates. |
| Recovery | GET `rides/{uuid}/events/?after=0` returns at most 200 sequenced events; advance cursor to last received sequence until caught up. GET current ride for authoritative snapshot. |
| After trip | POST `rides/{uuid}/ratings/` with score 1–5 and optional comment, once per author. GET `drivers/me/earnings/?period=all|day|week|month`, `drivers/me/trips/`, `payments/history/`. Earnings report completed agreed fares; payment receipt remains unverified. |
| Notifications | GET `notifications/`, POST `notifications/{uuid}/read/`; POST/DELETE `notifications/devices/` registers/removes authenticated Android/iOS tokens. Optional `PUSH_PROVIDER` implements `notifications.services.push.PushProvider`; no credentials or sender is bundled. Logout removes device registrations. |
| Safety | POST `support/tickets/` (`category: support|safety`, `message`, optional owned ride_id). GET/POST/DELETE `safety/contacts/`; POST `rides/{uuid}/share/` with `recipient_id`, authenticated recipient GET `safety/shares/{id}/`, owner DELETE to revoke. Sharing expires after six hours or trip termination. No emergency-service integration is claimed. |
| Administration | GET `admin/overview/`; permission-scoped `admin/drivers/`, `admin/rides/`, `admin/users/`, `admin/tickets/`; GET/POST/PATCH `admin/pricing/`, `admin/service-areas/`; POST `admin/drivers/{id}/review/`, `admin/vehicles/{id}/review/`, `admin/users/{id}/status/`, `admin/rides/{uuid}/cancel/`. |

Lists for rides, driver requests/trips, notifications and admin resources paginate at 50 with DRF `count,next,previous,results`. Ride history/admin rides support `?status=`. Payment history caps at 100; service configuration and user saved places remain small lists. Errors are `{errors: <field errors or detail>, request_id}` with 400 validation, 401 authentication, 403 authorization, 404 nonvisible object, 409 stale quote, 429 throttle or 503 missing provider/infrastructure. Request IDs appear in response headers and structured logs; payloads, OTPs and tokens are not logged by application code.

## Transaction and lifecycle rules

Searching → assigned → arriving → arrived → inProgress → completed. Cancellation is allowed before start; searching requests expire. Repeating the same completed transition is safe. No fare changes after selection. Selecting an offer locks ride, driver application and offer in that order, checks freshness/approval/availability again, creates an `ActiveAssignment` with unconditional unique keys for ride, driver and passenger, stores agreed fare and vehicle, closes competing offers and updates informational payment amount. These unique keys work on MySQL without relying on unsupported partial unique indexes. Application locks serialize the same driver across different rides. Passenger row locks plus unique idempotency keys protect booking retries. All mutating trip services use database transactions.

Completed/cancelled drivers become offline and must explicitly go online after publishing fresh location. Expired documents or suspended accounts stop operational access; an administrator must resolve any affected active trip through the appropriate operational policy. Driver disconnect alone does not cancel a trip.

## WebSockets and recovery

Paths: `/ws/v1/notifications/`, `/ws/v1/passenger/rides/{uuid}/`, `/ws/v1/driver/rides/{uuid}/`, `/ws/v1/driver/requests/`. Origins must match allowed hosts. Authenticate with `Authorization: Bearer <access>` for native clients, or first frame `{"token":"<access>"}` within five seconds for browser clients. The socket may accept the transport before authentication, but no subscriptions/data are available until `connection.ready`. URLs never contain tokens. Close codes: 4401 invalid/expired authentication, 4403 forbidden room, 4400 unsupported input. Reauthentication requires reconnection. Tokens expire on the socket and are rechecked on event delivery and ping; driver authorization is rechecked for request streams.

Events carry `schema_version,event_id,type,resource_id,timestamp,sequence,payload`. Types include `ride.created`, `ride.request`, `offer.created`, `offer.declined`, `offer.withdrawn`, `offer.expired`, `driver.assigned`, `driver.location`, `ride.arriving`, `ride.arrived`, `ride.inProgress`, `ride.completed`, `ride.cancelled`, `ride.expired`, `verification.updated`. Only ride participants receive driver tracking. Other offering drivers receive assignment/closure, never subsequent GPS. Persisted notifications form a transactional outbox. Celery Beat drains it every two seconds. Delivery is at least once: deduplicate `event_id`; apply increasing ride `sequence`; recover gaps with REST event history/current ride. `delivered_at` means published to channel layer, not device acknowledgement. `read_at` records explicit user acknowledgement. Redis restart can lose in-flight socket messages, but the relational event log and notification inbox remain authoritative.

Celery tasks: `dispatch_request` (eligible bounded proximity fan-out with stable per-driver event IDs), `maintenance` (request/offer expiration, stale online exclusion, rediscovery), `retention` (expired OTP and old GPS cleanup), `deliver_outbox`, `send_push`. Events are written inside database transactions; initial dispatch is queued with `on_commit`, with periodic rediscovery recovering enqueue failure. Never run multiple Beat schedulers. Provider push retries need adapter event-ID deduplication. No claim of live FCM/APNs delivery is made.

## Verification and deployment

```sh
DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py test accounts drivers rides core --noinput
DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py makemigrations --check --dry-run
DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py spectacular --file docs/openapi.yaml --validate
# Provision a disposable MySQL instance; see rideflow/mysql_testing.py variables.
DJANGO_SETTINGS_MODULE=rideflow.mysql_testing .venv/bin/python manage.py test accounts drivers rides core --noinput
DJANGO_SETTINGS_MODULE=rideflow.production .venv/bin/python manage.py check --deploy
```

SQLite is limited to explicit `rideflow.testing`; concurrency tests skip there. MySQL tests use `MYSQL_TEST_HOST`, `MYSQL_TEST_DATABASE`, `MYSQL_TEST_NAME`, `MYSQL_TEST_USER`, `MYSQL_TEST_PASSWORD`. Production refuses non-MySQL and local OTP, requires a secret, disables DEBUG and sets HTTPS/HSTS/secure cookies. `/health/` is liveness; `/ready/` checks MySQL, Redis and at least one Celery worker without returning infrastructure details.

Before deployment: configure trusted HTTPS termination, host/origin allowlists, SMS and maps contracts, explicit document/coverage/pricing policies, private media permissions and encrypted backup storage, worker monitoring, external exception reporting and provider timeouts. Collect static files. Apply migrations to a backed-up staging copy, review legacy records and run the MySQL tests. Backup MySQL and private media together, enable managed point-in-time recovery where available, test restoration into an isolated environment, reconcile event cursors and leave stale driver availability offline after recovery. Keep Redis internal with authentication/TLS when crossing hosts. Proxy/body/connection limits must complement application throttles.

Retention: GPS defaults to seven days across location history, notification payloads and sequenced event payloads (expired event payloads are redacted while sequence IDs remain); expired OTP rows are removed after a day. Legal retention for verification documents, support reports, audit logs and ride history needs operator policy. Document replacements leave old private blobs for controlled retention review; do not expose or indiscriminately delete them. No automated private-document cleanup is enabled without an approved retention policy. Native background location permissions and device delivery remain frontend/deployment integration work.

This is a tested core implementation, not certification of production readiness. Live SMS, maps credentials, push sender, object storage signing, full deployment/load/failover testing and final privacy/transport legal review are external launch requirements. Automatic radius expansion, route optimization, broad admin search/report exports and a configured external exception aggregator remain extensions; no fake success endpoints stand in for them.
