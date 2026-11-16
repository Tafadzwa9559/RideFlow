from .settings import *
DATABASES['default']['NAME'] = os.environ.get('MONGODB_TEST_BASE', 'trivia_test_base')
DATABASES['default']['HOST'] = os.environ.get('MONGODB_TEST_URI', 'mongodb://127.0.0.1:27018/?replicaSet=trivia-rs')
DATABASES['default']['TEST'] = {'NAME': os.environ.get('MONGODB_TEST_NAME', os.environ.get('MONGODB_TEST_DATABASE', 'test_trivia_isolated'))}
CHANNEL_LAYERS = {'default': {'BACKEND': 'channels.layers.InMemoryChannelLayer'}}
CACHES = {'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}}
PASSWORD_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']
CELERY_TASK_ALWAYS_EAGER = True
DEBUG = True
SMS_PROVIDER = 'accounts.services.authentication.LocalSMS'
TRIVIA_LOCAL_OTP = True
# Test creation destroys its selected database. Reject accidental application names.
from django.core.exceptions import ImproperlyConfigured
if not DATABASES['default']['TEST']['NAME'].startswith('test_') or DATABASES['default']['TEST']['NAME'] == os.environ.get('MONGODB_DATABASE', 'trivia'):
    raise ImproperlyConfigured('MONGODB_TEST_NAME must be an isolated test_* database, distinct from the application database.')

# Never create/drop test databases on Atlas or another remote deployment.
from urllib.parse import urlsplit
_test_uri = urlsplit(DATABASES['default']['HOST'])
if _test_uri.scheme != 'mongodb' or _test_uri.hostname not in {'localhost', '127.0.0.1', '::1'} or ',' in _test_uri.netloc:
    raise ImproperlyConfigured('Tests require a local loopback MongoDB replica set; Atlas/remote URIs are prohibited.')
STORAGES['private'] = {
    'BACKEND': 'django.core.files.storage.FileSystemStorage',
    'OPTIONS': {'location': PRIVATE_MEDIA_ROOT},
}
