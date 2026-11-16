from .settings import *
DATABASES['default']['NAME'] = os.environ.get('MONGODB_TEST_BASE', 'trivia_test_base')
DATABASES['default']['HOST'] = os.environ.get('MONGODB_TEST_URI', 'mongodb://127.0.0.1:27018/?replicaSet=trivia-rs')
DATABASES['default']['TEST'] = {'NAME': os.environ.get('MONGODB_TEST_DATABASE', 'test_trivia_isolated')}
CHANNEL_LAYERS = {'default': {'BACKEND': 'channels.layers.InMemoryChannelLayer'}}
CACHES = {'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}}
PASSWORD_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']
CELERY_TASK_ALWAYS_EAGER = True
DEBUG = True
SMS_PROVIDER = 'accounts.services.authentication.LocalSMS'
TRIVIA_LOCAL_OTP = True
