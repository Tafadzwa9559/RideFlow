# Trivia MongoDB migration completion report

16 November 2026 — MOrdec Solutions (Private) Limited.

## Result

The existing backend now uses the **official Django MongoDB Backend** as its primary database. Existing apps, Django user identities, REST/WebSocket paths, JWT, Swagger/ReDoc, Channels, Redis, Celery and Daphne are retained. No Django project/app recreation, Djongo, MongoEngine, Flutter or React changes were introduced.

The code migration is implemented and tested. **No live customer/source database was converted, deleted or overwritten.** A real-data cutover still needs a frozen source snapshot, staged import, media reconciliation and operator rollout. The [controlled migration plan](mongodb-migration-plan.md) and implemented read-only exporter/verified importer provide that path. All old SQL migration files and the existing local SQLite file remain; the latter was read-only inventoried and contains no tables.

## Dependencies and models

- Python 3.12; Django **5.2.19**, unchanged major/minor.
- `django-mongodb-backend==5.2.4`, `pymongo==4.20.0`, `dnspython==2.9.2` in pinned runtime requirements.
- MySQL client dependency moved to optional `requirements-legacy.txt` for read-only source export. The existing virtual environment's MySQL driver was not uninstalled.
- Former implicit integer keys become official ObjectIdAutoFields; explicit UUID trip/quote/event keys and natural payment/requirement/category keys stay intact. IDs serialize correctly as strings through DRF, JSON and OpenAPI. Former integer JWT identities are rejected with 401 and require fresh login.
- Django auth/admin/contenttypes AppConfigs and a separate contrib migration graph use supported keys. SimpleJWT's two explicit integer token fields have a narrow pinned compatibility adaptation; the same JWT blacklist models and behavior remain. Tests prove normal (non-superuser) group permissions, sessions, token rotation/revocation and ObjectId token records.
- Driver applications gain indexed GeoJSON location with `[longitude,latitude]`. Existing personal/licence/vehicle/document fields and approval workflows remain. All existing pricing, rides/offers/trips, ratings, notifications, support and audit models use the MongoDB schema graph.
- `core.OperationFence` supports transaction write guards. FK references continue through Django ORM relationships, with service/import validation rather than relational FK enforcement.

## Transaction and query changes

Critical commands use `django_mongodb_backend.transaction.atomic()`, not native Django SQL atomic blocks. Unsupported select_for_update/prefetch_related calls were removed. Shared write guards serialize conflicting ride, driver, account and OTP commands through MongoDB write conflicts; active-assignment uniqueness remains a second guarantee.

Only the outer command retries transient transactions with bounded backoff. Unknown commit outcomes retry the same commit without rerunning its body; unresolved acknowledgement returns a conflict for state reconciliation. Commit hooks and the durable notification outbox prevent dispatch/assignment events from claiming uncommitted state. No assignment response returns before a successful commit.

Nearby matching uses an official MongoManager/raw_aggregate `$geoNear` pipeline with a 2dsphere index. Approval, category, active vehicle/documents, availability, freshness, coverage and occupancy are checked. Fare estimation continues using actual configured road routing and Decimal USD pricing. Readiness uses MongoDB ping/topology checks. Existing supported UTC date truncation and Python local-time earnings cutoffs remain compatible.

## Migrations and connectivity

A separate `Backend/mongo_migrations/` graph covers auth, contenttypes, admin, sessions, JWT blacklist and all business apps. It was generated, checked and applied to a new isolated MongoDB verification database, including unique indexes, driver-location 2dsphere index and the three direct-payment preferences. The original `*/migrations/` SQL graph was preserved unchanged; `rideflow/legacy_mysql.py` retains read-only source configuration.

- Installed MongoDB Server **8.2.12** was used; no global server package was installed.
- Isolated single-member `trivia-rs` replica set ran on localhost port 27028 with storage under ignored Backend test files.
- Both the isolated verification connection and the user's already configured MongoDB URI passed read-only database/topology checks.
- Test databases were separate `test_*` databases. Test settings now reject application database names to prevent accidental deletion.
- Migrations were **not** applied to the user's configured live/application database; only isolated verification/test databases were written.

## Executed verification

**Final unlabelled `manage.py test --noinput`: 70/70 passed, zero failures, zero skips**, on the actual replica-set MongoDB deployment; test execution after setup took 201.372 seconds.

This includes:

