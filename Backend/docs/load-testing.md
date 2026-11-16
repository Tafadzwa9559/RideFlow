# Staging reliability and load exercises

No capacity measurements or production-readiness claims are implied by local regression tests. Use synthetic accounts/data in an isolated staging Atlas database, separate Redis/services and configured provider sandboxes. Never run load tooling against production without an operational test window.

1. Baseline 10, then 50, then 100 simultaneous synthetic clients: quote -> idempotent ride creation -> matching -> counteroffers -> selection -> arrive/start/complete -> rating/history. Retain EcoCash preference, note and agreed fare assertions. Reuse each booking key on retry and submit competing acceptance requests. Assert one active assignment per driver/passenger/ride.
2. Run 1,000 synthetic online drivers over several service zones; update positions no faster than DRIVER_LOCATION_MIN_INTERVAL. Verify stale/offline/unapproved/document-expired drivers are excluded. Measure geoNear latency, dispatch batch time, CPU, Mongo writes and location-notification growth.
3. Establish authenticated socket clients; disconnect/reconnect, revoke tokens, suspend users, send duplicate events and recover via REST sequence/history. Verify unrelated users never receive private rides or raw coordinates.
4. Interrupt staging Redis briefly: writes already committed must remain authoritative; readiness should return 503, outbox must recover without losing events. Clients must deduplicate event IDs. Test a worker restart during push delivery and verify provider idempotency.
5. Exercise Atlas transient transaction failures/stepdown only in a suitable disposable cluster; measure retries and validate no duplicate assignment. Simulate uncertain commits and provider timeouts. Never repeat a command body on an unknown commit result.
6. Interrupt workers/beat and resume: overdue rides/offers expire, fresh drivers stop receiving expired requests, document alerts deduplicate, location retention runs. Check queue age, failures and task-limit behavior on large batches.
7. Collect p50/p95/p99 HTTP and socket latency, error rate by type, Atlas docs examined/returned, transaction conflicts, connections, outbox age, queue depth, Redis memory/latency and stale-driver ratio. Choose acceptance thresholds with operations before testing; do not infer capacity from test-suite timing.

Read-only index inventory and representative history query plan:

```bash
python manage.py mongodb_index_report --explain
```

The command prints index names and plan stages only, with a synthetic passenger ID. For real staging query shapes, use Atlas profiler/explain with authorized access; compare history, pending-offer expiry and geoNear plans on realistic data. Reassess each added index against write cost before adding more. Autoscale web/workers separately; keep beat singleton. Split broker/cache/realtime Redis when measured contention or memory requires it.
