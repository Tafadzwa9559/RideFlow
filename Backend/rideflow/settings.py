"""Django settings for Trivia (RideFlow backend).

Production configuration is supplied via environment variables (Render).
MongoDB Atlas is the primary application database.
"""

import os
from datetime import timedelta
from pathlib import Path

import environ
from django.core.exceptions import ImproperlyConfigured


BASE_DIR = Path(__file__).resolve().parent.parent
# Load .env locally; on Render, configured environment variables take precedence.
environ.Env.read_env(BASE_DIR / ".env", overwrite=False)


def env_bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).strip().lower() in {
        "1", "true", "yes", "on"
    }


def env_list(name: str, default: str = "") -> list[str]:
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]


# ------------------------------------------------------------
# Security and reverse proxy (Render)
# ------------------------------------------------------------
DEBUG = env_bool("DJANGO_DEBUG", False)
SECRET_KEY = (
    os.environ.get("TRIVIA_DEV_SECRET_KEY", "")
    if os.environ.get("DJANGO_SETTINGS_MODULE") == "rideflow.development"
    else os.environ.get("DJANGO_SECRET_KEY", "")
)
if not SECRET_KEY:
    if os.environ.get("DJANGO_SETTINGS_MODULE") == "rideflow.testing":
        SECRET_KEY = "test-only-secret-key-not-for-production-0123456789"
    else:
        raise ImproperlyConfigured("Set DJANGO_SECRET_KEY in the environment.")

ALLOWED_HOSTS = env_list(
    "ALLOWED_HOSTS",
    os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1"),
)
RENDER_EXTERNAL_HOSTNAME = os.environ.get("RENDER_EXTERNAL_HOSTNAME", "").strip()
if RENDER_EXTERNAL_HOSTNAME and RENDER_EXTERNAL_HOSTNAME not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append(RENDER_EXTERNAL_HOSTNAME)

# Only trust X-Forwarded-Proto when deployed behind a controlled proxy (Render).
# Never accept untrusted forwarded headers on an arbitrary directly exposed server.
if RENDER_EXTERNAL_HOSTNAME:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# CSRF trusted origins are independent of CORS. Include the https:// scheme.
CSRF_TRUSTED_ORIGINS = env_list(
    "DJANGO_CSRF_TRUSTED_ORIGINS",
    "https://trivia-backend-bze2.onrender.com" if RENDER_EXTERNAL_HOSTNAME else "",
)
if RENDER_EXTERNAL_HOSTNAME:
    render_origin = f"https://{RENDER_EXTERNAL_HOSTNAME}"
    if render_origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(render_origin)

SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SAMESITE = "Lax"

# Add production React frontend origins explicitly when available.
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS", "http://localhost:5173")


# ------------------------------------------------------------
# Applications and middleware
# ------------------------------------------------------------
INSTALLED_APPS = [
    "rideflow.apps.MongoAdminConfig",
    "rideflow.apps.MongoAuthConfig",
    "rideflow.apps.MongoContentTypesConfig",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "django_filters",
    "drf_spectacular",
    "channels",
    "corsheaders",
    "accounts",
    "drivers",
    "notifications",
    "rides",
    "payments",
    "core.apps.CoreConfig",
]

MIDDLEWARE = [
    "core.middleware.RequestIDMiddleware",
    "django.middleware.security.SecurityMiddleware",
    # Requires the 'whitenoise' Python package in requirements.txt.
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "rideflow.urls"
WSGI_APPLICATION = "rideflow.wsgi.application"
ASGI_APPLICATION = "rideflow.asgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ]
        },
    }
]

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Africa/Harare"
USE_I18N = True
USE_TZ = True


# ------------------------------------------------------------
# MongoDB Atlas (only primary application database)
# ------------------------------------------------------------
DEFAULT_AUTO_FIELD = "django_mongodb_backend.fields.ObjectIdAutoField"
DATABASES = {
    "default": {
        "ENGINE": "django_mongodb_backend",
        "HOST": os.environ.get("MONGODB_URI", "mongodb://localhost:27017/"),
        "NAME": os.environ.get("MONGODB_DATABASE", "trivia"),
        "OPTIONS": {
            "serverSelectionTimeoutMS": 5000,
            "uuidRepresentation": "standard",
            "w": "majority",
            "retryWrites": True,
        },
    }
}
MIGRATION_MODULES = {
    app: f"mongo_migrations.{app}"
    for app in [
        "admin", "auth", "contenttypes", "sessions", "token_blacklist",
        "accounts", "drivers", "rides", "payments", "notifications", "core",
    ]
}


