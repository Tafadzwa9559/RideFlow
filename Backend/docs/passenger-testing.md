# Passenger testing on staging

Use a separate staging deployment with its own database, signing secret, Redis and background workers. Configure sandbox payment and notification services. Keep the production deployment on `rideflow.production`.

1. Use an authorized staging superuser. Keep the existing production account untouched and do not copy production passwords or secrets into staging. Have a staging administrator provision a dedicated synthetic, active user with an unusable password, no staff or superuser flags, no driver application and a verified synthetic PhoneIdentity. Do not reuse a real phone number.
2. Set `DJANGO_SETTINGS_MODULE=rideflow.staging`, `TRIVIA_PASSENGER_TEST_ACTOR` to the authorized staging superuser's MongoDB user ID, and `TRIVIA_PASSENGER_TEST_PROFILE` to the passenger's user ID. Leave the two IDs unset to disable the endpoint.
3. Build Flutter with `--dart-define=TRIVIA_PASSENGER_TESTING=true` and set both `TRIVIA_API_BASE_URL` and `TRIVIA_PASSENGER_TESTING_ORIGIN` to the same staging HTTPS origin. In Log In, turn on **Passenger Testing Mode** and enter the staging administrator username and password.
4. Confirm My Account shows the synthetic passenger. Confirm passenger endpoints work and admin endpoints reject the mobile token. Verify token refresh, then sign out in Flutter and return to the administrator interface in the browser. The browser session is separate and survives Flutter logout.

The staging endpoint verifies the staff password with the existing Redis limits and issues regular JWTs for the passenger only. Access and refresh are rejected if the mapping changes, the administrator loses privileges or changes password, or the passenger session version changes. Normal login and OTP endpoints remain unchanged. To disable the mode, remove the staging IDs, restart the staging services and rebuild the app without the testing flag.