- OTP, accounts, profile and document APIs; private file contents and ownership; driver review and vehicles.
- Full OTP → registration/document → admin approval → online/location → route/fare → proposed fare/EcoCash/notes → counteroffer → passenger selection → trip completion → rating/history/earnings/admin report integration.
- All **eight** concurrent assignment scenarios: two drivers/one ride, one driver/two passengers, withdrawal/selection, cancellation/selection, duplicate booking keys, duplicate offers, repeated completion and vehicle activation/selection.
- MongoDB-specific permission/session/blacklist compatibility; transactional rollback and commit hooks; transient transaction retry; uncertain commit retry without duplicate command execution; 2dsphere proximity/freshness; legacy fixture import/checksums/reference mapping/password preservation/rerun safety; refusal of dangling references and nonempty targets; clean rejection of integer-identity tokens.
- Existing authenticated/unauthorized WebSocket, event delivery, recovery and schema tests. Channels/cache are in-memory test adapters; MongoDB itself is real, not mocked.

Other checks:

- `manage.py check --database default`: passed for the isolated verification database and separately for the user's configured connection.
- `manage.py makemigrations --check --dry-run`: no changes detected.
- `manage.py migrate --noinput`: all new MongoDB migrations applied successfully in the isolated verification database.
- `manage.py spectacular --file docs/openapi.yaml --validate`: passed, zero warnings/errors in the final export.
- `manage.py check --deploy --database default` with production settings and explicit production-safe SMS flags: passed.
- Compose YAML/service wiring and `git diff --check`: passed. Docker containers were not built/run.

Initial regression failures exposed the need for MongoManager on raw aggregation and string-ID assertion updates; these were fixed. There are no remaining failing tests from the executed final suite. These tests do not certify live provider delivery, large-scale performance or production failover.

## Data migration rehearsal and limits

`export_legacy_mysql` executes raw read-only SQL against a restored/quiesced source and writes a new private snapshot file. `import_legacy_snapshot` defaults to dry-run; applying requires an exact target-database acknowledgement and an empty/non-seed target. It maps integer PK/FK/M2M identities, reconciles seeded permissions/content types, preserves hashes/UUIDs/money/media references, rebuilds pricing/audit/event references and GeoJSON, and verifies per-record content checksums plus non-seed row counts. A manifest marks partial targets as `importing` and only marks verified results after reconciliation. Verified reruns recheck rather than overwrite data.

The automated rehearsal uses representative MySQL-shaped fixture records, including groups/permissions and password-preserving user conversion. It did **not** perform a production MySQL export. The actual source data/media migration, source-specific anomalies and cutover/rollback rehearsal remain operator work. Drivers start offline after transfer; old sessions/refresh records are not copied and phone session versions advance. Never run SQL and MongoDB as independent live writers.

## Startup and documentation

Complete commands and Atlas/local replica-set configuration are in [mongodb.md](mongodb.md). Existing `.env` credentials and DJANGO_SECRET_KEY were preserved. Use MONGODB_URI and MONGODB_DATABASE; Atlas SRV URIs are supported.

```sh
cd Backend
.venv/bin/pip install -r requirements.txt
# Start/init a local replica set and Redis, or use docker compose up --build.
.venv/bin/python manage.py check --database default
.venv/bin/python manage.py migrate
.venv/bin/daphne -b 127.0.0.1 -p 8000 rideflow.asgi:application
# Separate terminals with the same environment:
.venv/bin/celery -A rideflow worker --loglevel=INFO
.venv/bin/celery -A rideflow beat --loglevel=INFO --schedule=/tmp/trivia-beat
```

Protected documentation remains `/api/schema/`, `/api/docs/` (Swagger), `/api/redoc/` and `/api/websockets/`. The catalog still contains **154 distinct REST operations**, excluding marked compatibility aliases. Resource paths and existing ride UUID contracts are preserved; former numeric IDs are now ObjectId strings.

USD, EcoCash/OneMoney/Cash direct-payment preferences, optional passenger instructions, passenger choice of driver and administrator approval remain unchanged. No gateway, automatic charge, wallet or ZiG booking was added.

## Remaining production hardening

Rehearse actual source/media migration and verify deployment credentials/replica membership, secured MongoDB/Atlas access, TLS, backups/restore, transaction sizing, lookup-heavy report performance and load/failover. Provision real SMS/maps/push credentials and test live Redis/Channels/Celery/device behavior. MongoDB has no relational FK enforcement or SQL savepoints; the application deliberately uses supported services/transaction boundaries and import validation. No claim of production readiness or live-data cutover is made.

## File inventory

