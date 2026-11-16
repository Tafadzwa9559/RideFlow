# Trivia API endpoint catalog

**154 distinct documented REST operations** (HTTP method + canonical path), plus 10 explicitly marked semantic aliases. Mobile/legacy compatibility aliases, documentation, health, HEAD and OPTIONS routes are excluded from the distinct total.

All entries below are connected to implemented handlers. `x-alias-of` in OpenAPI identifies exact semantic aliases so totals do not count the same behavior twice.

| API group | Distinct operations |
|---|---:|
| Admin Dashboard | 4 |
| Admin Drivers | 5 |
| Admin Pricing | 5 |
| Admin Reports | 4 |
| Admin Rides | 4 |
| Admin Verification | 5 |
| Administration | 14 |
| Authentication | 5 |
| Driver Applications | 9 |
| Drivers | 11 |
| Earnings | 3 |
| Locations | 9 |
| Notifications | 6 |
| Offers | 4 |
| Platform Configuration | 5 |
| Pricing | 3 |
| Ratings | 3 |
| Rides | 11 |
| Routes | 1 |
| Safety | 9 |
| Support | 6 |
| Tracking | 1 |
| Trips | 4 |
| Users | 9 |
| Vehicles | 10 |
| Verification | 4 |
| **Total** | **154** |

