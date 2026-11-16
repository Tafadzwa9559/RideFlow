# Trivia MongoDB migration and operations

This is the current database guide. Earlier MySQL implementation reports are historical verification records. The primary database is now MongoDB through **django-mongodb-backend 5.2.4 / PyMongo 4.20.0**, retaining **Django 5.2.19 / Python 3.12**. Redis, DRF, JWT, Django Channels, Celery, Daphne and all REST resource paths remain.

## Compatibility audit and implementation

The official backend does not support AutoField/BigAutoField, native SQL row locks or prefetch_related. Its transaction API is distinct from Django's native atomic handling; nested blocks have no savepoints and a replica set/sharded cluster is required. MongoDB timestamps have millisecond precision. Supported relationship lookups remain ORM-backed; joins can be expensive and should be monitored under load.

- Implicit entity keys use ObjectIdAutoField. Existing explicit UUIDs for rides, quotes and events and natural payment/requirement/category keys remain unchanged. ObjectIds appear as 24-character strings, never numeric IDs or `ObjectId(...)` JSON wrappers. HTTP path validation, DRF serialization, JSON snapshots, JWT identity validation and Swagger schemas reflect this necessary identifier change.
- Auth/admin/contenttypes have the documented MongoDB AppConfigs. The existing SimpleJWT blacklist models contain **explicit** BigAutoFields and check the literal installed-app name to enable blacklisting. A narrowly scoped, version-pinned initialization shim converts just these two fields to official ObjectIdAutoField, keeping the same app, models, JWT implementation and revocation behavior. Tests cover token record types, refresh/logout, sessions and non-superuser group permissions. No vendor package files are modified.
- A new `mongo_migrations` graph includes application and contrib schemas/indexes. Existing SQL migrations remain untouched in their original paths. New MongoDB databases receive the three direct-payment preferences but no operational service areas or fares. Optional `rideflow/legacy_mysql.py` remains a read-only export configuration; current MongoDB models must not run against the old SQL graph.
- `core.transactions` uses the official `django_mongodb_backend.transaction.atomic()` and its commit hooks. Shared per-resource write-guard documents force conflicting commands to abort stale snapshots. Guard writes, state updates, offer closure, assignments, events and notification outbox entries commit in the same transaction. Uniqueness on active ride/driver/passenger assignments remains an additional database guarantee.
- Only the outer command retries transient transaction failures, with bounded backoff. Unknown commit acknowledgements retry the same commit, never the command body. An unresolved outcome returns a machine-readable conflict and the client must retrieve state/reuse its idempotency key. No assigned response is returned before commit succeeds. No Redis lock replaces database correctness.
- GeoJSON driver `location` stores `{type:"Point", coordinates:[longitude,latitude]}` alongside existing validated coordinates. A `2dsphere` index and official MongoManager/raw_aggregate `$geoNear` query perform proximity discovery; approval, active vehicle, category, service area, fresh heartbeat and occupancy are rechecked. Haversine remains a secondary eligibility check, never fare routing. Existing configurable OSRM road distance still prices trips.
- SQL readiness queries were replaced by MongoDB ping/topology checks. Local-time earnings use Python calendar cutoffs. Existing date analytics use UTC truncation of Zimbabwe's UTC+02 offset, within the backend's supported UTC TruncDate subset. Unsupported SQL query methods are absent from application code.

