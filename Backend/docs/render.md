# Render / Atlas deployment

This configuration is prepared for review and staging. It has not been deployed to Render or certified against Atlas. Do not apply a new Blueprint blindly to existing resources.

## Existing service and secrets

Use `Backend/render.yaml` as the Blueprint file path. Confirm the web service's **actual Render resource name**, region, service plan and custom domains in the dashboard before adopting it; `trivia-backend-bze2` is inferred from the existing documented hostname and must be reconciled. Update the existing service to retain `https://trivia-backend-bze2.onrender.com` and its custom domains. Never delete/recreate the existing service to apply this file. No deployment is performed by this repository change.

Create an external Render environment group `trivia-production-secrets` and attach it to web, worker and beat. Use identical secrets/database/media configuration for all three:

| Variable | Value/purpose |
|---|---|
| DJANGO_SECRET_KEY | Existing strong secret; retain it across services/redeploys |
| MONGODB_URI | Secret Atlas **triviacluster** SRV URI copied from Atlas Connect; never invent the DNS name |
| MONGODB_DATABASE | Existing database name, e.g. trivia |
| ALLOWED_HOSTS | Explicit public API hostname/custom domains, no scheme, no wildcard or localhost |
| CORS_ALLOWED_ORIGINS | Exact HTTPS React origins; Flutter native does not use CORS |
| DJANGO_CSRF_TRUSTED_ORIGINS | Exact HTTPS browser/admin origins |
| PRIVATE_STORAGE_BUCKET | Private shared S3-compatible bucket |
| PRIVATE_STORAGE_ENDPOINT | HTTPS endpoint for non-default S3 providers; omit for default endpoint |
| PRIVATE_STORAGE_REGION | Provider region |
| PRIVATE_STORAGE_ACCESS_KEY / PRIVATE_STORAGE_SECRET_KEY | Least-privilege object credentials, or workload identity where supported |
| SMS_PROVIDER | Installed adapter class; empty means OTP returns 503, not delivered |
| TRIVIA_EMAIL_SIGNUP_VERIFICATION_ENABLED | Enable verification for newly created email signups after deploying the compatible Flutter build and verifying mail delivery |
| TRIVIA_RECOVERY_EMAIL_ENABLED | Enable the existing email password recovery endpoints |
| EMAIL_BACKEND | Django email backend class. Defaults to SMTP and can be replaced with an HTTPS provider adapter |
| EMAIL_HOST_USER / EMAIL_HOST_PASSWORD | Gmail SMTP account and app password when using Gmail. Store both in Render secrets |
| DEFAULT_FROM_EMAIL | Sender address. Defaults to the SMTP account |
| TRIVIA_GEOAPIFY_API_KEY | Server-side Geoapify project key for autocomplete, reverse geocoding and driving routes |
| TRIVIA_GEOAPIFY_DAILY_REQUEST_LIMIT | Optional shared daily upstream request limit, defaults to 2500 UTC. Long routes can consume multiple credits. Track credit usage in the Geoapify dashboard. |
| TRIVIA_ROUTING_URL / TRIVIA_GEOCODING_URL | Optional HTTPS overrides for existing OSRM and Nominatim-compatible services respectively. Clear either override to use Geoapify for that service. |
| PUSH_PROVIDER | Optional installed adapter; empty means no push delivery claim |

Add the Geoapify key to `trivia-production-secrets` (locally use `Backend/.env`).
Keep it out of Flutter builds. Search and reverse geocoding retain the shared
30/min per-user limit, and route and fare endpoints retain their own shared
30/min per-user limit. Valid geocodes are cached for 24 hours. Empty searches
and driving routes are cached for five minutes. Geoapify cache misses share
a Redis-backed five-per-second limit and a UTC daily request budget. Leave
existing pricing zones and fare rules in place and verify coverage for each
area where passengers can request rides.

### Email verification rollout

