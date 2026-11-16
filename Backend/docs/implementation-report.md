# Trivia backend implementation report

Date: 16 November 2026 (Africa/Harare).

## Delivered modules and workflow

- Existing `accounts`, `drivers`, `rides`, `payments`, `notifications`, `core` and `rideflow` structure reused; no duplicate Django project or user table introduced.
- Accounts: E.164 phone normalization, hashed OTPs, expiry/cooldown/attempt limits, IP throttling, configurable SMS interface, JWT rotation/blacklisting, immediate phone-account session revocation, profile update.
- Driver onboarding: resumable draft, explicit submission, administrator review/rejection/suspension/reactivation, vehicle review, configured document requirements, decoded image upload validation, opaque private storage and authorized retrieval. Self approval is prohibited. No automatic test-only approval endpoint exists.
- Pricing: existing OSRM road routing and Nominatim-compatible search retained; configurable enabled coverage, category pricing, time adjustment, USD Decimal calculations, quote snapshots and limits, one-time quote consumption and idempotent passenger booking.
- Ride negotiation: authenticated nearby eligible drivers see requests, accept proposed fare, counteroffer, decline or withdraw. Passenger compares actual driver/vehicle/rating/trip data and selects an offer transactionally. Agreed fare locks, competing offers close, driver occupancy uses MySQL-compatible unconditional uniqueness constraints.
- Trips: assigned-driver arrival/start/completion, participant cancellation before start, automatic request/offer expiration, driver availability/heartbeat freshness, participant-only GPS, sequenced event recovery, history and bilateral ratings.
- Direct payments: exactly Cash, EcoCash, OneMoney and USD for current booking. Payment records remain informational and unverified; no gateway, checkout, charge, wallet, settlement or fabricated receipt. Unsupported historical method rows remain disabled for compatibility and are excluded from metadata.
- Administration: actual overview statistics, drivers, users, vehicles, rides, offers, audit records, tickets, pricing and service-area APIs with scoped permissions. Review, suspension, vehicle changes, configuration changes and operational cancellations are audited. Administrative identities/groups remain managed through Django admin with its built-in LogEntry audit history.
- Safety: restricted support/safety tickets, administrator investigation status, emergency contacts, authenticated recipient trip sharing with expiry and revocation. No emergency-service integration is claimed.
- Reporting: completed agreed fares, day/week/month/all periods and actual trip counts, clearly separated from verified receipt of money.
- Operations: MySQL default, Redis cache/Channels/Celery configuration, durable notification outbox, Daphne ASGI, request IDs and structured logs, health/readiness, production settings, reproducible requirements and Docker Compose.

## Database

New models: `PhoneIdentity`, `PhoneChallenge`, `AuditEvent`, `DriverApplication`, `Vehicle`, `DocumentRequirement`, `DriverDocument`, `ActiveAssignment`, `RideEvent`, `LocationUpdate`, `Rating`, `SupportTicket`, `SavedPlace`, `EmergencyContact`, `TripShare`, `Notification`, `DeviceToken`.

Existing `auth.User`, pricing/quote, ride/offer and payment models were preserved and extended. User and offer integer keys remain intact; ride/quote/event identifiers remain UUIDs. Prices serialize as decimal strings or integer cents. Historical exchange-rate records are retained without an active conversion booking/API flow.

Generated migrations: `accounts/0001`, `drivers/0001`, `notifications/0001–0002`, `payments/0004–0005`, `rides/0003–0005`. The pre-existing uncommitted `rides/0002` remains part of the migration chain. `rides/0005` backfills expiration on older request rows. Legacy assigned rides without real assigned-driver data require operational review rather than guessing a driver.

Migrations were applied by test database setup to isolated MySQL 8.0.46 and SQLite databases. The existing local `db.sqlite3` and any production database were not migrated or converted. Production/staging migration remains an operator deployment step after backup and review.

## REST, WebSockets and jobs

