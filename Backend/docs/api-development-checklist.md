# REST API completion checklist

Audit baseline: core OTP/JWT, draft/review, private documents, single vehicle, quote/booking/offer/lifecycle, notifications, ratings, safety sharing and basic administration already work. Existing APIViews have broad/free-form schema responses; ReDoc, resource CRUD, search/filtering and several read endpoints are missing.

- [x] Preserve existing mobile handlers and enum casing; document aliases without inflating counts.
- [x] Complete own profile/avatar/preferences/saved-place resources and auth resend/logout-all.
- [x] Complete application documents/history and multiple-vehicle lifecycle with safe activation/archival.
- [x] Complete driver profile/statistics/availability/current trip/request detail.
- [x] Add reverse geocoding, route-only estimation, service/category details.
- [x] Add status/timeline/tracking/receipt/history and offer/ratings/earnings reads.
- [x] Complete notification counters/bulk reads/devices, private ticket/contact CRUD.
- [x] Complete permission-scoped admin actions, configuration deletion, analytics/reports.
- [x] Replace free-form schemas with typed contracts, examples, tags and error codes.
- [x] Add protected ReDoc, separate WebSocket protocol and integration guide.
- [x] Test endpoint authorization, ownership, pagination/filtering and MySQL concurrency.
- [x] Validate schema coverage, migrations, production checks and report canonical counts.

Verified: MySQL 62/62 tests passed, including eight concurrency tests; portable suite 54 passed/eight MySQL-only skips. Full counts and limits are in api-completion-report.md.