Render Free blocks outbound SMTP ports 25, 465, and 587. Gmail SMTP on port
587 requires a service with working outbound SMTP. An HTTPS email backend
is the alternative for Render Free. Configure delivery on the web service
for signup and on the Celery worker for recovery. Both use the shared
password-auth Redis connection and the same Django secret for code digests.

Apply the MongoDB account migration before enabling email signup verification.
Existing accounts keep their login policy. New pending signups require email
verification before password login and can resume by logging in with their
password. Test signup, resend, verification, and recovery against a staging
mailbox before enabling the flags in production. Recovery's generic HTTP 202
does not confirm account existence or message delivery.

The Blueprint supplies production settings, private storage class and internal Redis connections. Production rejects local OTP, non-Atlas URIs, insecure browser origins, wildcard/local hosts and filesystem-only storage. Never supply test variables on production services. The environment group is intentionally not generated with secret values.

## Atlas and private media

Use Atlas database credentials limited to Trivia's application database; give migration credentials separately controlled index/collection permissions. Restrict Atlas access lists to the Render outbound addresses for the actual region/services (or a supported private networking arrangement). Keep TLS verification enabled; never allow 0.0.0.0/0 for convenience. Confirm Atlas UI identifies **triviacluster**, enable backups/PITR as supported, rehearse restore and alert on connections/storage/transaction conflicts. The application can validate the URI format/topology, not the human-readable cluster identity or Atlas access-list policy.

Private storage must block public access, use encryption at rest and HTTPS transport, restrict credentials to the required prefix/bucket, and have a documented retention/restore policy. Driver uploads and avatars retain existing object names. Copy existing private files to the same keys and verify counts/checksums **before switching storage**. File upload/database transactions are not distributed transactions; monitor/reconcile orphan objects after failures. The application never returns storage URLs and streams documents only through authorized retrieval APIs. Local files remain untouched.

## Release sequence

1. Rehearse on a separate Atlas staging database with synthetic data. Run destructive tests **only** on a loopback replica set; the test settings reject Atlas/remote URIs.
2. Review BACKEND_AUDIT.md and the additive migrations. Snapshot the existing database/media before rollout. Do not run legacy SQL export/import for an already MongoDB-native database.
3. Validate the Blueprint with Render CLI/API and reconcile existing service properties. The web pre-deploy command runs deployment/database checks and supported migrations. Build collects static files with WhiteNoise.
4. Roll out matching web and Celery worker revisions, then a **single** beat instance. Use `celery -A rideflow inspect ping` to confirm workers. Keep beat singleton during deploys; duplicate task notifications deduplicate by event ID where supported.
5. Verify `/health/` (process liveness), `/ready/` (MongoDB replica topology, Redis, live Celery worker), JWT/OTP, admin, protected docs and authenticated `wss://.../ws/v1/notifications/`. Run a real device synthetic ride, provider deliveries and reconnection tests before admitting traffic.
6. Monitor pending outbox age, task retries/failures, Atlas query plans, transaction retries, HTTP p95/p99, Redis memory/latency and stale-driver ratios. Alert on dependency readiness and failed releases.

Start commands from Backend (after installing requirements-storage.txt):

```bash
python manage.py check --deploy --database default
python manage.py migrate --noinput
python manage.py collectstatic --noinput
daphne -b 0.0.0.0 -p "$PORT" --proxy-headers rideflow.asgi:application
celery -A rideflow worker --loglevel=INFO --concurrency=2
celery -A rideflow beat --loglevel=INFO --schedule=/tmp/trivia-celerybeat
```

Each long-running command is a separate service. Daphne is ASGI; a WSGI-only Gunicorn process would not serve Channels sockets. Render must strip untrusted forwarded headers before trusted proxy mode is enabled. Public health responses deliberately omit dependency errors and credentials.

## Recovery and capacity