The complete endpoint table, enum values, request shapes, permissions, pagination, errors, local commands and deployment steps are in [../README.md](../README.md). Machine-readable schema: [openapi.yaml](openapi.yaml). Staff-only live schema/UI: `/api/schema/`, `/api/docs/`. Canonical API `/api/v1/` and compatibility `/mobile/v1/` share handlers; existing mobile names/casing are preserved instead of implementing a separate inconsistent contract.

WebSocket channels: notifications, passenger ride, driver ride and driver requests under `/ws/v1/`. Native Authorization header or first-frame browser authentication; allowed-origin checks, room authorization, access-token expiry, permission checks during delivery and REST recovery. No bearer tokens in URLs. At-least-once event envelopes carry UUID event IDs and ride sequence numbers. Unauthenticated transports may connect briefly to send authentication but receive no private data.

Celery tasks: `dispatch_request`, `maintenance`, `retention`, `deliver_outbox`, `send_push`. Initial dispatch follows transaction commit. Outbox rows commit with ride changes and survive broker outages. Redis is not authoritative for assignments. Periodic rediscovery recovers initial dispatch enqueue failure. OTP delivery is synchronous by design to avoid storing plaintext OTP in a broker/outbox. Optional push adapters receive generic event types and stable IDs; provider credentials are not invented.

## Verification

See final recorded results below. Tests use explicit artificial road/pricing/image fixtures. No live SMS/maps/push delivery, passenger charge or financial settlement is exercised or claimed. Channels tests use the in-memory channel layer; real Redis fan-out/failover remains staging verification. WebSocket tests require execution outside this environment's network sandbox because asynchronous thread wakeup sockets are restricted there.

Seven MySQL race scenarios: two drivers selected for one ride, one driver selected for two passengers, selection versus withdrawal, cancellation versus assignment, simultaneous completion retries, duplicate offer requests, duplicate passenger booking keys. These execute on real MySQL connections/transactions and skip on SQLite.

Production checks use `rideflow.production` and a temporary check-only secret; they do not certify deployment credentials or production infrastructure. No Docker binary was available, so images/Compose were not built or started.

## Launch requirements and practical limits

- Supply a real SMS adapter and credentials, licensed routing/geocoding deployment, optional FCM/APNs adapter, operator-approved document requirements, enabled coverage and commercial fare policies. No operational city or market fare was invented.
- Provision private-media persistence/backup and TLS ingress. If using `TRUST_PROXY_SSL_HEADER=true`, ingress must strip untrusted forwarding headers. Configure Redis network protection and monitoring, external exception reporting, database backups/PITR and restore drills.
- Native background-location permissions, mobile lifecycle handling and React integration need device/staging validation. Existing frontend differences are documented; Flutter and React were read only and their pre-existing uncommitted changes remain.
- Document support is JPEG/PNG only; PDFs, managed object-storage signed URLs and automatic private-document deletion are not supplied. Document/report/audit retention needs an approved policy. GPS history/payload cleanup defaults to seven days.
- Automatic matching-radius expansion, broad administrative text search, report exports, advanced fleet metrics and external error-reporting integrations remain extensions. Driver matching uses configured bounded proximity, category, approval and freshness checks.
- Completed/cancelled drivers return offline. Account/document suspension during an active trip requires operational resolution; the API does not invent an unsafe automatic trip termination rule.
- Final transport/privacy legal review, real Redis/provider integration, deployment/load/failover validation and production rollout remain outstanding. The result is a tested core backend, not a claim of public-launch readiness.

## File inventory

The following inventory is scoped to Backend changes in the working tree. Ride model/API/service files and migration 0002 already had user changes before this work; they were extended in place. Python bytecode is excluded.

### Modified

