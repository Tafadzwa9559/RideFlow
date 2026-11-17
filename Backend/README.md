# Trivia backend

Your Journey. Your Choice. — MOrdec Solutions (Private) Limited.

Django 5.2.19 / Python 3.12, the official Django MongoDB Backend 5.2.4, MongoDB replica-set transactions, DRF, JWT/OTP, Channels/Redis, Celery and Daphne.

**Current setup, migration and operational guide: [MongoDB migration and operations](docs/mongodb.md).**

- [REST integration guide and cURL workflow](docs/api-integration-guide.md)
- [Validated OpenAPI](docs/openapi.yaml), Swagger `/api/docs/`, ReDoc `/api/redoc/`
- [Endpoint catalog](docs/endpoint-catalog.md)
- [WebSocket protocol](docs/websockets.md)
- [Controlled source-data migration plan](docs/mongodb-migration-plan.md)

The original SQL migration graph and source databases are preserved. MongoDB has a separate migration graph. Live source-data cutover requires a rehearsed read-only export, verified import and media reconciliation; changing the connection alone does not migrate customer data.

Former integer entity IDs now serialize as 24-character ObjectId strings. Existing ride/quote/event UUIDs, resource paths, field names and payment/category/state enums are retained. Older implementation reports describe their historical MySQL verification; use the current MongoDB guide/report for this revision.

Only USD fares and Cash/EcoCash/OneMoney direct-payment preferences are supported. Trivia does not charge passengers or verify direct receipt of funds. Driver review, server-side eligibility, passenger-selected offers and transactional assignment remain authoritative.

Current enhancement deliverables: [backend audit](BACKEND_AUDIT.md), [API documentation](API_DOCUMENTATION.md), [Render/Atlas deployment](docs/render.md), and [implementation/testing report](docs/backend-enhancement-report.md).

Production uses Atlas through `MONGODB_URI`, with shared private object storage (`requirements-storage.txt`); `rideflow.production` rejects local/unsafe configuration. Tests are restricted to a loopback MongoDB replica set and never run on Atlas. See the local startup commands in [MongoDB operations](docs/mongodb.md). Render web, Celery worker and singleton beat are independent services; the Blueprint is prepared for review and has not been deployed.

Session/delivery follow-up: refresh rotation is serialized with logout, transport failures use bounded retries, and internal per-device push receipts reduce repeat sends after partial delivery. See the current implementation report for test results and the additive notification migration.

Local authentication testing: [guarded development OTP setup](docs/development-otp.md).
The fixed code is disabled by default and prohibited in production settings.
