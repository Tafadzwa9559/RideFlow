
"""
Trivia — Django Testing Settings

Isolated test environment for the Trivia ride-hailing platform.

- Uses a local MongoDB replica set.
- Prevents testing against MongoDB Atlas or remote databases.
- Keeps Django's default database test configuration intact.
- Uses in-memory Channels and cache backends.
- Enables local SMS OTP testing.
- Executes Celery tasks synchronously.
"""

import os
from urllib.parse import urlsplit

from django.core.exceptions import ImproperlyConfigured

from .settings import *  # noqa: F401, F403


# ============================================================
# 1. DATABASE CONFIGURATION
# ============================================================

TEST_DATABASE_BASE = os.environ.get(
    "MONGODB_TEST_BASE",
    "trivia_test_base",
)

TEST_DATABASE_NAME = os.environ.get(
    "MONGODB_TEST_NAME",
    os.environ.get(
        "MONGODB_TEST_DATABASE",
        "test_trivia_isolated",
    ),
)

TEST_DATABASE_URI = os.environ.get(
    "MONGODB_TEST_URI",
    "mongodb://127.0.0.1:27018/?replicaSet=trivia-rs",
)

DATABASES["default"]["NAME"] = TEST_DATABASE_BASE
DATABASES["default"]["HOST"] = TEST_DATABASE_URI

# Preserve Django's existing TEST configuration.
# Replacing the entire dictionary can cause KeyError: 'MIRROR'.
DATABASES["default"].setdefault("TEST", {})
DATABASES["default"]["TEST"]["NAME"] = TEST_DATABASE_NAME
DATABASES["default"]["TEST"].setdefault("MIRROR", None)


# ============================================================
# 2. DATABASE SAFETY CHECKS
# ============================================================

# Django tests can create and destroy databases.
# Never allow the test database to have the production name.

APPLICATION_DATABASE_NAME = os.environ.get(
    "MONGODB_DATABASE",
    "trivia",
)

if (
    not TEST_DATABASE_NAME.startswith("test_")
    or TEST_DATABASE_NAME == APPLICATION_DATABASE_NAME
    or TEST_DATABASE_BASE == APPLICATION_DATABASE_NAME
    or TEST_DATABASE_BASE == TEST_DATABASE_NAME
):
    raise ImproperlyConfigured(
        "Unsafe MongoDB test configuration. "
        "Test database names must be isolated from the "
        "application database."
    )


# ============================================================
# 3. BLOCK REMOTE DATABASE CONNECTIONS
# ============================================================

parsed_uri = urlsplit(TEST_DATABASE_URI)

ALLOWED_TEST_HOSTS = {
    "localhost",
    "127.0.0.1",
    "::1",
}

if (
    parsed_uri.scheme != "mongodb"
    or parsed_uri.hostname not in ALLOWED_TEST_HOSTS
    or "," in parsed_uri.netloc
    or parsed_uri.username is not None
):
    raise ImproperlyConfigured(
        "Tests must use a local MongoDB replica set. "
        "Remote MongoDB and Atlas connections are prohibited."
    )


# ============================================================
# 4. CHANNELS CONFIGURATION
# ============================================================

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    }
}


# ============================================================
# 5. CACHE CONFIGURATION
# ============================================================

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    }
}


# ============================================================
# 6. PASSWORD HASHING
# ============================================================

# Faster password hashing during automated tests.
# Never use this configuration in production.

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]


# ============================================================
# 7. CELERY CONFIGURATION
# ============================================================

# Execute Celery tasks immediately during tests.

CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True


# ============================================================
# 8. OTP TESTING CONFIGURATION
# ============================================================

DEBUG = True

# Local SMS provider prevents sending real SMS messages.
SMS_PROVIDER = "accounts.services.authentication.LocalSMS"

TRIVIA_LOCAL_OTP = True

# Never send real emails during automated tests.
EMAIL_BACKEND = (
    "django.core.mail.backends.locmem.EmailBackend"
)


# ============================================================
# 9. PRIVATE FILE STORAGE
# ============================================================

STORAGES["private"] = {
    "BACKEND": "django.core.files.storage.FileSystemStorage",
    "OPTIONS": {
        "location": PRIVATE_MEDIA_ROOT,
    },
}
