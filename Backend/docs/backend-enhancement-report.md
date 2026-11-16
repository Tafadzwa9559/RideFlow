# Trivia backend enhancement report

Latest follow-up verification: **85 tests passed, 0 failed, 0 skipped, 214.250 seconds**, including 11 real MongoDB concurrency scenarios. Strict schema, migration drift, local migration and read-only configured-database checks passed. Live Atlas/Render/provider acceptance remains unverified.

## Scope and audit

All changes are within Backend. Existing apps, business workflow, public URLs, USD-only fares and informational Cash/EcoCash/OneMoney preferences are preserved. No customer records, source files, collections or historical migrations were deleted. No external service was deployed. [BACKEND_AUDIT.md](../BACKEND_AUDIT.md) records the baseline and findings.

## Implementation

- Added strict production validation for Atlas SRV URI/TLS, explicit public hosts, HTTPS browser origins and shared private document storage.
- Restricted destructive Django tests to loopback MongoDB replica sets, rejecting Atlas and remote URIs before database setup.
- Preserved the PrivateStorage migration identity while delegating actual bytes to a shared private S3-compatible backend in production. Existing authenticated download endpoints remain authoritative; there are no public media URLs. Local development retains local storage.
- Added daily licence/driver-document/vehicle-document expiry alerts. Deterministic event IDs deduplicate retries and recurring schedule ticks. Metadata-only alerts go to active approved owners and use existing notification/outbox delivery.
- Added eight query-driven indexes through three additive MongoDB migrations and a read-only index/explain management command.
- Added Render ASGI web, separate Celery worker, singleton beat and private noeviction Redis configuration. Added task time limits, broker visibility timeout and worker prefetch bounds.
- Fixed critical offer editing: canonical GET-only route previously shadowed PATCH; the update used an undefined Decimal and bypassed fare limits/transaction guards. Canonical PATCH now enforces ownership, eligibility, fare bounds and pending/searching state under the same ride/driver guards used for assignment. Omitted fields are preserved; agreed fares cannot be edited.
- Added typed Swagger contracts for three already implemented views and corrected sync pending-actions by lifecycle stage.

Files: `core/production.py`, `core/tests.py`, `core/contracts.py`, `core/schema.py`, `core/management/commands/mongodb_index_report.py`; `rideflow/settings.py`, `production.py`, `testing.py`; `accounts/models.py`; `drivers/models.py`, `tasks.py`, `tests/test_maintenance.py`; `rides/models.py`, `api/views.py`, `api/resources.py`, `services/lifecycle.py`, `tests/test_offer_updates.py`, `tests/test_concurrency.py`, `tests/test_rest_resources.py`; three new `mongo_migrations` files; `.env.example`, `requirements-storage.txt`, `render.yaml`, `scripts/render-build.sh`; README/audit/API/OpenAPI/catalog and operational reports/guides. No Flutter/React edits.

## MongoDB report

Reviewed existing auth/contrib, accounts, drivers, vehicles/documents, rides/offers/events/locations/quotes/configuration, ratings/support, notifications/devices, payments/preferences and operation-fence collections. No duplicate entity collections added. Existing ObjectIds/UUIDs, references, uniqueness constraints and location 2dsphere index retained.

| Collection | Added index | Query |
|---|---|---|
| accounts_phonechallenge | otp_expiry_cleanup | Expired temporary challenge cleanup |
| drivers_driverapplication | driver_licence_expiry | Approved drivers/date window |
| drivers_driverdocument | driver_document_expiry | Expiry alerts |
| drivers_vehicledocument | vehicle_document_expiry | Expiry alerts |
| rides_ride | ride_passenger_history | Passenger + newest history |
| rides_ride | ride_driver_state_history | Assigned driver/status/newest history |
| rides_ride | ride_expiry_work | Searching request expiration |
| rides_rideoffer | offer_expiry_work | Pending offer expiration |

Migrations: accounts `0002`, drivers `0004`, rides `0002`. All three applied successfully to isolated local `trivia_migration_verify`; drift check reports no changes. Atlas rollout remains a controlled release task. Local read-only explain selected `ride_passenger_history` with FETCH/IXSCAN, without a sort stage, for a representative synthetic passenger query. This is not an Atlas performance benchmark.

