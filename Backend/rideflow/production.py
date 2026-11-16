from .settings import *
from django.core.exceptions import ImproperlyConfigured
DEBUG = False
if not os.environ.get('DJANGO_SECRET_KEY') or SECRET_KEY.startswith('django-insecure'):
    raise ImproperlyConfigured('Production requires a secret from the secret manager.')
if DATABASES['default']['ENGINE'] != 'django_mongodb_backend':
    raise ImproperlyConfigured('Production requires the official MongoDB backend.')
if TRIVIA_LOCAL_OTP or SMS_PROVIDER.endswith('LocalSMS'):
    raise ImproperlyConfigured('Local OTP is prohibited in production.')
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True

# Set only when the trusted ingress strips client-supplied forwarding headers.
if os.environ.get('TRUST_PROXY_SSL_HEADER', 'false').lower() == 'true':
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_REDIRECT_EXEMPT = [r'^health/$', r'^ready/$']
