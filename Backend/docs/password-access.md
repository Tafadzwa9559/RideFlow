# Trivia password access

All paths below are relative to `/api/v1/`. Requests are JSON.

The API uses Simple JWT with rotating refresh tokens. Django's browser admin uses session cookies. Passenger and driver accounts share the same sign-in routes. First-time OTP verification creates the account, and driver eligibility depends on the existing approval workflow.

| Method and path | Purpose |
| --- | --- |
| `POST auth/otp/request/` | Request a phone code for registration or sign-in |
| `POST auth/otp/verify/` | Verify the code and return the account and JWT pair |
| `POST auth/token/refresh/` | Rotate the refresh token and issue a new JWT pair |
| `POST auth/logout/` | Revoke the authenticated session |
| `GET auth/me/` | Return the authenticated profile |

### Password sign-in and recovery

| POST path | Request fields | Success |
| --- | --- | --- |
| `auth/login/` | `channel` (`phone` or `email`), `identifier`, `password` | 200 with `access`, `refresh` and `user` |
| `auth/password/request/` | `channel`, `identifier` | Generic 202 when the channel is enabled |
| `auth/password/verify/` | `channel`, `identifier`, `code` | 200 with an expiring `token` |
| `auth/password/reset/` | `token`, `password` | 204. Existing access and refresh sessions are revoked. |

Password login uses the existing Django password hash and verified phone identity. Email login requires a unique case-insensitive match and the correct password. The account's official driver status comes from the existing profile response. OTP sign-up still uses its original endpoints.

Older accounts created by phone OTP have an unusable password unless one was provisioned later. They can set their first password through verified recovery once their channel is available. For secured staging, provision an isolated verified test account and set its own password through Django's interactive `changepassword` command. Use separate passenger and approved driver accounts, and give the Flutter debug build the staging HTTPS origin using `--dart-define=TRIVIA_API_BASE_URL=…`.

## Delivery and deployment

- Run the existing Celery worker from the same revision as the web service and provide both services with the same private cache Redis, broker, signing key and delivery settings. The Redis challenges have a five-minute TTL. The API applies atomic limits for account identifiers and client IPs.
- SMS recovery requires a working `SMS_PROVIDER`. The recovery flow generates its own random six-digit codes. For loopback development only, `TRIVIA_LOCAL_PASSWORD_RECOVERY=true` with `rideflow.development` uses the explicitly allowlisted `TRIVIA_TEST_OTP_PHONES` and a separate process-local test mailbox. It works independently of the existing registration test-code toggle.
- Enable email recovery with `TRIVIA_RECOVERY_EMAIL_ENABLED=true` after configuring the SMTP environment variables in `.env.example`. The email contains an expiring token to paste in Trivia. Set `TRIVIA_VERIFIED_RECOVERY_EMAILS` on both services to a JSON mapping from user IDs to email addresses whose ownership has been independently verified. The current profile address must match the binding. Legacy profile email data alone cannot establish eligibility. Keep the binding list synchronized until a reviewed persistent verification design is available.
- A 503 indicates disabled delivery or a required service outage. A 202 acknowledges the request and keeps account existence private. Watch the worker's delivery-error metric or log during staging.
- Render public ingress provides the Cloudflare client address header used for password endpoint throttling. Confirm the header is overwritten at the edge before accepting traffic on a custom or private ingress.
- Review legacy duplicate emails before a broader rollout. Ambiguous addresses cannot be used for email login or recovery. Profile writes prevent new case-insensitive collisions through the API. Phone uniqueness uses the existing normalized identifier. Deployment adds no models or migrations.

Run `python manage.py test accounts.tests --settings=rideflow.testing` against an isolated loopback MongoDB replica set. Set `MONGODB_TEST_NAME` to a dedicated `test_trivia_dev_*` database so the development OTP test cases satisfy the same database guard as the application. Set `TRIVIA_PASSWORD_TEST_REDIS_URL` to a dedicated Redis test instance. SMS and email deliveries use test mailboxes.

## Staff API sign-in and Swagger

- `POST /api/v1/admin/auth/login/` accepts `channel` (`username`, `email`, or `phone`), `identifier`, and `password`. Email must uniquely identify a user and a phone must be verified. Only active Django staff can sign in. Each administrative action separately checks its Django permission, such as `drivers.operate_platform` for the dashboard.
- Use `POST /api/v1/auth/token/refresh/` for both personal and staff API sessions. Store the rotated token pair. `GET /api/v1/auth/me/` returns the authenticated profile. `POST /api/v1/auth/logout/` revokes the current staff API session, or all sessions for a personal phone account as before. Staff API sessions have an absolute lifetime equal to the configured refresh lifetime. Staff password changes invalidate existing staff API sessions.
- Staff password changes and recovery use Django's administrative account procedures. Public OTP and password recovery are for personal accounts.
- Production `/api/docs/`, `/api/redoc/`, and `/api/schema/` require an active Django staff browser session. Open `/admin/login/` to establish that session. An API bearer token is for API requests, while the documentation viewer and schema use the browser session. All canonical auth operations appear under **Authentication**.
