# Trivia backend audit

Audit baseline: existing Django 5.2.19 / Python 3.12 application; official MongoDB backend 5.2.4 and PyMongo 4.20.0. Scope: Backend only. No production records changed during this audit.

## Existing working implementation

Reviewed app models, migration graphs, API serializers/views/URLs/permissions, services, authentication, consumers, tasks, settings, tests and integration documentation. Existing accounts, drivers, rides, payments (informational preferences), notifications and core apps already provide:

- OTP identity, JWT rotation/revocation, normalized phones, profile/preferences, device registration and Django permission groups.
- Driver onboarding, private image validation/retrieval, document and licence expiry eligibility, vehicle ownership and audited administrative review.
- Configurable service areas, road-routing adapter, USD quote snapshots, negotiated offers, offline payment preference and passenger notes.
- Strict ride lifecycle, idempotent booking, MongoDB transaction retries and shared operation fences, unique active driver/passenger/ride assignments.
- GeoJSON/2dsphere nearby-driver search, freshness checks, interval-limited location updates, authorized Channels subscriptions and REST recovery.
- Ratings, history, earnings summaries, safety/support, notifications, outbox, Celery expiry/retention, admin APIs and protected Swagger.
- 154 canonical REST operations plus 10 documented compatibility aliases. Existing ObjectId and UUID contracts are retained.

Baseline verification: previous MongoDB migration suite passed 70 tests including real replica-set races; schema generation and deployment checks passed. This is local evidence, not an Atlas or Render deployment certification.

## Findings and priorities

### P0: deployment and security

1. No Backend-owned Render blueprint or deployment runbook. Web, independent worker and singleton beat must be configured separately. Existing production URL must be preserved by updating the existing web service.
2. Production settings prohibit local OTP but do not require an Atlas SRV URI, explicit public hosts/origins or durable shared private media. Local FileSystemStorage is unsuitable for disposable Render instances.
3. Test settings accept a configurable MongoDB URI and only check the test name. An Atlas URI must be rejected before the test runner can create/drop databases.
4. Password authentication is Django admin only; mobile authentication is passwordless OTP. No verified email/reset provider is implemented. Do not add a second identity system or claim email delivery.
5. SMS, road routing, geocoding and push are adapter/configuration boundaries. Actual provider delivery and Atlas cluster identity/network policy cannot be certified from local tests.

### P1: database and operations

6. Ride history, assigned-driver state, searching expiry and pending-offer maintenance need compound indexes matching current filters/sorts. Existing uniqueness and 2dsphere indexes must remain intact.
7. OTP cleanup scans expiration without an index. An expiration index is safe; TTL deletion needs explicit retention policy and cannot replace authorization checks.
8. Temporary GPS retention exists; other notification/audit growth needs an operator-approved retention policy. Never TTL-delete rides, verification documents, financial snapshots or audit records by default.
9. Document eligibility rejects expired documents, but advance document-expiry notifications are missing.
10. Push delivery is at least once; provider idempotency is required for duplicates across worker crashes. Outbox Redis failures retry, but external provider error taxonomies are adapter-specific.
11. Readiness checks MongoDB/Redis/Celery; worker ping on every probe has overhead. Liveness is suitable for Render process health; readiness is suitable for external dependency monitoring.

### P2: integration and scale

12. Support staff can use existing granular Django permissions; no automatic broad support role should expose private documents. Provision groups explicitly.
13. Existing GPS updates are interval limited and persist active-trip history. Benchmark geospatial dispatch, transaction conflicts, worker lag and serialization on representative staging data before capacity claims.
14. No live Render, Atlas query profiler, distributed Redis failure or external push/SMS/route-provider acceptance evidence is available. Provide repeatable staging exercises and report these as outstanding.

## Controlled implementation sequence

1. Add production configuration validation, durable shared private-media support, and local-only destructive-test protection.
2. Add only query-driven compound indexes through additive MongoDB migrations.
3. Add bounded retryable document-expiry alerts using deterministic event IDs.
4. Add Render configuration, environment/deployment/API documentation and operational verification commands.
5. Run isolated replica-set tests, migration drift/system checks and schema validation. Report exact results and remaining external requirements.

No existing collection will be dropped; historical SQL files remain inert migration artifacts, not configured application databases. Atlas `triviacluster` must be selected through the secret connection URI; no credentials or invented cluster address will be committed.

## Verification findings addressed during implementation

- Three existing views (ride sync, driver decline and offer PATCH) lacked typed OpenAPI contracts: strict schema export reported 11 errors across those views. Added contracts; the generated catalog now covers 157 canonical operations plus 10 aliases.
- Offer PATCH used an undefined Decimal, wrote outside ride/driver transaction guards, bypassed fare limits and reset omitted notes. Moved updates into a guarded transactional service, enforced fare/state/eligibility/ownership and preserved omitted values. Added HTTP and real concurrent edit-versus-selection regression tests.
- PrivateStorage's inherited migration serialization needed preserving when switching from filesystem inheritance to delegated Django storage; explicit deconstruction preserves the migration identity without a file-field schema change.

- HTTP regression tests also revealed that an earlier GET-only offer route shadowed PATCH and returned 405. The canonical offer detail view now shares the guarded update handler while preserving GET.

## Follow-up audit: session rotation and background delivery

The repeated enhancement review preserved all previous changes and identified two additional priorities:

- Refresh rotation checks revocation outside the user/refresh-token transaction guards. Concurrent rotation and logout need the same serialization guarantees as other sensitive commands.
- Notification retry declarations catch Python ConnectionError/OSError, whereas redis-py raises its own exception classes. MongoDB/broker transient errors also need bounded retry coverage. Push retry delivery currently has no persisted per-device success marker, so a successful device can receive repeated sends when a later device fails.

Next changes: guard refresh rotation against replay/logout, explicitly handle actual transport exceptions, record per-device push acceptance for retry deduplication, and test outage/retry behavior on isolated services. Provider acceptance remains distinct from confirmed device delivery.

Follow-up implementation: refresh rotation now uses user/JTI guards, and actual Redis/broker/MongoDB transient error classes have bounded retries. Push acceptance receipts use destination-token hashes and the model's prepared UUID key/active MongoDB session. They reduce sequential retry duplicates without claiming exactly-once or handset delivery. A configured MongoDB connectivity/topology check passed read-only; cluster identity/network policy and live provider delivery remain operator acceptance items.

Final follow-up verification: 85 tests passed (0 failed/skipped), including 11 replica-set concurrency scenarios; strict schema, drift, migration and database checks passed. See the implementation report for exact scope and outstanding external acceptance work.
