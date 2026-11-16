import json
import logging
import time
import uuid


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
        response = self.get_response(request)
        response['X-Request-ID'] = request.request_id
        logging.getLogger('trivia.http').info('method=%s status=%s duration_ms=%d', request.method, response.status_code,
            (time.monotonic() - started) * 1000, extra={'request_id': request.request_id})
        return response
