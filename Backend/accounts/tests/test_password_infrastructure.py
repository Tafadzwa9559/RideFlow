import os
import runpy
from unittest.mock import patch

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.test import SimpleTestCase, override_settings
from redis.exceptions import ConnectionError, NoPermissionError, TimeoutError
from rest_framework.test import APIClient

from accounts.services import passwords


class PasswordInfrastructureTests(SimpleTestCase):
    def test_render_requires_non_loopback_redis_without_exposing_configuration(self):
        for url in ('', 'redis://test:private-secret@127.0.0.1:6379/0',
                    'rediss://test:private-secret@redis.example.test?ssl_cert_reqs=none'):
            with self.subTest(configured=bool(url)), patch.dict(os.environ, RENDER='true', REDIS_URL=url):
                with self.assertRaises(ImproperlyConfigured) as raised:
                    runpy.run_path(str(settings.BASE_DIR / 'rideflow' / 'settings.py'))
                self.assertIn('REDIS_URL', str(raised.exception))
                self.assertNotIn('private-secret', str(raised.exception))

    def test_render_can_share_a_tls_url_with_verified_connections(self):
        url = 'rediss://redis.example.test:6380/0'
        with patch.dict(os.environ, RENDER='true', REDIS_URL=url, CACHE_REDIS_URL='', CELERY_BROKER_URL=''):
            config = runpy.run_path(str(settings.BASE_DIR / 'rideflow' / 'settings.py'))
        self.assertEqual(config['PASSWORD_AUTH_REDIS_URL'], url)
        self.assertEqual(config['CELERY_BROKER_URL'], url)
        for options in (config['CHANNEL_LAYERS']['default']['CONFIG']['hosts'][0],
                        config['CACHES']['default']['OPTIONS'], config['CELERY_BROKER_USE_SSL']):
            self.assertEqual(options['ssl_cert_reqs'], 'required')
            self.assertTrue(options['ssl_check_hostname'])

    @override_settings(SMS_PROVIDER='', TRIVIA_TEST_OTP_ENABLED=False, TRIVIA_LOCAL_OTP=False)
    def test_disabled_sms_returns_503_without_starting_a_database_transaction(self):
        response = APIClient().post('/api/v1/auth/otp/request/', {'phone': '+263771234567'}, format='json')
        self.assertEqual(response.status_code, 503)

    def test_cache_url_prefers_dedicated_service_then_shared_service(self):
        shared = 'rediss://shared-cache.example.test:6380/0'
        dedicated = 'rediss://password-cache.example.test:6380/0'
        for explicit, expected in [(dedicated, dedicated), ('', shared)]:
            with self.subTest(dedicated=bool(explicit)), patch.dict(
                os.environ, CACHE_REDIS_URL=explicit, REDIS_URL=shared,
            ):
                config = runpy.run_path(str(settings.BASE_DIR / 'rideflow' / 'settings.py'))
                self.assertEqual(config['PASSWORD_AUTH_REDIS_URL'], expected)
                self.assertEqual(config['CACHES']['default']['LOCATION'], expected)

    def test_redis_errors_return_sanitized_503_before_credentials_are_checked(self):
        for error_type in (ConnectionError, TimeoutError, NoPermissionError):
            with self.subTest(error=error_type.__name__), patch.object(
                passwords, 'redis_client',
            ) as redis_client, self.assertLogs(passwords.logger, 'ERROR') as logs:
                redis_client.return_value.eval.side_effect = error_type('private diagnostic')
                response = APIClient().post('/api/v1/admin/auth/login/', {}, format='json')
                self.assertEqual(response.status_code, 503)
                self.assertIn(error_type.__name__, logs.output[0])
                self.assertEqual(logs.records[0].request_id, response['X-Request-ID'])
                self.assertNotIn('private diagnostic', str(response.data))
                self.assertNotIn('private diagnostic', str(logs.output))

    @override_settings(PASSWORD_AUTH_REDIS_URL='invalid-redis-url')
    def test_malformed_redis_url_fails_closed(self):
        with self.assertLogs(passwords.logger, 'ERROR'):
            response = APIClient().post('/api/v1/admin/auth/login/', {}, format='json')
        self.assertEqual(response.status_code, 503)

    def test_unexpected_exception_is_not_relabelled_as_redis_outage(self):
        with patch.object(passwords, 'redis_client') as redis_client:
            redis_client.return_value.eval.side_effect = RuntimeError('unexpected')
            with self.assertRaisesRegex(RuntimeError, 'unexpected'):
                passwords.run_script('return 1', 'test:password-redis')

    def test_readiness_fails_when_only_password_redis_is_down(self):
        with (
            patch('core.views.check_mongodb', return_value=True),
            patch('core.views.check_redis', return_value=True),
            patch('core.views.check_celery', return_value=True),
            patch.object(passwords, 'redis_client') as redis_client,
        ):
            redis_client.return_value.eval.side_effect = ConnectionError('private diagnostic')
            response = self.client.get('/ready/')
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {'status': 'unavailable'})