- `Backend/.env.example`
- `Backend/.gitignore`
- `Backend/accounts/admin.py`
- `Backend/accounts/api/views.py`
- `Backend/accounts/models.py`
- `Backend/docs/booking.md`
- `Backend/drivers/admin.py`
- `Backend/drivers/api/serializers.py`
- `Backend/drivers/api/urls.py`
- `Backend/drivers/api/views.py`
- `Backend/drivers/models.py`
- `Backend/notifications/api/views.py`
- `Backend/notifications/models.py`
- `Backend/notifications/tasks.py`
- `Backend/payments/api/urls.py`
- `Backend/payments/api/views.py`
- `Backend/payments/models.py`
- `Backend/requirements.txt`
- `Backend/rideflow/__init__.py`
- `Backend/rideflow/asgi.py`
- `Backend/rideflow/settings.py`
- `Backend/rideflow/urls.py`
- `Backend/rides/admin.py`
- `Backend/rides/api/serializers.py`
- `Backend/rides/api/urls.py`
- `Backend/rides/api/views.py`
- `Backend/rides/consumers/ride_consumer.py`
- `Backend/rides/models.py`
- `Backend/rides/services/booking.py`
- `Backend/rides/tests/test_booking.py`

### Created

- `Backend/.dockerignore`
- `Backend/Dockerfile`
- `Backend/README.md`
- `Backend/accounts/authentication.py`
- `Backend/accounts/migrations/0001_initial.py`
- `Backend/accounts/services/authentication.py`
- `Backend/accounts/tests/test_authentication.py`
- `Backend/core/__init__.py`
- `Backend/core/admin_api.py`
- `Backend/core/errors.py`
- `Backend/core/middleware.py`
- `Backend/core/schema.py`
- `Backend/core/tests.py`
- `Backend/core/views.py`
- `Backend/docker-compose.yml`
- `Backend/docs/implementation-report.md`
- `Backend/docs/openapi.yaml`
- `Backend/drivers/migrations/0001_initial.py`
- `Backend/drivers/services/eligibility.py`
- `Backend/drivers/services/onboarding.py`
- `Backend/drivers/tests/test_onboarding.py`
- `Backend/notifications/migrations/0001_initial.py`
- `Backend/notifications/migrations/0002_devicetoken.py`
- `Backend/notifications/services/events.py`
- `Backend/notifications/services/push.py`
- `Backend/payments/migrations/0004_direct_payment_preferences.py`
- `Backend/payments/migrations/0005_alter_payment_currency_alter_payment_status.py`
- `Backend/payments/tests/fixtures.py`
- `Backend/rideflow/celery.py`
- `Backend/rideflow/mysql_testing.py`
- `Backend/rideflow/production.py`
- `Backend/rideflow/testing.py`
- `Backend/rides/migrations/0002_farequote_pricing_version_ride_passenger_note_and_more.py`
- `Backend/rides/migrations/0003_activeassignment_locationupdate_rating_rideevent_and_more.py`
- `Backend/rides/migrations/0004_emergencycontact_tripshare.py`
- `Backend/rides/migrations/0005_legacy_request_expiration.py`
- `Backend/rides/services/lifecycle.py`
- `Backend/rides/tasks.py`
- `Backend/rides/tests/helpers.py`
- `Backend/rides/tests/test_concurrency.py`
- `Backend/rides/tests/test_integration.py`
- `Backend/rides/tests/test_lifecycle.py`
- `Backend/rides/tests/test_websocket.py`

### Removed scaffold files

- `Backend/accounts/tests.py`
- `Backend/drivers/tests.py`
- `Backend/notifications/tests.py`
- `Backend/riders/tests.py`

## Final recorded results

- MySQL 8.0.46: **43/43 tests passed**, including all seven concurrency tests; final run 8.690 seconds after database setup. Migrations through `rides/0005` applied to the isolated test database.
- SQLite test configuration: **36 passed, seven MySQL-only concurrency tests skipped**; final run 3.543 seconds after database setup.
- End-to-end API test passed: OTP identities → driver details/private document → submission → administrator approval → location/online → road quote → adjusted fare/EcoCash/notes → counteroffer → selection → arrival/start/completion → rating → earnings/admin report.
- `manage.py check`: passed, zero issues.
- `manage.py makemigrations --check --dry-run`: no changes detected.
- `manage.py spectacular --file docs/openapi.yaml --validate`: passed, no warnings/errors in final generation.
- `manage.py check --deploy` with production settings: passed, zero issues.
- `git diff --check`: passed.
- Live provider delivery, Redis transport/failover, Docker build and public deployment were not tested. No staging/production database was modified.
