"""Pure configuration validation, shared by production startup and unit tests."""
from urllib.parse import urlsplit, parse_qs
from django.core.exceptions import ImproperlyConfigured


def validate_production(*, uri, hosts, cors_origins, csrf_origins, storage_backend, bucket):
    try:
        parsed = urlsplit(uri)
        atlas = (parsed.hostname or '').endswith('.mongodb.net')
    except ValueError:
        atlas = False
        parsed = None
    if not parsed or parsed.scheme != 'mongodb+srv' or not atlas:
        raise ImproperlyConfigured('Production requires the secret MongoDB Atlas SRV connection URI.')
    options = {key.lower(): value[-1].lower() for key, value in parse_qs(parsed.query).items()}
    if any(options.get(key) == 'true' for key in ('tlsinsecure', 'tlsallowinvalidcertificates', 'tlsallowinvalidhostnames')) or any(options.get(key) == 'false' for key in ('tls', 'ssl')):
        raise ImproperlyConfigured('Production MongoDB TLS verification cannot be disabled.')
    if not hosts or any(host in {'*', 'localhost', '127.0.0.1', '[::1]'} or host.startswith('.') for host in hosts):
        raise ImproperlyConfigured('Production requires explicit public ALLOWED_HOSTS.')
    for origins in (cors_origins, csrf_origins):
        for origin in origins:
            parsed = urlsplit(origin)
            if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment:
                raise ImproperlyConfigured('Production browser origins must be explicit HTTPS origins.')
    if storage_backend != 'storages.backends.s3.S3Storage' or not bucket:
        raise ImproperlyConfigured('Production requires the configured private shared object-storage bucket.')
