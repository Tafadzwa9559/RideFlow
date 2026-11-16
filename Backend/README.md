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
