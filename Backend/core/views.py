
import logging
from pathlib import Path

from django.conf import settings
from django.db import connection
from django.http import HttpResponse, JsonResponse

from redis import Redis

from rest_framework.permissions import IsAdminUser
from rest_framework.views import APIView


logger = logging.getLogger("trivia.readiness")


# ============================================================
# 1. HEALTH CHECK
# ============================================================

def health(request):
    """
    Liveness endpoint.

    Returns HTTP 200 when the Django application is running.
    Does not verify external services.
    """
    return JsonResponse(
        {"status": "ok"},
        status=200,
    )


# ============================================================
# 2. DATABASE READINESS
# ============================================================

def check_mongodb():
    """
    Verify MongoDB Atlas connectivity and transaction support.
    """
    connection.ensure_connection()

    database = connection.database

    database.command("ping")

    hello = database.client.admin.command("hello")

    is_replica_set = bool(hello.get("setName"))
    is_sharded_cluster = hello.get("msg") == "isdbgrid"

    if not (is_replica_set or is_sharded_cluster):
        raise RuntimeError(
            "MongoDB deployment does not support transactions."
        )

    return True


# ============================================================
# 3. REDIS READINESS
# ============================================================

def check_redis():
    """
    Verify Redis connectivity.
    """
    redis_url = settings.REDIS_URL

    client = Redis.from_url(
        redis_url,
        socket_connect_timeout=2,
        socket_timeout=2,
    )

    try:
        if not client.ping():
            raise RuntimeError("Redis ping failed.")

    finally:
        client.close()

    return True


# ============================================================
# 4. CELERY WORKER READINESS
# ============================================================

def check_celery():
    """
    Verify at least one Celery worker is responding.
    """
    from rideflow.celery import app

    workers = app.control.ping(timeout=2)

    if not workers:
        raise RuntimeError(
            "No Celery workers are responding."
        )

    return True


# ============================================================
# 5. FULL APPLICATION READINESS
# ============================================================

def ready(request):
    """
    Readiness endpoint.

    Checks:
        1. MongoDB Atlas
        2. Redis
        3. Celery worker

    Returns HTTP 503 if any dependency is unavailable.

    Detailed failures are logged server-side.
    """
    checks = (
        ("mongodb", check_mongodb),
        ("redis", check_redis),
        ("celery", check_celery),
    )

    for service_name, check_function in checks:
        try:
            check_function()

        except Exception:
            logger.exception(
                "Trivia readiness check failed: %s",
                service_name,
            )

            return JsonResponse(
                {"status": "unavailable"},
                status=503,
            )

    return JsonResponse(
        {"status": "ready"},
        status=200,
    )


# ============================================================
# 6. SECURE WEBSOCKET DOCUMENTATION
# ============================================================

class WebSocketDocumentationView(APIView):
    """
    Administrator-only WebSocket protocol documentation.
    """

    permission_classes = [IsAdminUser]

    def get(self, request):
        documentation_path = (
            Path(settings.BASE_DIR)
            / "docs"
            / "websockets.md"
        )

        if not documentation_path.is_file():
            logger.error(
                "Trivia WebSocket documentation file is missing."
            )

            return JsonResponse(
                {"detail": "Documentation unavailable."},
                status=404,
            )

        content = documentation_path.read_text(
            encoding="utf-8"
        )

        return HttpResponse(
            content,
            content_type="text/plain; charset=utf-8",
        )
