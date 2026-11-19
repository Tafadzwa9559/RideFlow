import json
import logging
import time
import uuid
from contextvars import ContextVar


request_id_context = ContextVar('request_id', default=None)


class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({'level': record.levelname, 'logger': record.name, 'message': record.getMessage(),
                           'request_id': getattr(record, 'request_id', None)})


class RequestIDMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request.request_id = uuid.uuid4().hex
        started = time.monotonic()
        token = request_id_context.set(request.request_id)
        try:
            response = self.get_response(request)
        finally:
            request_id_context.reset(token)
        response['X-Request-ID'] = request.request_id
        logging.getLogger('trivia.http').info('method=%s status=%s duration_ms=%d', request.method, response.status_code,
            (time.monotonic() - started) * 1000, extra={'request_id': request.request_id})
        return response
