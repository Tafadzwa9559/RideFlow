#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Android emulator reaches the host loopback interface through 10.0.2.2.
exec flutter run --debug \
  --dart-define=TRIVIA_DEVELOPMENT_BUILD=true \
  --dart-define=TRIVIA_API_BASE_URL="${TRIVIA_DEV_API_ORIGIN:-http://10.0.2.2:8000}" \
  "$@"
