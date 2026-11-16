from rest_framework.views import exception_handler as drf_handler


def exception_handler(exc, context):
    response = drf_handler(exc, context)
    if response is not None:
        def codes(value):
            if isinstance(value, dict):
                return {k: codes(v) for k, v in value.items()}
            if isinstance(value, list):
                return [codes(v) for v in value]
            return getattr(value, 'code', 'error')
        detail = getattr(exc, 'detail', {})
        def first_code(value):
            if isinstance(value, dict):
                return next((first_code(v) for v in value.values()), None)
            if isinstance(value, list):
                return next((first_code(v) for v in value), None)
            return getattr(value, 'code', None)
        code = first_code(detail) or getattr(exc, 'default_code', 'error')
        response.data = {'errors': response.data, 'code': str(code).upper(), 'field_codes': codes(detail),
                         'request_id': getattr(context.get('request'), 'request_id', None)}
    return response
