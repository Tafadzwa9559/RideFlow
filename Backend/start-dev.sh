#!/bin/bash
set -Eeuo pipefail

celery_pid=""
daphne_pid=""

shutdown() {
    trap - TERM INT
    echo "Stopping Trivia services..."

    if [ -n "$celery_pid" ]; then
        kill -TERM "$celery_pid" 2>/dev/null || true
    fi

    if [ -n "$daphne_pid" ]; then
        kill -TERM "$daphne_pid" 2>/dev/null || true
    fi

    wait 2>/dev/null || true
}

trap 'shutdown; exit 143' TERM
trap 'shutdown; exit 130' INT

echo "Starting Trivia Celery worker..."
python -m celery -A rideflow worker \
    --loglevel=info \
    --concurrency=1 \
    --pool=solo &
celery_pid=$!

echo "Starting Trivia Daphne server..."
daphne -b 0.0.0.0 -p "${PORT:-10000}" rideflow.asgi:application &
daphne_pid=$!

set +e
wait -n "$celery_pid" "$daphne_pid"
exit_code=$?
set -e

echo "A Trivia process exited. Shutting down..."
shutdown
exit "$exit_code"
