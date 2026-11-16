from django.db import connection
from django.http import JsonResponse
from django.conf import settings


def health(request):
    return JsonResponse({'status': 'ok'})


def ready(request):
    try:
        from redis import Redis
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        Redis.from_url(settings.REDIS_URL, socket_connect_timeout=1, socket_timeout=1).ping()
        from rideflow.celery import app
        if not app.control.ping(timeout=1):
            raise RuntimeError('Worker unavailable')
    except Exception:
        return JsonResponse({'status': 'unavailable'}, status=503)
    return JsonResponse({'status': 'ready'})


from rest_framework.permissions import IsAdminUser
from rest_framework.views import APIView


class WebSocketDocumentationView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        from pathlib import Path
        from django.http import HttpResponse
        content = (Path(settings.BASE_DIR) / 'docs' / 'websockets.md').read_text()
        return HttpResponse(content, content_type='text/plain; charset=utf-8')
