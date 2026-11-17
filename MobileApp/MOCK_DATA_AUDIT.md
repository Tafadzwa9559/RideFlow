# Mock-data audit

Historical record of simulation removal during backend integration. The table describes the pre-integration sources and their replacements. Current account screens are split across lib/features/account/.

Scope: existing Flutter app; preserve screens/navigation/style. No Django changes authorized or required by this task.

| Source | Finding | Replacement |
|---|---|---|
| lib/core/config.dart | Demo enabled by default; empty API host | Production HTTPS origin by default |
| lib/core/repository.dart | In-memory DemoRepository: OTP 123456, fictional routes/fares/drivers/offers, simulated approval/trips/earnings, fabricated notifications, no-op writes | Remove from application; keep fixtures only in automated tests |
| lib/shared/models.dart | Sample landmark list, unsupported currency, missing expired enum | Remove sample data; parse actual supported states/USD |
| lib/app/controller.dart | Demo repository selector, simulation exceptions, invented realtime/ticket request | Always real repository; documented first-frame JWT socket authentication |
| lib/core/realtime.dart | Ticket/subscribe protocol unsupported by server | token first frame, connection.ready, authenticated notifications room, REST reconciliation |
| lib/features/entry/entry.dart | Demo OTP text | Real request/verify/errors only |
| lib/features/driver/registration.dart | Local secure-storage application, simulated approval, future-service gate | Existing draft/document/submit endpoints and real requirement metadata |
| lib/features/driver/driver.dart | Simulated passenger selection, local decline, fake earnings shape | Real offers/decline and earnings data |
| lib/features/passenger/booking_fields.dart, home.dart | Demo explanations and simulated passenger trip controls | Server-driven quotes, driver-only transitions |
| lib/features/account/account.dart | Simulated submissions, invented paths, static settings, placeholder notification rendering | Documented resources/validation; unavailable state for missing features |
| lib/shared/widgets.dart, app/app.dart | Demo banner | Remove simulation banner |
| lib/core/map_view.dart | Default viewport centered in Harare | Legitimate viewport constant; never a GPS fix or driver marker |
| test/* | Tests exercise demo runtime | Isolate synthetic fixtures under test/support; add real client contract/error/refresh tests |

Legitimate constants retained: branding, theme/assets, categories, offline payment enums, map initial viewport, debounce/countdown/reconnect timers. No arbitrary delays represent API success.

Live schema fetch: GET https://trivia-backend-bze2.onrender.com/api/schema/ returned 302 to /admin/login/?next=/api/schema/; following it returns HTML. Full live OpenAPI cannot be read anonymously. Use the checked-in Backend/docs/openapi.yaml and actual handlers as the contract, without claiming deployed parity. No administrator credentials were requested or disclosed; no production mutations used for inspection.