No TTL index silently deletes existing data. OTP/GPS cleanup already exists; a broader retention/TTL policy for notifications and audit/fence records needs operator review. Business ride/payment snapshots and audit history must not be treated as disposable temporary records.

## API report

157 canonical documented operations plus 10 semantic aliases. No REST URL removed. Existing sync, decline and PATCH handlers now have typed schema contracts; offer PATCH is now reachable at the canonical path. New `driver.document.expiry` events are documented in [API_DOCUMENTATION.md](../API_DOCUMENTATION.md); existing WebSocket ride envelopes remain unchanged. ObjectId-string migration requirements are retained in the integration guide.

Production Swagger/schema/ReDoc retain the existing Django staff-session login redirect flow; DEBUG development allows documentation. API WebSocket documentation requires administrator authorization. Tests now exercise actual staff sessions and nonstaff rejection rather than expecting JWT force-authentication to bypass the existing outer Django decorator.

## Verification

Completed full regression run: **79 tests passed, 0 failed, 0 skipped**, 349.732 seconds. This includes nine real replica-set concurrency scenarios, complete ride/negotiation/completion workflows, OTP/JWT, onboarding, role/ownership boundaries, geoNear/freshness, schema and new production/storage/expiry/offer tests. The final repeat after the storage/test-setting compatibility corrections also passed all 79 tests with no failures or skips in 246.716 seconds (see .mongo-enhancement-verified.log). The private test MongoDB process was stopped afterward; its files and the configured application database were preserved. Tests use an isolated local MongoDB replica set, never Atlas. Redis/Channels are in-memory test adapters unless a failure is explicitly simulated.

Additional checks passed:

- `manage.py check --database default`: no issues, local transaction-capable MongoDB.
- `manage.py makemigrations --check --dry-run`: no changes detected.
- `manage.py migrate --noinput`: all three additive index migrations applied on the isolated verification database.
- `manage.py spectacular --file docs/openapi.yaml --validate --fail-on-warn`: no errors/warnings.
- `manage.py check --deploy`: no issues under production settings with synthetic Atlas configuration; this check does not connect to Atlas.
- Render official JSON Schema validation, dependency `pip check`, and `git diff --check`: passed.
- Read-only index report/explain confirmed the passenger-history index is actually used locally.

Intermediate failures were investigated and corrected: storage serialization, the subprocess test working directory, missing view schema contracts, GET-route shadowing of offer PATCH and an outdated documentation test's expectation of 403 instead of the existing staff-session redirect. No failing scenario was skipped or hidden.

## Deployment report

See [Render guide](render.md), [load/recovery exercises](load-testing.md), `.env.example`, and `render.yaml`. Shared media dependencies are isolated in `requirements-storage.txt`: django-storages 1.14.6, boto3/botocore 1.44.3, s3transfer 0.19.3, jmespath 1.1.0, urllib3 2.8.0. Existing Django 5.2.19, official backend 5.2.4 and PyMongo 4.20.0 remain unchanged. Backend virtualenv installation and dependency consistency checked; no global packages changed.

The Blueprint passed Render's official JSON Schema validation. It is prepared for review and has not created/updated Render services. Reconcile the existing resource name/region/plan before adoption to preserve its URL. Use an existing shared secrets group, actual Atlas triviacluster SRV URI, least-privilege credentials, restricted network policy, private durable media and configured providers. Copy/reconcile local media at unchanged keys before switching storage.

## Remaining external work and limits

- Atlas cluster identity, access list, backups/restore, live query profiler/latency and real deployment connectivity have not been independently verified. No Atlas credentials or network policy were changed.
- Render live build/pre-deploy rollout, custom domains/proxy behavior, actual independent Redis/workers/beat, graceful restart and real cross-process WebSocket recovery need staging acceptance.
- Real SMS, routing/geocoding and optional push providers must be configured and tested. No delivery success is invented. OTP dispatch remains synchronous to avoid plaintext-code broker persistence.
- Mobile login is passwordless OTP. Django admin passwords use Django hashing; mobile password reset and verified email delivery are not added as a second authentication system. Define those product/provider contracts if needed.
- Support roles use existing granular staff permissions; provision/review least-privilege groups operationally. No broad implicit support privilege was introduced.
- Document storage configuration/authorized streaming is implemented; actual bucket policy, object round trips, encryption, media checksum migration and restore need operator/provider verification.
- Outbox is at least once; client event deduplication and provider push idempotency remain required. Provider-specific retry exceptions need adapter acceptance tests.
- Review maintenance duration and backlog on realistic datasets, set agreed SLOs, run staged load/failure exercises and approve retention policy. Local regression timing does not establish production capacity.