# ------------------------------------------------------------
# Static files and protected uploads
# ------------------------------------------------------------
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"
    },
}
# Local directory is not durable on Render. Use private object storage before
# accepting actual identity documents and driver uploads in production.
PRIVATE_MEDIA_ROOT = Path(
    os.environ.get("PRIVATE_MEDIA_ROOT", str(BASE_DIR / "private_media"))
)
# Shared private storage for disposable/scaled Render processes.
PRIVATE_STORAGE_BACKEND = os.environ.get('PRIVATE_STORAGE_BACKEND', 'django.core.files.storage.FileSystemStorage')
PRIVATE_STORAGE_BUCKET = os.environ.get('PRIVATE_STORAGE_BUCKET', '')
if PRIVATE_STORAGE_BACKEND == 'storages.backends.s3.S3Storage':
    STORAGES['private'] = {
        'BACKEND': PRIVATE_STORAGE_BACKEND,
        'OPTIONS': {
            'bucket_name': PRIVATE_STORAGE_BUCKET,
            'region_name': os.environ.get('PRIVATE_STORAGE_REGION') or None,
            'endpoint_url': os.environ.get('PRIVATE_STORAGE_ENDPOINT') or None,
            'access_key': os.environ.get('PRIVATE_STORAGE_ACCESS_KEY') or None,
            'secret_key': os.environ.get('PRIVATE_STORAGE_SECRET_KEY') or None,
            'default_acl': None, 'custom_domain': None,
            'querystring_auth': True, 'file_overwrite': False,
            'object_parameters': {'CacheControl': 'private, no-store'},
        },
    }
else:
    STORAGES['private'] = {
        'BACKEND': 'django.core.files.storage.FileSystemStorage',
        'OPTIONS': {'location': PRIVATE_MEDIA_ROOT},
    }

DRIVER_DOCUMENT_MAX_BYTES = 5 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = 6 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024


# ------------------------------------------------------------
# REST API / JWT / documentation
# ------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "accounts.authentication.SessionJWTAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_SCHEMA_CLASS": "core.schema.TriviaAutoSchema",
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,
    "EXCEPTION_HANDLER": "core.errors.exception_handler",
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.ScopedRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {
        "quotes": "30/min", "places": "30/min",
        "otp_request": "10/hour", "otp_verify": "30/hour",
    },
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "core.identifiers.MongoJSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ],
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(
        minutes=int(os.environ.get("JWT_ACCESS_TOKEN_MINUTES", "10"))
    ),
    "REFRESH_TOKEN_LIFETIME": timedelta(
        days=int(os.environ.get("JWT_REFRESH_TOKEN_DAYS", "7"))
    ),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Trivia API",
    "DESCRIPTION": (
        "Official REST API for Trivia — MOrdec Solutions (Private) Limited. "
        "USD only; Cash, EcoCash and OneMoney are direct-payment preferences. "
        "Trivia does not collect or verify fares. "
        "[WebSocket protocol](/api/websockets/)."
    ),
    "VERSION": "1.0.0",
    "COMPONENT_SPLIT_REQUEST": True,
    "SERVE_INCLUDE_SCHEMA": False,
    "SWAGGER_UI_SETTINGS": {
        "persistAuthorization": False,
        "displayRequestDuration": True,
    },
    "PREPROCESSING_HOOKS": ["core.schema.canonical_paths"],
    "POSTPROCESSING_HOOKS": [
        "drf_spectacular.hooks.postprocess_schema_enums",
        "core.schema.examples_hook",
    ],
    "ENUM_NAME_OVERRIDES": {
        "RideCategoryEnum": [
            ("Standard", "Trivia Standard"),
            ("Comfort", "Trivia Comfort"),
            ("XL", "Trivia XL"),
        ],
        "VehicleCategoryEnum": ["Standard", "Comfort", "XL"],
        "TicketCategoryEnum": ["support", "safety"],
        "CurrencyEnum": ["USD"],
        "OfferStatusEnum": [
            "pending", "accepted", "rejected", "withdrawn", "expired", "declined"
        ],
        "TicketStatusEnum": ["open", "investigating", "resolved"],
    },
    "PATH_CONVERTER_OVERRIDES": {
        "objectid": {"type": "string", "pattern": "^[0-9a-fA-F]{24}$"}
    },
}


