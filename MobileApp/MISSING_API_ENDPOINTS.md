# Missing APIs and deployment blockers

No new Django APIs were created. Existing supported actions use Backend/docs/openapi.yaml and actual handlers; the deployed schema could not be fetched anonymously (302 to staff login).

| Requirement | Gap / safe behavior | Expected backend contract |
|---|---|---|
| Live schema parity | Production schema requires a staff session; local specification is used, deployed parity unverified | Authenticated schema export from the deployed release, supplied through an approved secure workflow |
| Full live integration | `/health/` 200, `/ready/` 503, unauthenticated current-user request 401 | Restore dependency readiness; provision safe passenger/driver accounts and configured SMS/routing/pricing for acceptance testing |
| Assigned driver summary after app restart | Ride response contains assigned_driver_id but no driver/vehicle summary or accepted offer ID. The selected offer is shown only when obtained from the server during this session; otherwise details are unavailable | Extend participant-owned ride detail with verified driver display name, rating, vehicle/plate and/or selected_offer_id. Never expose unrelated drivers or documents |
| Account deletion | No documented deletion-request operation. Action disabled; no fabricated submission | Authenticated create/status endpoint, idempotency, retention explanation and processing status |
| DOB / national ID text | No matching driver application fields; those unpersisted text inputs removed. Identity documents still use requirement-driven uploads | Define validated private fields only if product/compliance requirements demand storing them |
| Durable partial onboarding drafts | Application draft/documents are server-backed at submission; in-progress screen entries remain local UI state and are not claimed to be saved | Optional explicit partial draft contract, including expiry metadata and safe resume behavior; current complete draft API remains usable |
| Push delivery | In-app notifications use real REST/WS; handset push provider/device permission integration not verified | Provider configuration and device-token registration acceptance, APNs/FCM credentials, actual-device tests |
| Payment transactions/payouts | Trivia intentionally has no payment gateway. Earnings show completed agreed fares, not verified transactions/net commission/payouts | No payment API requested; preserve direct Cash/EcoCash/OneMoney preferences in USD |

Native Android/iOS GPS, WSS reconnect/Origin handling, document uploads and release signing require device/staging acceptance. No credentials or backend secrets belong in Flutter or reports.