| Group | Method | Path | Alias of |
|---|---|---|---|
| Admin Dashboard | GET | `/api/v1/admin/dashboard/driver-analytics/` | — |
| Admin Dashboard | GET | `/api/v1/admin/dashboard/overview/` | — |
| Admin Dashboard | GET | `/api/v1/admin/dashboard/platform-activity/` | — |
| Admin Dashboard | GET | `/api/v1/admin/dashboard/ride-analytics/` | — |
| Admin Drivers | GET | `/api/v1/admin/drivers/` | — |
| Admin Drivers | GET | `/api/v1/admin/drivers/{id}/` | — |
| Admin Drivers | POST | `/api/v1/admin/drivers/{id}/reactivate/` | — |
| Admin Drivers | POST | `/api/v1/admin/drivers/{id}/review/` | — |
| Admin Drivers | POST | `/api/v1/admin/drivers/{id}/suspend/` | — |
| Admin Pricing | DELETE | `/api/v1/admin/pricing-rules/{id}/` | — |
| Admin Pricing | GET | `/api/v1/admin/pricing-rules/` | — |
| Admin Pricing | GET | `/api/v1/admin/pricing-rules/{id}/` | — |
| Admin Pricing | PATCH | `/api/v1/admin/pricing-rules/{id}/` | — |
| Admin Pricing | POST | `/api/v1/admin/pricing-rules/` | — |
| Admin Reports | GET | `/api/v1/admin/reports/drivers/` | — |
| Admin Reports | GET | `/api/v1/admin/reports/earnings/` | — |
| Admin Reports | GET | `/api/v1/admin/reports/passengers/` | — |
| Admin Reports | GET | `/api/v1/admin/reports/rides/` | — |
| Admin Rides | GET | `/api/v1/admin/rides/` | — |
| Admin Rides | GET | `/api/v1/admin/rides/{id}/` | — |
| Admin Rides | GET | `/api/v1/admin/rides/{id}/timeline/` | — |
| Admin Rides | POST | `/api/v1/admin/rides/{id}/cancel/` | — |
| Admin Verification | GET | `/api/v1/admin/driver-applications/` | — |
| Admin Verification | GET | `/api/v1/admin/driver-applications/{id}/` | — |
| Admin Verification | POST | `/api/v1/admin/driver-applications/{id}/approve/` | — |
| Admin Verification | POST | `/api/v1/admin/driver-applications/{id}/reject/` | — |
| Admin Verification | POST | `/api/v1/admin/driver-applications/{id}/request-changes/` | — |
| Administration | DELETE | `/api/v1/admin/document-requirements/{code}/` | — |
| Administration | GET | `/api/v1/admin/audit-logs/` | — |
| Administration | GET | `/api/v1/admin/audit-logs/{id}/` | — |
| Administration | GET | `/api/v1/admin/document-requirements/` | — |
| Administration | GET | `/api/v1/admin/document-requirements/{code}/` | — |
| Administration | GET | `/api/v1/admin/offers/` | — |
| Administration | GET | `/api/v1/admin/offers/{id}/` | — |
| Administration | GET | `/api/v1/admin/passengers/` | — |
| Administration | GET | `/api/v1/admin/passengers/{id}/` | — |
| Administration | PATCH | `/api/v1/admin/document-requirements/{code}/` | — |
| Administration | PATCH | `/api/v1/admin/passengers/{id}/` | — |
| Administration | POST | `/api/v1/admin/document-requirements/` | — |
| Administration | POST | `/api/v1/admin/passengers/{id}/reactivate/` | — |
| Administration | POST | `/api/v1/admin/passengers/{id}/suspend/` | — |
| Authentication | GET | `/api/v1/auth/me/` | — |
| Authentication | POST | `/api/v1/auth/logout-all/` | POST /api/v1/auth/logout/ |
| Authentication | POST | `/api/v1/auth/logout/` | — |
| Authentication | POST | `/api/v1/auth/otp/request/` | — |
| Authentication | POST | `/api/v1/auth/otp/resend/` | POST /api/v1/auth/otp/request/ |
| Authentication | POST | `/api/v1/auth/otp/verify/` | — |
| Authentication | POST | `/api/v1/auth/token/refresh/` | — |
| Driver Applications | DELETE | `/api/v1/drivers/applications/me/documents/{id}/` | — |
| Driver Applications | GET | `/api/v1/drivers/applications/me/` | — |
| Driver Applications | GET | `/api/v1/drivers/applications/me/documents/` | — |
| Driver Applications | GET | `/api/v1/drivers/applications/me/documents/{id}/` | — |
| Driver Applications | GET | `/api/v1/drivers/applications/me/review-history/` | — |
| Driver Applications | PATCH | `/api/v1/drivers/applications/me/` | — |
| Driver Applications | POST | `/api/v1/drivers/applications/` | — |
| Driver Applications | POST | `/api/v1/drivers/applications/me/` | POST /api/v1/drivers/applications/ |
| Driver Applications | POST | `/api/v1/drivers/applications/me/documents/` | — |
| Driver Applications | POST | `/api/v1/drivers/applications/me/submit/` | — |
| Drivers | GET | `/api/v1/drivers/document-requirements/` | — |
| Drivers | GET | `/api/v1/drivers/me/` | GET /api/v1/drivers/applications/me/ |
| Drivers | GET | `/api/v1/drivers/me/availability/` | — |
| Drivers | GET | `/api/v1/drivers/me/current-trip/` | — |
| Drivers | GET | `/api/v1/drivers/me/profile/` | — |
| Drivers | GET | `/api/v1/drivers/me/requests/` | — |
| Drivers | GET | `/api/v1/drivers/me/requests/{id}/` | — |
| Drivers | GET | `/api/v1/drivers/me/statistics/` | — |
| Drivers | GET | `/api/v1/drivers/me/status/` | GET /api/v1/drivers/applications/me/ |
| Drivers | PATCH | `/api/v1/drivers/me/profile/` | — |
| Drivers | POST | `/api/v1/drivers/me/go-offline/` | — |
| Drivers | POST | `/api/v1/drivers/me/go-online/` | — |
| Drivers | POST | `/api/v1/drivers/me/location/` | — |
| Earnings | GET | `/api/v1/drivers/me/earnings/` | — |
| Earnings | GET | `/api/v1/drivers/me/earnings/history/` | — |
| Earnings | GET | `/api/v1/drivers/me/earnings/summary/` | — |
| Locations | DELETE | `/api/v1/users/me/saved-places/{id}/` | — |
| Locations | GET | `/api/v1/locations/reverse-geocode/` | — |
| Locations | GET | `/api/v1/locations/search/` | — |
| Locations | GET | `/api/v1/places/` | GET /api/v1/locations/search/ |
| Locations | GET | `/api/v1/service-areas/` | — |
| Locations | GET | `/api/v1/service-areas/{id}/` | — |
| Locations | GET | `/api/v1/users/me/saved-places/` | — |
| Locations | GET | `/api/v1/users/me/saved-places/{id}/` | — |
| Locations | PATCH | `/api/v1/users/me/saved-places/{id}/` | — |
| Locations | POST | `/api/v1/users/me/saved-places/` | — |
| Notifications | DELETE | `/api/v1/devices/{id}/` | — |
| Notifications | GET | `/api/v1/notifications/` | — |
| Notifications | GET | `/api/v1/notifications/unread-count/` | — |
| Notifications | POST | `/api/v1/devices/register/` | — |
| Notifications | POST | `/api/v1/notifications/mark-all-read/` | — |
| Notifications | POST | `/api/v1/notifications/{id}/read/` | — |
| Offers | GET | `/api/v1/offers/{id}/` | — |
| Offers | GET | `/api/v1/rides/{id}/offers/` | — |
| Offers | POST | `/api/v1/offers/{id}/withdraw/` | — |
| Offers | POST | `/api/v1/rides/{id}/offers/` | — |
| Platform Configuration | DELETE | `/api/v1/admin/service-areas/{id}/` | — |
| Platform Configuration | GET | `/api/v1/admin/service-areas/` | — |
| Platform Configuration | GET | `/api/v1/admin/service-areas/{id}/` | — |
| Platform Configuration | PATCH | `/api/v1/admin/service-areas/{id}/` | — |
| Platform Configuration | POST | `/api/v1/admin/service-areas/` | — |
| Pricing | GET | `/api/v1/ride-categories/` | — |
| Pricing | GET | `/api/v1/ride-categories/{id}/` | — |
| Pricing | POST | `/api/v1/fares/estimate/` | — |
| Ratings | GET | `/api/v1/drivers/me/ratings/` | GET /api/v1/users/me/ratings/ |
| Ratings | GET | `/api/v1/drivers/{id}/ratings/` | — |
| Ratings | GET | `/api/v1/users/me/ratings/` | — |
| Ratings | POST | `/api/v1/rides/{id}/ratings/` | — |
| Rides | GET | `/api/v1/rides/` | — |
| Rides | GET | `/api/v1/rides/active/` | — |
| Rides | GET | `/api/v1/rides/{id}/` | — |
| Rides | GET | `/api/v1/rides/{id}/status/` | — |
| Rides | POST | `/api/v1/rides/` | — |
| Rides | POST | `/api/v1/rides/{id}/arrived/` | — |
| Rides | POST | `/api/v1/rides/{id}/cancel/` | — |
| Rides | POST | `/api/v1/rides/{id}/complete/` | — |
| Rides | POST | `/api/v1/rides/{id}/driver-en-route/` | — |
| Rides | POST | `/api/v1/rides/{id}/select-offer/` | — |
| Rides | POST | `/api/v1/rides/{id}/start/` | — |
| Routes | POST | `/api/v1/routes/estimate/` | — |
| Routes | POST | `/api/v1/routes/quote/` | POST /api/v1/fares/estimate/ |
| Safety | DELETE | `/api/v1/safety/shares/{id}/` | — |
| Safety | DELETE | `/api/v1/users/me/emergency-contacts/{id}/` | — |
| Safety | GET | `/api/v1/safety/shares/{id}/` | — |
| Safety | GET | `/api/v1/users/me/emergency-contacts/` | — |
| Safety | GET | `/api/v1/users/me/emergency-contacts/{id}/` | — |
| Safety | PATCH | `/api/v1/users/me/emergency-contacts/{id}/` | — |
| Safety | POST | `/api/v1/rides/{id}/report/` | — |
| Safety | POST | `/api/v1/rides/{id}/share/` | — |
| Safety | POST | `/api/v1/users/me/emergency-contacts/` | — |
| Support | GET | `/api/v1/admin/disputes/` | — |
| Support | GET | `/api/v1/admin/disputes/{id}/` | — |
| Support | GET | `/api/v1/support/tickets/` | — |
| Support | GET | `/api/v1/support/tickets/{id}/` | — |
| Support | POST | `/api/v1/admin/disputes/{id}/resolve/` | — |
| Support | POST | `/api/v1/support/tickets/` | — |
| Tracking | GET | `/api/v1/rides/{id}/tracking/` | — |
| Trips | GET | `/api/v1/drivers/me/trips/` | — |
| Trips | GET | `/api/v1/rides/{id}/receipt/` | — |
| Trips | GET | `/api/v1/rides/{id}/timeline/` | — |
| Trips | GET | `/api/v1/users/me/trips/` | — |
| Users | DELETE | `/api/v1/users/me/avatar/` | — |
| Users | GET | `/api/v1/currencies/` | — |
| Users | GET | `/api/v1/payments/history/` | — |
| Users | GET | `/api/v1/payments/methods/` | — |
| Users | GET | `/api/v1/users/me/` | GET /api/v1/auth/me/ |
| Users | GET | `/api/v1/users/me/avatar/` | — |
| Users | GET | `/api/v1/users/me/preferences/` | — |
| Users | PATCH | `/api/v1/users/me/` | — |
| Users | PATCH | `/api/v1/users/me/preferences/` | — |
| Users | POST | `/api/v1/users/me/avatar/` | — |
| Vehicles | DELETE | `/api/v1/drivers/me/vehicles/{id}/` | — |
| Vehicles | DELETE | `/api/v1/drivers/me/vehicles/{vehicle_id}/documents/{id}/` | — |
| Vehicles | GET | `/api/v1/drivers/me/vehicles/` | — |
| Vehicles | GET | `/api/v1/drivers/me/vehicles/{id}/` | — |
| Vehicles | GET | `/api/v1/drivers/me/vehicles/{vehicle_id}/documents/` | — |
| Vehicles | GET | `/api/v1/drivers/me/vehicles/{vehicle_id}/documents/{id}/` | — |
| Vehicles | PATCH | `/api/v1/drivers/me/vehicles/{id}/` | — |
| Vehicles | POST | `/api/v1/drivers/me/vehicles/` | — |
| Vehicles | POST | `/api/v1/drivers/me/vehicles/{id}/activate/` | — |
| Vehicles | POST | `/api/v1/drivers/me/vehicles/{vehicle_id}/documents/` | — |
| Verification | GET | `/api/v1/admin/vehicles/` | — |
| Verification | GET | `/api/v1/admin/vehicles/{id}/` | — |
| Verification | GET | `/api/v1/drivers/me/verification-status/` | GET /api/v1/drivers/applications/me/ |
| Verification | POST | `/api/v1/admin/vehicles/{id}/approve/` | — |
| Verification | POST | `/api/v1/admin/vehicles/{id}/reject/` | — |