# ------------------------------------------------------------
# Routing, location and ride operational configuration
# ------------------------------------------------------------
TRIVIA_ROUTING_URL = os.environ.get("TRIVIA_ROUTING_URL", "")
TRIVIA_GEOCODING_URL = os.environ.get("TRIVIA_GEOCODING_URL", "")
TRIVIA_MAX_SNAP_METRES = int(os.environ.get("TRIVIA_MAX_SNAP_METRES", "250"))
TRIVIA_QUOTE_TTL_SECONDS = int(os.environ.get("TRIVIA_QUOTE_TTL_SECONDS", "300"))
TRIVIA_EXCHANGE_MAX_AGE_SECONDS = int(
    os.environ.get("TRIVIA_EXCHANGE_MAX_AGE_SECONDS", "86400")
)
TRIVIA_EXCHANGE_SOURCE_HOSTS = env_list(
    "TRIVIA_EXCHANGE_SOURCE_HOSTS", "www.rbz.co.zw,rbz.co.zw"
)

DRIVER_LOCATION_TTL = int(os.environ.get("DRIVER_LOCATION_TTL", "90"))
DRIVER_LOCATION_MIN_INTERVAL = int(os.environ.get("DRIVER_LOCATION_MIN_INTERVAL", "3"))
DRIVER_MATCH_RADIUS_KM = float(os.environ.get("DRIVER_MATCH_RADIUS_KM", "8"))
RIDE_REQUEST_TTL = int(os.environ.get("RIDE_REQUEST_TTL", "300"))
OFFER_TTL = int(os.environ.get("OFFER_TTL", "90"))
LOCATION_RETENTION_DAYS = int(os.environ.get("LOCATION_RETENTION_DAYS", "7"))


# ------------------------------------------------------------
# Redis / Channels / Celery
# ------------------------------------------------------------
REDIS_URL = os.environ.get("REDIS_URL", "redis://127.0.0.1:6379/0")
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_URL]},
    }
}
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": os.environ.get("CACHE_REDIS_URL", "redis://127.0.0.1:6379/2"),
    }
}
CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://127.0.0.1:6379/1")
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_TASK_SOFT_TIME_LIMIT = 240
CELERY_TASK_TIME_LIMIT = 300
CELERY_BROKER_TRANSPORT_OPTIONS = {"visibility_timeout": 600}
CELERY_TASK_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TIMEZONE = "UTC"
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = True
CELERY_BEAT_SCHEDULE = {
    "maintenance": {"task": "rides.tasks.maintenance", "schedule": 15.0},
    "event-outbox": {"task": "notifications.tasks.deliver_outbox", "schedule": 2.0},
    "document-expiry": {"task": "drivers.tasks.document_expiry_alerts", "schedule": 86400.0},
    "retention": {"task": "rides.tasks.retention", "schedule": 3600.0},
}


# ------------------------------------------------------------
# Notifications, OTP, logging
# ------------------------------------------------------------
SMS_PROVIDER = os.environ.get("SMS_PROVIDER", "")
PUSH_PROVIDER = os.environ.get("PUSH_PROVIDER", "")
TRIVIA_LOCAL_OTP = env_bool("TRIVIA_LOCAL_OTP", False)
TRIVIA_TEST_OTP_ENABLED = env_bool("TRIVIA_TEST_OTP_ENABLED", False)
TRIVIA_TEST_OTP_PHONES = env_list("TRIVIA_TEST_OTP_PHONES")
OTP_TTL_SECONDS = 300
OTP_RESEND_SECONDS = 60
OTP_MAX_ATTEMPTS = 5

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {"json": {"()": "core.middleware.JSONFormatter"}},
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "json"}
    },
    "root": {"handlers": ["console"], "level": "INFO"},
}
