# API integration matrix

Origin: `https://trivia-backend-bze2.onrender.com`; prefix `/api/v1/`. All rows use JWT except OTP. Contracts checked against the complete repository OpenAPI and implemented handlers; live schema fetch is staff-protected. “Connected” describes code wiring, not a verified production user journey.

| Screen / feature | Method | Exact path | Auth | Status |
|---|---|---|---|---|
| Phone login/register | POST | auth/otp/request/ | Public | Connected; client contract tested; real SMS unverified |
| OTP verification | POST | auth/otp/verify/ | Public | Connected; server-issued tokens stored securely; contract tested |
| Session refresh | POST | auth/token/refresh/ | Refresh token | Connected; concurrent 401 single-flight contract tested |
| Logout | POST | auth/logout/ | JWT | Connected; credentials cleared locally; server revokes sessions |
| Current profile | GET, PATCH | users/me/ | JWT | Connected; real driver_status determines approval |
| Location search | GET | places/?q=... | JWT | Connected; no sample landmarks |
| Fare estimate | POST | fares/estimate/ | JWT | Connected; backend road distance/duration/limits; contract tested |
| Payment options | GET | payments/methods/ | JWT | Connected; booking uses enabled backend preferences |
| Create ride | POST | rides/ | JWT | Connected; quote, UUID idempotency key, fare, offline preference, note |
| Ride list/history | GET | rides/?page=... | JWT | Connected; own visible rides, empty state and load-more |
| Active ride | GET | rides/active/ | JWT | Connected; null means no active ride |
| Authorized tracking | GET | rides/{uuid}/tracking/ | JWT | Connected; actual decimal GPS/time; no simulated movement |
| Offers | GET, POST | rides/{uuid}/offers/ | JWT | Connected; server offers and real fare proposals |
| Passenger choice | POST | rides/{uuid}/accept/ | JWT | Connected; real offer ID; confirmation only after success |
| Driver lifecycle/cancellation | POST | rides/{uuid}/status/ | JWT | Connected; participant/driver enforcement by server |
| Driver requirements | GET | drivers/document-requirements/ | JWT | Connected; required scope/expiry metadata |
| Driver application | GET, PATCH | drivers/applications/me/ | JWT | Connected; actual status and legal/licence/vehicle draft |
| Driver documents | POST multipart | drivers/applications/me/documents/ | JWT | Connected; decoded JPEG/PNG size/expiry validated by backend |
| Vehicle lookup | GET | drivers/me/vehicles/ | JWT | Connected; owner fleet ID used for documents |
| Vehicle documents | POST multipart | drivers/me/vehicles/{objectid}/documents/ | JWT | Connected; requirement-driven scope |
| Submit verification | POST | drivers/applications/me/submit/ | JWT | Connected; no self-approval or local verified flag |
| Driver availability | POST | driver/availability/ | JWT | Connected; confirmation read before UI updates |
| Availability read | GET | drivers/me/availability/ | JWT | Connected |
| Device GPS | POST | drivers/me/location/ (initial compatibility path driver/location/) | JWT | Connected; real permission/GPS, throttled writes and freshness heartbeat; hardware unverified |
| Eligible driver requests | GET | driver/requests/ | JWT | Connected; backend eligibility; manual refresh/realtime reconciliation |
| Decline request | POST | rides/{uuid}/driver-request-decline/ | JWT | Connected; remove only after server acknowledgement |
| Driver earnings | GET | drivers/me/earnings/?period=day,week,month | JWT | Connected; actual agreed_fares/completed_trips only |
| Notifications | GET | notifications/?page=... | JWT | Connected; real envelopes; empty state/load-more |
| Settings | GET, PATCH | users/me/preferences/ | JWT | Connected; server push_notifications value, unavailable/retry state |
| Saved places | GET, POST | users/me/saved-places/ | JWT | Connected; no in-memory backend substitute |
| Review | POST | rides/{uuid}/ratings/ | JWT | Connected; score/comment mapped to documented fields |
| Ride complaint | POST | rides/{uuid}/report/ | JWT | Connected |
| Support/safety | POST | support/tickets/ | JWT | Connected; message/category; no fake agent response |
| Emergency contact | POST | users/me/emergency-contacts/ | JWT | Connected; name/phone |
| Direct-payment history | GET | payments/history/ | JWT | Connected; informational records only |
| Realtime notifications | WSS | /ws/v1/notifications/ | First frame `{token: accessJWT}` | Documented `connection.ready`, ping/pong and REST reconciliation; live WSS unverified |

No passenger/driver screen calls administrative APIs. Unsupported deletion/driver-summary gaps are recorded in MISSING_API_ENDPOINTS.md.
