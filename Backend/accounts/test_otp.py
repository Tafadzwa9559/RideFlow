"""Fail-closed configuration for isolated development OTP testing."""
import os
from urllib.parse import urlsplit

import phonenumbers
from django.core.exceptions import ImproperlyConfigured


DEVELOPMENT_CODE = '123456'
DEVELOPMENT_DIGEST_PREFIX = 'development_otp$'


def validate_test_otp_settings(config):
    if not config.TRIVIA_TEST_OTP_ENABLED:
        return
    database = config.DATABASES['default']
    uri = urlsplit(database.get('HOST', ''))
    name = database.get('NAME', '')
    if (
        config.SETTINGS_MODULE != 'rideflow.development'
        or not config.DEBUG
        or bool(os.environ.get('RENDER_EXTERNAL_HOSTNAME'))
        or os.environ.get('RENDER', '').lower() == 'true'
        or not config.ALLOWED_HOSTS
        or any(host not in {'localhost', '127.0.0.1', '[::1]', '10.0.2.2'}
               for host in config.ALLOWED_HOSTS)
        or database.get('ENGINE') != 'django_mongodb_backend'
        or uri.scheme != 'mongodb'
        or uri.hostname not in {'localhost', '127.0.0.1', '::1'}
        or ',' in uri.netloc
        or uri.path not in {'', '/'}
        or not name.startswith(('trivia_dev_', 'test_trivia_dev_'))
        or name == os.environ.get('MONGODB_DATABASE', 'trivia')
    ):
        raise ImproperlyConfigured(
            'Test OTP requires rideflow.development, DEBUG and a local trivia_dev_* database.'
        )
    phones = config.TRIVIA_TEST_OTP_PHONES
    if not phones:
        raise ImproperlyConfigured('Test OTP requires an explicit TRIVIA_TEST_OTP_PHONES allowlist.')
    for value in phones:
        try:
            phone = phonenumbers.parse(value, None)
            valid = phonenumbers.is_valid_number(phone) and value == phonenumbers.format_number(
                phone, phonenumbers.PhoneNumberFormat.E164)
        except phonenumbers.NumberParseException:
            valid = False
        if not valid:
            raise ImproperlyConfigured('Test OTP phone numbers must use valid E.164 format.')
