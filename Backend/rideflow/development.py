"""Local development only; never use these settings on a public deployment."""
from .settings import *

if len(SECRET_KEY) < 32 or SECRET_KEY == os.environ.get('DJANGO_SECRET_KEY'):
    raise ImproperlyConfigured('Set a distinct TRIVIA_DEV_SECRET_KEY of at least 32 characters.')

DEBUG = True
TRIVIA_LOCAL_PASSWORD_RECOVERY = env_bool("TRIVIA_LOCAL_PASSWORD_RECOVERY", False)
PASSWORD_AUTH_REDIS_URL = os.environ.get("TRIVIA_DEV_PASSWORD_REDIS_URL", "redis://127.0.0.1:6379/14")
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '[::1]', '10.0.2.2']
DATABASES['default']['HOST'] = os.environ.get(
    'TRIVIA_DEV_MONGODB_URI', 'mongodb://127.0.0.1:27018/?replicaSet=trivia-rs')
DATABASES['default']['NAME'] = os.environ.get('TRIVIA_DEV_MONGODB_DATABASE', 'trivia_dev_local')
CHANNEL_LAYERS = {'default': {'BACKEND': 'channels.layers.InMemoryChannelLayer'}}
CACHES = {'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}}
CELERY_BROKER_URL = 'memory://'
CELERY_TASK_ALWAYS_EAGER = True
PUSH_PROVIDER = ''
PRIVATE_MEDIA_ROOT = BASE_DIR / 'private_media' / 'development'
PRIVATE_STORAGE_BACKEND = 'django.core.files.storage.FileSystemStorage'
STORAGES['private'] = {
    'BACKEND': PRIVATE_STORAGE_BACKEND,
    'OPTIONS': {'location': PRIVATE_MEDIA_ROOT},
}
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False

# The test-code guard is also evaluated on each OTP request and verification.
from accounts.test_otp import validate_test_otp_settings
from types import SimpleNamespace
validate_test_otp_settings(SimpleNamespace(
    SETTINGS_MODULE=__name__, DEBUG=DEBUG, DATABASES=DATABASES, ALLOWED_HOSTS=ALLOWED_HOSTS,
    TRIVIA_TEST_OTP_ENABLED=TRIVIA_TEST_OTP_ENABLED,
    TRIVIA_TEST_OTP_PHONES=TRIVIA_TEST_OTP_PHONES,
))