Official references: [feature compatibility](https://www.mongodb.com/docs/languages/python/django-mongodb/v5.2/limitations-upcoming/), [connection configuration](https://www.mongodb.com/docs/languages/python/django-mongodb/v5.2/connect/), [contrib/AppConfig and migration setup](https://django-mongodb-backend.readthedocs.io/en/5.2.x/intro/configure/), [official transactions](https://www.mongodb.com/docs/languages/python/django-mongodb/v5.2/interact-data/transactions/).

## Local startup

MongoDB Community Server must be installed separately or supplied by Docker; no global system package was installed by this work. The application dependencies belong in the existing virtual environment.

```sh
cd Backend
python3.12 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env  # only for a new environment; preserve your existing secrets
```

Set `MONGODB_URI` and `MONGODB_DATABASE` in the environment or existing `.env`. Django reads `.env` without overwriting already exported variables. The existing DJANGO_SECRET_KEY is retained. Standard defaults:

```env
MONGODB_URI=mongodb://localhost:27017/?replicaSet=trivia-rs
MONGODB_DATABASE=trivia
```

An Atlas `mongodb+srv://` URI is supported in the same variable; keep credentials in the secret manager, TLS enabled and network access restricted. Supply the database via MONGODB_DATABASE; avoid embedding a conflicting database path in the URI. MongoDB write concern defaults to majority and retryable writes are enabled. Do not use a standalone server for Trivia commands.

For a local native replica set, in separate terminals:

```sh
mkdir -p .mongo-local
mongod --dbpath "$PWD/.mongo-local" --replSet trivia-rs --port 27017 --bind_ip 127.0.0.1
# Initialize once, using mongosh:
mongosh --port 27017 --eval 'rs.initiate({_id:"trivia-rs",members:[{_id:0,host:"localhost:27017"}]})'
redis-server
```

Alternatively `docker compose up --build` supplies an internal single-member replica set, initialization job, Redis, migration job, Daphne, worker and Beat. It is a **local development** composition with no public database/broker ports. Production should use a secured replica set/Atlas, not this unauthenticated development topology. The Docker definition was parsed but not built in this environment.

With the same environment in every application terminal:

```sh
.venv/bin/python manage.py check --database default
.venv/bin/python manage.py makemigrations --check --dry-run
.venv/bin/python manage.py migrate
.venv/bin/python manage.py createsuperuser
.venv/bin/daphne -b 127.0.0.1 -p 8000 rideflow.asgi:application
.venv/bin/celery -A rideflow worker --loglevel=INFO
.venv/bin/celery -A rideflow beat --loglevel=INFO --schedule=/tmp/trivia-beat
```

All MongoDB nodes advertised by the replica set must be resolvable from the app/worker hosts. For Docker-local clients use the compose network DNS; for native apps initialize advertised localhost addresses. Do not reuse Docker-internal member names from a host process.

## Existing data: rehearse, reconcile, then cut over

See the [controlled migration plan](mongodb-migration-plan.md). **No production/source data was imported or deleted.** Old MySQL and SQLite databases and all original SQL migration files remain. The new default settings do not constitute a completed live-data cutover.

The transfer tools are implemented and fixture-rehearsed:

```sh
# Optional on a controlled export host; not needed by the MongoDB runtime:
.venv/bin/pip install -r requirements-legacy.txt
# MYSQL_* / DB_* variables identify a read-only restored source.
.venv/bin/python manage.py export_legacy_mysql --output migration_exports/source.json
# Point the environment at a NEW isolated replica-set target and migrate it first.
.venv/bin/python manage.py migrate
.venv/bin/python manage.py import_legacy_snapshot --input migration_exports/source.json
# Explicit application only after reviewing the dry-run and exact target name:
.venv/bin/python manage.py import_legacy_snapshot --input migration_exports/source.json \
  --apply --target-database trivia_rehearsal
```

The exporter executes read-only raw SQL and creates a new mode-0600 snapshot without overwriting files. Stop source writers for a consistent final snapshot; a read-only connection alone is not a cross-table snapshot guarantee. The snapshot contains sensitive password hashes and personal data: protect and encrypt it. `migration_exports/` is excluded from version control and container builds.

The importer defaults to planning only, requires an exact configured target name for writes, rejects non-seed target data and mismatched source manifests, validates source references, deterministically maps legacy integer PK/FK/M2M keys, reconciles seeded content types/permissions, preserves password hashes and UUIDs, rewrites pricing/event/audit references, preserves Decimal amounts/UTC times/private-media paths, creates GeoJSON positions, and verifies imported content checksums and non-seed row counts. Imports are resumable for the same source snapshot; a verified target is rechecked rather than rewritten. A partially imported target stays marked `importing` and must never serve traffic.

Drivers start offline and need fresh heartbeats after transfer. Old sessions/refresh records are deliberately not copied; phone session versions advance. Existing JWTs with integer identities return 401 instead of a server error. Users/admins must sign in again. Private media must be backed up/copied separately and downloads verified. Index constraints can expose inconsistent source data; resolve those conflicts in the rehearsal, without deleting historical source records.

The automated rehearsal verifies representative MySQL-shaped user/group/permission records, ID/reference conversion, password preservation, checksums, safe reruns and refusal of dangling references/nonempty targets. A real production MySQL export/import and full source/media reconciliation still require the operator's snapshot and cutover window. Do not claim that fixture tests migrated actual customer data.

## Tests and documentation

`rideflow.testing` now uses a real MongoDB replica set (never SQLite or mongomock) with in-memory Channels/cache and local explicit SMS fixtures. Its default test database is `test_trivia_mongodb`, isolated from the application database. Override the connection/name when necessary:

```sh
MONGODB_TEST_URI='mongodb://localhost:27017/?replicaSet=trivia-rs' \
  DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py test accounts drivers rides core --noinput
DJANGO_SETTINGS_MODULE=rideflow.testing .venv/bin/python manage.py spectacular --file docs/openapi.yaml --validate
DJANGO_SETTINGS_MODULE=rideflow.production .venv/bin/python manage.py check --deploy
```

Do not run concurrent test suites against the same test database. Historical `mysql_testing.py` deliberately fails fast with current ObjectId models; use the old application revision for SQL rollback/testing. `/health/` is liveness; `/ready/` checks MongoDB/topology, Redis and a worker without exposing connection details.

Protected documentation paths remain `/api/schema/`, `/api/docs/`, `/api/redoc/`, `/api/websockets/`. The [API integration guide](api-integration-guide.md), [endpoint catalog](endpoint-catalog.md) and [WebSocket protocol](websockets.md) remain applicable with ObjectId strings replacing former integer IDs. JSON field names and ride UUID routes remain stable. Neither Flutter nor React was edited.

## Preserved product rules and launch work

USD only. Exactly EcoCash, OneMoney and Cash as informational direct-payment preferences. No platform fare charging, payment gateway, wallet, settlement, invented commission or verified receipt. Passenger-choice negotiation, admin-reviewed driver onboarding, actual routing, atomic selection, tracking, completion, history and ratings remain.

Production hardening still requires secured replicated MongoDB/Atlas, backups and restore drills, source-data/media rehearsal and cutover, appropriate connection/transaction limits, TLS ingress, real SMS/maps/push credentials, real Redis transport/failover tests, load tests and operator privacy/transport review. Foreign-key integrity is enforced by application services/import validation rather than relational database FK constraints. Preserve archival deletion policies and monitor lookup-heavy reports before increasing load.