This revision improves the backend for serious integration testing; it does not claim production deployment certification.

## Follow-up: session rotation and notification reliability

Re-audited the current implementation after the repeated enhancement request. Preserved prior changes and addressed two additional gaps:

- `accounts/api/views.py`: refresh rotation now acquires user and refresh-JTI MongoDB guards and revalidates the token after serialization. This prevents simultaneous refresh replay and orders rotation with logout/account-status changes.
- `notifications/tasks.py`: explicitly retries redis-py connection/timeouts, broker operational failures, transient MongoDB errors and Channels capacity errors. Backoff is jittered, capped at 300 seconds, with five retries. `TransientPushError` gives configured adapters an explicit retry contract.
- `notifications/models.py`: internal `push_receipts` stores SHA256 destination-token hashes and acceptance timestamps. Independent nested MongoDB updates preserve receipts across retries; public response contracts exclude the field. Sequential retries skip successful devices. Concurrent delivery and the acceptance/write crash window still need provider deduplication using event and destination IDs.
- `mongo_migrations/notifications/0002_notification_push_receipts.py`: additive field with empty-dictionary default. The installed official backend initializes this field on existing notification documents; schedule that collection update during a controlled release for a large database. No collections/records are deleted or new entity collections added.
- Added six regression tests in `accounts/tests/test_session_concurrency.py` and `notifications/tests/test_delivery.py`: simultaneous refresh, logout/rotation race, Redis failure/recovery, partial push success/retry, unconfigured push and user opt-out.

Follow-up changes preserve dependencies, REST URLs, JWT response fields, payment behavior and existing ride WebSocket contracts. The configured application MongoDB connectivity/topology check passed read-only; this does not independently verify Atlas cluster identity or its network policy. Redis is not installed as a server in this environment; failure tests inject the actual redis-py exception into the channel transport. Real Redis worker/network fault acceptance remains outstanding, as do live Atlas/Render/provider checks.

Reference behavior was checked against [Celery retry documentation](https://docs.celeryq.dev/en/stable/userguide/tasks.html) and [redis-py error handling](https://redis.io/docs/latest/develop/clients/redis-py/error-handling/), as well as the installed library versions/source.


Follow-up verification notes: the initial receipt tests caught both MongoDB session participation and the UUID column/preparation contract; these were corrected rather than suppressing failures. One unlabelled test invocation from the repository root discovered zero tests and was discarded; the complete run is executed from Backend, the actual discovery root. The receipt migration applied successfully on the isolated verification database, migration drift reported no changes, strict OpenAPI export passed without warnings, and database-aware system checks passed.


### Final follow-up verification

From Backend, `DJANGO_SETTINGS_MODULE=rideflow.testing` with the explicitly local replica-set URI and isolated `test_trivia_followup_final` database:

- `manage.py test --noinput`: **85 passed, 0 failed, 0 skipped**, 214.250 seconds, including nine ride and two session concurrency tests.
- Strict `spectacular --validate --fail-on-warn`: passed; existing 157 canonical operations plus 10 aliases preserved.
- `makemigrations --check --dry-run`: no changes detected.
- `migrate --noinput`: receipt migration applied successfully to the private local verification database; no migration applied to Atlas by this follow-up.
- `check --database default`: passed on the isolated verification connection and read-only on the configured application connection.
- `git diff --check`: passed. No frontend changes or new dependencies in this follow-up.

The private test MongoDB process was stopped after verification; data files were preserved. Real Redis server/network failure, actual external SMS/push/route delivery, Atlas policy/backups/query performance, live Render rollout and shared-media round trips remain unverified as described above.
