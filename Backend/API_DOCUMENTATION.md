# Trivia API documentation

The canonical REST API remains `/api/v1/`. Flutter and React contracts are described in the [integration guide](docs/api-integration-guide.md), [endpoint catalog](docs/endpoint-catalog.md) and [validated OpenAPI document](docs/openapi.yaml). There are 157 canonical operations and 10 marked compatibility aliases after documenting three already implemented operations; no endpoint has been removed by the operational enhancement.

- Swagger UI: `/api/docs/`
- Schema: `/api/schema/`
- ReDoc: `/api/redoc/`
- WebSocket specification: `/api/websockets/` and [event contracts](docs/websockets.md)
- Liveness: `/health/`; dependency readiness: `/ready/` (503 when dependencies fail)

In production, Swagger/schema/ReDoc use the existing Django staff-session login flow; DEBUG development permits those docs. The WebSocket documentation endpoint requires an administrator. API requests require Bearer JWT except explicitly documented OTP/public health operations. Do not place bearer tokens in WebSocket URLs. Authenticate sockets by Authorization header or first frame; subscriptions are checked against current user/ride ownership. On reconnect, deduplicate `event_id`, inspect sequence gaps and use REST ride detail/events/notifications to resynchronize.

## Preserved workflow and formats

1. Request/verify phone OTP; verification issues access and rotating refresh tokens. Mobile identity is passwordless. Django administrators retain Django password hashing/login. No second mobile password or email verification system is implied.
2. Driver submits personal/vehicle details and private verification images; authorized staff review. Only approved active drivers with valid documents, an approved vehicle and fresh online locations are dispatch eligible.
3. Passenger requests a road-distance quote, chooses a permitted proposed USD amount, Cash/EcoCash/OneMoney preference and optional notes, then books with a UUID idempotency key.
4. Eligible drivers accept the proposal or counteroffer. Passenger selects an offer; MongoDB transactions and unique active assignments arbitrate races.
5. Assigned driver marks arriving/arrived/start/complete. Trip completion is independent of digital payment verification. Ratings/history/earnings remain available.

Former integer IDs use **24-character ObjectId strings**; ride/quote/event UUIDs remain UUID strings. Money/cents, canonical lifecycle enums and pagination/error envelopes remain as documented in OpenAPI. Client-supplied IDs must be opaque strings. Existing integer-identity tokens require sign-in again after the MongoDB migration.

## Additional operational notification

`driver.document.expiry` is a metadata-only notification to the owning driver. It uses the existing notification/outbox transport and envelope:

```json
{
  "schema_version": 1,
  "event_id": "b0ddce76-b13e-51c0-9151-c613c340584b",
  "type": "driver.document.expiry",
  "resource_id": "507f1f77bcf86cd799439011",
  "timestamp": "2026-11-16T08:00:00+00:00",
  "sequence": 0,
  "payload": {
    "resource_type": "driver_document",
    "expires_on": "2026-11-20",
    "milestone": "7d"
  }
}
```

`resource_type`: `licence`, `driver_document`, `vehicle_document`. `milestone`: `30d`, `7d`, `expired`. Stable IDs deduplicate repeats for the same resource, expiry and milestone. The task checks a window from 30 days overdue through 30 days ahead. It emits no file paths, signed URLs or raw identity data. Clients should safely ignore unfamiliar event types. Existing ride event contracts are unchanged.

No new REST URLs were required. Existing `GET /rides/{id}/sync/`, `POST /rides/{id}/driver-request-decline/` and `PATCH /offers/{id}/` now have typed Swagger contracts. Offer PATCH accepts `fare_cents`, `note` and/or `pickup_minutes`; omitted fields are retained. It enforces ownership, current driver eligibility, fare bounds and pending/searching state under the same MongoDB guards as passenger acceptance. Accepted/agreed fares cannot be edited through this endpoint. Private document retrieval still streams through authenticated ownership/admin checks and returns no public storage URL. Provider-backed SMS, road routing and optional push require actual configured services; empty adapters never imply delivery success.

Deployment and external verification requirements: [Render guide](docs/render.md). Audit and remaining limitations: [BACKEND_AUDIT.md](BACKEND_AUDIT.md).

## Session and delivery reliability follow-up

Refresh-token rotation now runs under the same MongoDB user guard as logout, plus a guard for the refresh token ID. Simultaneous rotation of one token yields one successful rotation; replay is rejected. Logout invalidates access and refresh tokens even when a rotation races it. Request/response formats and endpoint URLs remain unchanged.

Notification delivery retries explicitly cover Redis, broker and transient MongoDB failures, with at most five Celery retries and a maximum backoff of 300 seconds. Internal per-device push receipts contain token hashes and adapter-acceptance timestamps; they are never included in public notification responses. Successful devices are skipped on sequential retries. Concurrent workers or a crash before recording acceptance still require adapter deduplication by event ID **and destination device**. These records do not verify handset arrival or offline fare payment.
