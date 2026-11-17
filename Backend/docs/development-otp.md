# Local development OTP

The fixed code `123456` is available only with `rideflow.development` settings,
`DEBUG=True`, a loopback MongoDB URI, a separate `trivia_dev_*` database and an
explicit E.164 phone allowlist. It is disabled by default. Do not enable it on
Render or any public backend. No deployment changes are required or included.

## Backend setup

Use a local MongoDB replica set as described in [MongoDB operations](mongodb.md).
The default development URI is
`mongodb://127.0.0.1:27018/?replicaSet=trivia-rs`; point it at your local replica
set if its port/name differ. The URI must use a loopback hostname and contain
no database path. The database name must differ from `MONGODB_DATABASE`.
Public/wildcard allowed hosts and Render deployment markers are rejected. Use a new database; do not copy production users or credentials.

From `Backend`, with the existing dependencies installed:

```bash
export DJANGO_SETTINGS_MODULE=rideflow.development
export TRIVIA_DEV_SECRET_KEY="$(.venv/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))')"
export TRIVIA_DEV_MONGODB_URI='mongodb://127.0.0.1:27018/?replicaSet=trivia-rs'
export TRIVIA_DEV_MONGODB_DATABASE=trivia_dev_local
export TRIVIA_TEST_OTP_ENABLED=true
# Replace with phone numbers explicitly authorized for this development database.
export TRIVIA_TEST_OTP_PHONES='+263771234567,+263771234568'
.venv/bin/python manage.py check
.venv/bin/python manage.py migrate
.venv/bin/daphne -b 127.0.0.1 -p 8000 rideflow.asgi:application
```

The phone numbers above are examples, not provisioned accounts. Request a code
through the app before entering `123456`. The existing endpoints create a normal
non-staff account on first verification. Profile and driver registration continue
through the real development APIs. Drivers still require approval, valid documents
and vehicle/location eligibility before operating; OTP never grants approval.

The development signing secret must have at least 32 characters and differ from
`DJANGO_SECRET_KEY`. Development settings use local media, an in-process cache and
Channels layer, eager Celery tasks and no push provider to avoid production
brokers/storage. This configuration is for one local backend process.

## Flutter connection

From `MobileApp`, start an Android emulator and run:

```bash
bash tool/run-development.sh
```

The helper enables `TRIVIA_DEVELOPMENT_BUILD=true` and selects
`http://10.0.2.2:8000`, the emulator's route to the host. For a USB Android device,
use `adb reverse tcp:8000 tcp:8000` and:

```bash
TRIVIA_DEV_API_ORIGIN=http://127.0.0.1:8000 bash tool/run-development.sh
```

Only local origins are accepted in this mode. Profile/release builds reject the
development flag. The Android debug network configuration allows HTTP only for
localhost, 127.0.0.1 and 10.0.2.2; the release manifest retains its HTTPS-only policy.
Default builds retain the public HTTPS backend and contain no client-side OTP
acceptance or mock repository. Native HTTP/iOS transport and real devices still
require platform acceptance; no iOS transport exceptions were added.

## Disable and remove

Set `TRIVIA_TEST_OTP_ENABLED=false` and restart the backend to restore the existing
SMS provider flow. Configure `SMS_PROVIDER` as usual; no provider is bundled by
this change. Remove the development flag when running the Flutter application.

Test challenges carry a digest prefix and cannot verify in normal SMS mode.
Test-issued JWTs use the normal signer/session version plus a provenance claim;
they are rejected if test mode is disabled, the number is removed from the
allowlist, or the account becomes staff/superuser/inactive. Production uses a
separate signing key and rejects activation of test mode. Staff/superusers and
inactive accounts are excluded at request, verification, access and refresh.

No OTP code is returned by the API or written to logs. Cooldowns, expiry,
attempt limits, challenge consumption, token rotation/revocation and normal
permissions remain enforced. Database schemas and API response fields are unchanged.

To remove the temporary feature later, remove the development settings/guard and
conditional OTP/session branches together; keep the normal SMS implementation.
Discard the isolated development database and local signing secret separately.

## Verification — 17 November 2026

- Account and driver regression suite: 24 tests passed.
- Final development OTP security suite: 16 tests passed, including actual
  production-settings startup refusal and new-driver registration through the API.
- Flutter regression suite: 51 tests passed. The final three configuration cases
  also passed separately with the default build and with
  `--dart-define=TRIVIA_DEVELOPMENT_BUILD=true`.
- Flutter analysis: no issues. Dart formatting, shell syntax, Python syntax,
  Android XML parsing and diff whitespace checks passed.
- Dedicated development settings passed `manage.py check --database default`
  against a disposable local MongoDB replica set.

Backend tests used only `test_trivia_dev_otp` on a newly created loopback replica
set, with no production connection or SMS delivery. Initial test assertions were
corrected for DRF's HTTP 403 response on the unauthenticated OTP views and Django's
nested settings-module override behavior. The final security run passed.

No production environment file, credentials, schema or deployment was modified.
Physical-device and new Android/iOS binary verification were not performed for
this change. Earlier mobile cleanup validation is a separate record.