The initial shared Redis uses `noeviction` to protect queued jobs and rate-limit counters. A full instance will reject writes; monitor memory and separate cache/realtime/broker instances as traffic requires. Outbox is at least once; clients deduplicate event IDs and resync authoritative state over REST. SMS dispatch remains synchronous; leave `SMS_PROVIDER` unset until an adapter is authorized. OTP requests return 503 while SMS is unavailable.

### Redis setup and verification

1. In the Render Dashboard, check for an existing Key Value instance in the backend's workspace and region. Reuse it if it has capacity, supports Lua `EVAL`, and will not evict authentication counters or queue data. Otherwise create **New → Key Value**, choose the backend's region, and select `noeviction`. Leave external access disabled. Confirm the plan and cost before creating anything; the Blueprint selects the paid `256mb` plan and also declares two separate workers.
2. Copy the **Internal URL** from the instance's Connect menu into the web, worker and beat environment settings. Use Blueprint `fromService` references if adopting the managed Blueprint. Set `REDIS_URL` for Channels; set `CACHE_REDIS_URL` for Django cache and password authentication; set `CELERY_BROKER_URL` for the worker/beat broker. The last two default to `REDIS_URL` in production. Use the same URL if sharing one instance. Enable internal authentication for a new instance; for an existing instance, follow Render's authenticated URL migration procedure and coordinate the restart with all consumers. Never print URLs in deploy logs or place them in source control.
3. The clients support `rediss://` with certificate and hostname verification. Use a provider URL with no query or fragment, and specify a path database only if supported. The default database is sufficient: Channels, cache and Celery use `trivia:channels`, `trivia:cache` and `trivia:celery:` prefixes; existing password counters and reset state keep their existing keys. Keep `CACHE_REDIS_URL` on the existing auth Redis through the rollout to preserve outstanding rate windows and reset state.
4. In staging, run `python manage.py check_redis_services --worker` with deployed settings. Omit `--worker` if none is deployed. The command checks Redis PING, auth Lua, cache writes and reads, a Channels round trip, and a disposable rate-limit counter. Then test login and refresh with synthetic staging accounts, including wrong/unknown credentials and HTTP 429. Check OTP returns 503 with SMS unset. Verify `/health/`, `/ready/` where a Celery worker is required, and an authenticated WebSocket round trip.
5. Coordinate web/worker/beat deployment. The Celery prefix changes queue keys: pause beat and producers and drain the old queue before switching all three; an old worker cannot see the new queue. Expect existing WebSockets to reconnect and caches to warm. On rollback, drain the new queue first or retain a matching worker to finish it, then restore the prior revision and coordinated environment configuration. Keep both Redis namespaces intact; never flush Redis.

Celery prefetch is 1, retries bounded where implemented, soft/hard task limits 240/300 seconds, visibility timeout 600 seconds. Worker graceful shutdown is 300 seconds; capacity-test large maintenance batches before increasing limits. Beat schedule storage is ephemeral, so restarts may repeat ticks. Database-backed idempotency remains essential.

Rollback application code with additive indexes retained. Do not drop collections/indexes as a rollback shortcut. Do not roll back to the old SQL revision against MongoDB. Stop intake during any required data repair; reconcile active assignments and outbox, then verify a synthetic trip.

Sources: [Render Blueprint reference](https://render.com/docs/blueprint-spec), [Django MongoDB indexes](https://www.mongodb.com/docs/languages/python/django-mongodb/v5.2/model-data/indexes/), [private S3 storage options](https://django-storages.readthedocs.io/en/latest/backends/amazon-S3.html).

### Follow-up release: notification receipts

Apply `notifications.0002_notification_push_receipts` before deploying the updated notification worker. It initializes an internal empty receipt map on existing notification documents; review collection size and rehearse migration duration on staging. Keep any in-flight older workers drained during the transition. An adapter must deduplicate acceptance using event ID and destination device, raise `TransientPushError` for retryable failures, and handle permanently invalid tokens explicitly. Five retries with jitter and a 300-second maximum backoff are configured. A receipt means the adapter returned successfully, not that a handset received/read a message.
