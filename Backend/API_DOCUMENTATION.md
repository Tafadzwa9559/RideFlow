# Trivia API documentation

The canonical REST API remains `/api/v1/`. Flutter and React contracts are described in the [integration guide](docs/api-integration-guide.md), [endpoint catalog](docs/endpoint-catalog.md) and [validated OpenAPI document](docs/openapi.yaml). The catalog identifies canonical operations and marked compatibility aliases.

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

## City-to-City, courier and scheduled bookings

Use the existing quote and booking endpoints. The fare quote binds the service, endpoints and ordered stops. Pricing uses the enabled USD configuration and the configured road routing provider.

| Operation | Contract |
|---|---|
| `POST /api/v1/fares/estimate/` | Accepts `Intercity` and `Courier` categories. Intercity requires a supported `city` on both endpoints and a point within 20 km of its city centre. Passenger rides can include up to three ordered `stops`. |
| `POST /api/v1/rides/` | Submit the same quote inputs and the proposed fare. Intercity accepts `passenger_count` from 1 to 6 and `luggage` of `none`, `small` or `large`. Courier requires `parcel` handover data and a permitted-goods declaration. |
| `PATCH /api/v1/rides/{id}/schedule/` | The passenger may edit `departure_at` while the ride is still scheduled and matching has yet to open. |
| `GET`, `POST /api/v1/drivers/me/service-preferences/` | View or change `accepts_intercity` and `accepts_courier`. Both default to false. Drivers still need valid approval, vehicle, availability and location. City-to-City matching also checks seat capacity. |
| `GET /api/v1/rides/{id}/parcel/` | Handover contacts and parcel details are available to the owner and assigned courier during an active delivery. The owner receives the handover code after pickup and shares it with the recipient. |
| `GET`, `POST /api/v1/rides/{id}/parcel/photo/` | Optional authenticated JPEG or PNG, at most 5 MiB. Only the owner can upload. The assigned courier can read the photo during an active delivery. |
| `POST /api/v1/rides/{id}/parcel/confirm/` | The assigned courier completes delivery with the eight-digit recipient code after confirming pickup. Five wrong attempts require a 15-minute wait. |

Scheduled rides accept `departure_at` more than 15 minutes and up to 30 days in advance. The app displays Africa/Harare time. The existing maintenance worker opens matching approximately 15 minutes before departure and emits `ride.matching_open` as a reminder. `ride.scheduled` and `ride.rescheduled` also use the existing notification transport. Current booking rules allow one non-terminal booking per passenger. The passenger confirms a driver by selecting an offer.

Before enabling the new service categories, apply the MongoDB migrations, configure an enabled pricing rule and covered zone for each service, and verify the actual routing provider across that coverage. Run Celery beat, the ride maintenance worker and the notification outbox. Parcel photos require the existing private storage configuration. Courier recipient handover is coordinated by the sender and courier. External recipient messaging requires a separate integration.

The app's emergency action opens the phone dialler with 112 or 999. [Zimbabwe Ministry of Health and Child Care emergency contacts](https://impilo.mohcc.gov.zw/welcome/emergency)