The following source/configuration/documentation files were changed or added for this migration; Python bytecode, local test storage and logs are omitted.
- `Backend/.dockerignore`
- `Backend/.env.example`
- `Backend/.gitignore`
- `Backend/Dockerfile`
- `Backend/README.md`
- `Backend/accounts/api/resources.py`
- `Backend/accounts/api/views.py`
- `Backend/accounts/authentication.py`
- `Backend/accounts/models.py`
- `Backend/accounts/services/authentication.py`
- `Backend/core/admin_resources.py`
- `Backend/core/api_urls.py`
- `Backend/core/apps.py`
- `Backend/core/checks.py`
- `Backend/core/contracts.py`
- `Backend/core/filters.py`
- `Backend/core/identifiers.py`
- `Backend/core/management/__init__.py`
- `Backend/core/management/commands/__init__.py`
- `Backend/core/management/commands/export_legacy_mysql.py`
- `Backend/core/management/commands/import_legacy_snapshot.py`
- `Backend/core/models.py`
- `Backend/core/schema.py`
- `Backend/core/services/administration.py`
- `Backend/core/services/transfer.py`
- `Backend/core/transactions.py`
- `Backend/core/views.py`
- `Backend/docker-compose.yml`
- `Backend/docs/api-integration-guide.md`
- `Backend/docs/mongodb-completion-report.md`
- `Backend/docs/mongodb-migration-plan.md`
- `Backend/docs/mongodb.md`
- `Backend/docs/openapi.yaml`
- `Backend/docs/websockets.md`
- `Backend/drivers/api/resources.py`
- `Backend/drivers/api/urls.py`
- `Backend/drivers/api/views.py`
- `Backend/drivers/models.py`
- `Backend/drivers/services/eligibility.py`
- `Backend/drivers/services/matching.py`
- `Backend/drivers/services/onboarding.py`
- `Backend/mongo_migrations/__init__.py`
- `Backend/mongo_migrations/accounts/0001_initial.py`
- `Backend/mongo_migrations/accounts/__init__.py`
- `Backend/mongo_migrations/admin/0001_initial.py`
- `Backend/mongo_migrations/admin/__init__.py`
- `Backend/mongo_migrations/auth/0001_initial.py`
- `Backend/mongo_migrations/auth/__init__.py`
- `Backend/mongo_migrations/contenttypes/0001_initial.py`
- `Backend/mongo_migrations/contenttypes/__init__.py`
- `Backend/mongo_migrations/core/0001_initial.py`
- `Backend/mongo_migrations/core/__init__.py`
- `Backend/mongo_migrations/drivers/0001_initial.py`
- `Backend/mongo_migrations/drivers/0002_driverapplication_location.py`
- `Backend/mongo_migrations/drivers/0003_location_2dsphere.py`
- `Backend/mongo_migrations/drivers/__init__.py`
- `Backend/mongo_migrations/notifications/0001_initial.py`
- `Backend/mongo_migrations/notifications/__init__.py`
- `Backend/mongo_migrations/payments/0001_initial.py`
- `Backend/mongo_migrations/payments/0002_initial.py`
- `Backend/mongo_migrations/payments/0003_direct_preferences.py`
- `Backend/mongo_migrations/payments/__init__.py`
- `Backend/mongo_migrations/rides/0001_initial.py`
- `Backend/mongo_migrations/rides/__init__.py`
- `Backend/mongo_migrations/sessions/0001_initial.py`
- `Backend/mongo_migrations/sessions/__init__.py`
- `Backend/mongo_migrations/token_blacklist/0001_initial.py`
- `Backend/mongo_migrations/token_blacklist/__init__.py`
- `Backend/notifications/models.py`
- `Backend/payments/models.py`
- `Backend/requirements-legacy.txt`
- `Backend/requirements.txt`
- `Backend/rideflow/apps.py`
- `Backend/rideflow/legacy_mysql.py`
- `Backend/rideflow/mysql_testing.py`
- `Backend/rideflow/production.py`
- `Backend/rideflow/settings.py`
- `Backend/rideflow/testing.py`
- `Backend/rideflow/urls.py`
- `Backend/rides/api/serializers.py`
- `Backend/rides/api/urls.py`
- `Backend/rides/api/views.py`
- `Backend/rides/models.py`
- `Backend/rides/services/booking.py`
- `Backend/rides/services/lifecycle.py`
- `Backend/rides/tasks.py`
- `Backend/rides/tests/test_booking.py`
- `Backend/rides/tests/test_concurrency.py`
- `Backend/rides/tests/test_mongodb.py`
- `Backend/rides/tests/test_rest_resources.py`
