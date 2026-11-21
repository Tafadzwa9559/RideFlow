# Trivia WebSocket protocol — version 1

REST is authoritative for booking, offer selection and trip commands. WebSockets deliver committed updates only. Configure HTTPS/WSS and an allowed Origin. No bearer tokens belong in URLs.

| Path | Authorization |
|---|---|
| `/ws/v1/notifications/` | Authenticated user's own inbox |
| `/ws/v1/passenger/rides/{ride_id}/` | Passenger or assigned driver on that ride |
| `/ws/v1/driver/rides/{ride_id}/` | Passenger or assigned driver on that ride |
| `/ws/v1/driver/requests/` | Approved, eligible, online driver with fresh location |

Native clients may send `Authorization: Bearer ACCESS_TOKEN`. Browser clients send `{"token":"ACCESS_TOKEN"}` as their first frame within five seconds after transport acceptance. No data subscriptions are established before authorization. Server replies `{"type":"connection.ready","schema_version":1}`. Send `{"type":"ping"}` for `{"type":"pong"}`. Commands use REST, not socket messages.

Close codes: 4400 unsupported input; 4401 missing/invalid/expired/revoked token; 4403 unauthorized room. Access-token expiry closes the connection. Refresh by REST then reconnect. Permission and session checks run during event delivery. Disconnect never cancels or completes a ride.

## Event envelope

```json
{
  "schema_version": 1,
  "event_id": "00000000-0000-4000-8000-000000000001",
  "type": "driver.assigned",
  "resource_id": "00000000-0000-4000-8000-000000000002",
  "timestamp": "2026-11-16T08:00:00Z",
  "sequence": 3,
  "payload": {"status": "assigned", "offer_id": "000000000000000000000012"}
}
```

These are illustrative values, never live trips.

| Event | Payload schema |
|---|---|
| `ride.created`, `ride.arriving`, `ride.arrived`, `ride.inProgress`, `ride.completed`, `ride.cancelled`, `ride.expired` | `{status: string}` |
| `ride.request` | `{ride_id: UUID, service: string}`; eligible driver retrieves the request through authorized REST |
| `ride.scheduled` | `{status: "scheduled"}` |
| `ride.rescheduled` | `{departure_at: ISO timestamp}` |
| `ride.matching_open` | `{status: "searching", departure_at: ISO timestamp}` |
| `offer.created`, `offer.declined`, `offer.withdrawn`, `offer.expired` | `{offer_id: 24-character ObjectId string}` |
| `driver.assigned` | `{status: "assigned", offer_id: 24-character ObjectId string}` |
| `driver.location` | `{latitude: decimal string, longitude: decimal string, at: ISO timestamp}` |
| `verification.updated` | `{status: draft\|submitted\|underReview\|approved\|rejected\|suspended}` |

`event_id` is globally unique. `resource_id` is the ride UUID for trip events, application ID as a string for verification. Trip `sequence` increases per ride; non-trip events use zero. Delivery is at least once: deduplicate event IDs, ignore already-applied sequences, detect gaps and recover using `GET /api/v1/rides/{id}/timeline/?after=N` (at most 200 items) and the authoritative ride snapshot. Read the last returned sequence to continue recovery. A gap does not authorize replaying a critical command with a new idempotency key.

Notification outbox persistence survives Redis outages, but publication is not device acknowledgement. GET the paginated notification inbox after reconnect. Driver request notifications contain the request identifier and service category. City-to-City and courier ride event payloads include `service` so clients can display the corresponding status. Handover contacts, parcel images and delivery codes are available through the authenticated parcel API. Other offering drivers receive closure/assignment events without subsequent GPS; location reaches only ride participants. Private documents and passenger notes never appear in push notifications. GPS older than configured retention is removed from location records/notifications and redacted from event payloads as `{redacted: true}`.
