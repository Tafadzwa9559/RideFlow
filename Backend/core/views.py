
import logging
from pathlib import Path

from django.conf import settings
from django.db import connection
from django.http import HttpResponse, JsonResponse
from django.views.decorators.http import require_GET

from redis import Redis

from rest_framework.permissions import IsAdminUser
from rest_framework.views import APIView


logger = logging.getLogger("trivia.readiness")


# ============================================================
# 1. APPLICATION HEALTH
# ============================================================

@require_GET
def health(request):
    """
    Liveness endpoint.

    Confirms that Django is running.
    Does not check external services.
    """
    return JsonResponse(
        {"status": "ok"},
        status=200,
    )


# ============================================================
# 2. MONGODB ATLAS CHECK
# ============================================================

def check_mongodb():
    """
    Verify MongoDB connectivity and transaction-capable topology.
    """

    connection.ensure_connection()

    database = connection.database
    client = database.client

    # Confirm MongoDB can process a command.
    database.command("ping")

    # Check server topology.
    hello = client.admin.command("hello")

    is_replica_set = bool(hello.get("setName"))
    is_sharded_cluster = hello.get("msg") == "isdbgrid"

    if not (is_replica_set or is_sharded_cluster):
        raise RuntimeError(
            "MongoDB transaction-capable topology unavailable"
        )

    return True


# ============================================================
# 3. REDIS CHECK
# ============================================================

def check_redis():
    """
    Verify the Redis server used by Trivia.
    """

    redis_url = getattr(settings, "REDIS_URL", None)

    if not redis_url:
        raise RuntimeError("REDIS_URL is not configured")

    client = Redis.from_url(
        redis_url,
        socket_connect_timeout=2,
        socket_timeout=2,
        health_check_interval=30,
    )

    try:
        if not client.ping():
            raise RuntimeError("Redis ping unsuccessful")

    finally:
        client.close()

    return True


# ============================================================
# 4. CELERY WORKER CHECK
# ============================================================

def check_celery():
    """
    Check whether at least one Celery worker is responding.
    """

    from rideflow.celery import app

    workers = app.control.ping(timeout=2)

    if not workers:
        raise RuntimeError("No Celery worker responding")

    return True


# ============================================================
# 5. READINESS CHECK
# ============================================================

@require_GET
def ready(request):
    """
    Verify all required backend services.

    Checks:
        MongoDB Atlas
        Redis
        Celery

    HTTP 200:
        All checks passed.

    HTTP 503:
        At least one dependency failed.

    Public responses do not expose credentials,
    server addresses or internal exceptions.
    """

    checks = {
        "mongodb": check_mongodb,
        "redis": check_redis,
        "celery": check_celery,
    }

    results = {}

    for service_name, check_function in checks.items():
        try:
            check_function()

            results[service_name] = "ok"

            logger.info(
                "Trivia dependency check passed: %s",
                service_name,
            )

        except Exception as exc:
            results[service_name] = "failed"

            # Log only the exception class by default,
            # avoiding credential-bearing exception messages.
            logger.error(
                "Trivia readiness check failed: %s | error_type=%s",
                service_name,
                type(exc).__name__,
            )

    all_ready = all(
        status == "ok"
        for status in results.values()
    )

    if not all_ready:
        logger.warning(
            "Trivia readiness summary: %s",
            results,
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
# 6. ADMIN-ONLY WEBSOCKET DOCUMENTATION
# ============================================================

class WebSocketDocumentationView(APIView):
    """
    Admin-only access to Trivia's WebSocket documentation.
    """

    permission_classes = [IsAdminUser]
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        documentation_path = (
            Path(settings.BASE_DIR)
            / "docs"
            / "websockets.md"
        )

        if not documentation_path.is_file():
            logger.error(
                "Trivia WebSocket documentation missing"
            )

            return JsonResponse(
                {"detail": "Documentation unavailable."},
                status=404,
            )

        try:
            content = documentation_path.read_text(
                encoding="utf-8"
            )

        except OSError:
            logger.error(
                "Unable to read Trivia WebSocket documentation"
            )

            return JsonResponse(
                {"detail": "Documentation unavailable."},
                status=500,
            )

        return HttpResponse(
            content,
            content_type="text/plain; charset=utf-8",
        )
