import os
import subprocess
import sys
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.core.exceptions import ImproperlyConfigured
from django.test import SimpleTestCase, TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import PhoneChallenge, PhoneIdentity
from accounts.test_otp import validate_test_otp_settings
from drivers.models import DriverApplication


class DevelopmentOTPConfigurationTests(SimpleTestCase):
    def config(self, **changes):
        values = dict(
            SETTINGS_MODULE='rideflow.development', DEBUG=True, ALLOWED_HOSTS=['localhost'],
            TRIVIA_TEST_OTP_ENABLED=True, TRIVIA_TEST_OTP_PHONES=['+263771234567'],
            DATABASES={'default': {'ENGINE': 'django_mongodb_backend',
                                  'HOST': 'mongodb://127.0.0.1:27028/?replicaSet=trivia-rs',
                                  'NAME': 'trivia_dev_local'}},
        )
        values.update(changes)
        return SimpleNamespace(**values)

    def test_only_explicit_isolated_development_configuration_is_allowed(self):
        validate_test_otp_settings(self.config())
        for changes in [
            {'SETTINGS_MODULE': 'rideflow.production'},
            {'SETTINGS_MODULE': 'rideflow.settings'},
            {'DEBUG': False},
            {'ALLOWED_HOSTS': ['*']},
            {'ALLOWED_HOSTS': ['trivia-backend-bze2.onrender.com']},
            {'TRIVIA_TEST_OTP_PHONES': []},
            {'TRIVIA_TEST_OTP_PHONES': ['0771234567']},
        ]:
            with self.subTest(changes=changes), self.assertRaises(ImproperlyConfigured):
                validate_test_otp_settings(self.config(**changes))
        for host, name in [
            ('mongodb+srv://production.mongodb.net/', 'trivia_dev_local'),
            ('mongodb://remote.example/', 'trivia_dev_local'),
            ('mongodb://localhost,remote.example/', 'trivia_dev_local'),
            ('mongodb://localhost/production', 'trivia_dev_local'),
            ('mongodb://localhost/', 'trivia'),
        ]:
            with self.subTest(host=host, name=name), self.assertRaises(ImproperlyConfigured):
                validate_test_otp_settings(self.config(DATABASES={'default': {
                    'ENGINE': 'django_mongodb_backend', 'HOST': host, 'NAME': name}}))

    def test_development_database_cannot_equal_application_database(self):
        with patch.dict(os.environ, {'MONGODB_DATABASE': 'trivia_dev_local'}):
            with self.assertRaises(ImproperlyConfigured):
                validate_test_otp_settings(self.config())

    def test_public_render_environment_is_rejected(self):
        for values in [{'RENDER': 'true'}, {'RENDER_EXTERNAL_HOSTNAME': 'example.onrender.com'}]:
            with patch.dict(os.environ, values), self.assertRaises(ImproperlyConfigured):
                validate_test_otp_settings(self.config())

    def test_disabled_default_does_not_change_production_configuration(self):
        validate_test_otp_settings(self.config(
            SETTINGS_MODULE='rideflow.production', DEBUG=False,
            TRIVIA_TEST_OTP_ENABLED=False, TRIVIA_TEST_OTP_PHONES=[]))

    def test_actual_production_settings_refuse_activation_before_connecting(self):
        result = subprocess.run(
            [sys.executable, 'manage.py', 'check', '--settings=rideflow.production'],
            cwd=settings.BASE_DIR,
            env={**os.environ,
                 'PYTHONDONTWRITEBYTECODE': '1',
                 'TRIVIA_TEST_OTP_ENABLED': 'true',
                 'DJANGO_SECRET_KEY': 'production-guard-test-key-not-a-real-secret',
                 'MONGODB_URI': 'mongodb://127.0.0.1:27028/',
                 'REDIS_URL': 'redis://redis.example.test:6379',
                 'CACHE_REDIS_URL': '',
                 'CELERY_BROKER_URL': '',
                 'DJANGO_DEBUG': 'true'},
            capture_output=True, text=True, timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Test OTP is prohibited in production.', result.stderr)


@override_settings(
    SETTINGS_MODULE='rideflow.development', DEBUG=True, ALLOWED_HOSTS=['localhost'],
    TRIVIA_TEST_OTP_ENABLED=True,
    TRIVIA_TEST_OTP_PHONES=['+263771234567', '+263771234568'],
)
class DevelopmentOTPTests(TestCase):
    phone = '+263771234567'

    def setUp(self):
        cache.clear()
        self.client = APIClient(SERVER_NAME='localhost')
        self.provider = patch('accounts.services.authentication.sms_provider')
        self.sms = self.provider.start()
        self.addCleanup(self.provider.stop)

    def request(self, phone=None):
        return self.client.post('/api/v1/auth/otp/request/', {'phone': phone or self.phone})

    def verify(self, code='123456', phone=None):
        return self.client.post('/api/v1/auth/otp/verify/', {
            'phone': phone or self.phone, 'code': code})

    def test_passenger_registration_uses_normal_tokens_and_api_endpoints_without_sms(self):
        response = self.request()
        self.assertEqual(response.status_code, 202, response.data)
        self.assertNotIn('123456', str(response.data))
        self.assertEqual(self.verify('654321').status_code, 400)
        response = self.verify()
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['user']['driver_status'], 'notRegistered')
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + response.data['access'])
        self.assertEqual(self.client.get('/api/v1/users/me/').status_code, 200)
        self.assertEqual(self.client.patch('/api/v1/users/me/', {
            'first_name': 'Development', 'last_name': 'Passenger'}).status_code, 200)
        self.assertEqual(self.client.get('/api/v1/payments/methods/').status_code, 200)
        self.assertEqual(self.client.get('/api/v1/admin/users/').status_code, 403)
        self.client.credentials()
        refreshed = self.client.post('/api/v1/auth/token/refresh/', {'refresh': response.data['refresh']})
        self.assertEqual(refreshed.status_code, 200, refreshed.data)
        self.assertEqual(self.verify().status_code, 400)
        self.sms.assert_not_called()

    def test_new_driver_can_start_real_registration_after_fixed_otp_login(self):
        phone = '+263771234568'
        self.assertEqual(self.request(phone).status_code, 202)
        response = self.verify(phone=phone)
        self.assertEqual(response.status_code, 200, response.data)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + response.data['access'])
        response = self.client.patch('/api/v1/drivers/applications/me/', {
            'legal_name': 'Development Driver'})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['status'], 'draft')
        self.assertEqual(self.client.get('/api/v1/drivers/document-requirements/').status_code, 200)
        self.assertEqual(self.client.get('/api/v1/users/me/').data['driver_status'], 'draft')
        self.sms.assert_not_called()

    def test_driver_login_preserves_existing_status_and_permissions(self):
        user = get_user_model().objects.create_user(username=self.phone)
        PhoneIdentity.objects.create(user=user, phone=self.phone)
        application = DriverApplication.objects.create(user=user, status='draft')
        self.assertEqual(self.request().status_code, 202)
        response = self.verify()
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['user']['driver_status'], 'draft')
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + response.data['access'])
        self.assertEqual(self.client.post('/api/v1/driver/availability/', {'online': True}).status_code, 403)
        application.refresh_from_db()
        self.assertEqual(application.status, 'draft')
        self.sms.assert_not_called()

    def test_non_allowlisted_numbers_cannot_request_or_verify(self):
        self.assertEqual(self.request('+263771234569').status_code, 400)
        self.assertEqual(self.verify(phone='+263771234569').status_code, 400)
        self.assertFalse(PhoneChallenge.objects.exists())
        self.sms.assert_not_called()

    def test_request_expiry_and_attempt_limits_still_apply(self):
        self.assertEqual(self.verify().status_code, 400)
        self.assertEqual(self.request().status_code, 202)
        self.assertEqual(self.request().status_code, 429)
        for _ in range(settings.OTP_MAX_ATTEMPTS):
            self.assertEqual(self.verify('654321').status_code, 400)
        self.assertEqual(self.verify().status_code, 400)
        PhoneChallenge.objects.update(attempts=0, expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.verify().status_code, 400)
        self.sms.assert_not_called()

    def test_disabled_mode_rejects_previously_issued_development_challenge(self):
        self.assertEqual(self.request().status_code, 202)
        with override_settings(TRIVIA_TEST_OTP_ENABLED=False):
            self.assertEqual(self.verify().status_code, 400)
        self.assertFalse(PhoneIdentity.objects.exists())

    def test_production_runtime_guard_rejects_both_endpoints(self):
        for changes in [{'DEBUG': False}, {'SETTINGS_MODULE': 'rideflow.production'}]:
            with self.subTest(changes=changes), override_settings(**changes):
                with self.assertRaises(ImproperlyConfigured):
                    self.request()
                with self.assertRaises(ImproperlyConfigured):
                    self.verify()
        self.sms.assert_not_called()

    def test_administrators_and_disabled_accounts_are_excluded(self):
        for flags in [{'is_staff': True}, {'is_superuser': True}, {'is_active': False}]:
            with self.subTest(flags=flags):
                user = get_user_model().objects.create_user(username=self.phone, **flags)
                self.assertEqual(self.request().status_code, 403)
                self.assertEqual(self.verify().status_code, 403)
                user.delete()
        self.sms.assert_not_called()

    def test_promoting_account_after_request_cannot_issue_admin_tokens(self):
        user = get_user_model().objects.create_user(username='existing-passenger')
        PhoneIdentity.objects.create(user=user, phone=self.phone)
        self.assertEqual(self.request().status_code, 202)
        user.is_staff = True
        user.save(update_fields=['is_staff'])
        self.assertEqual(self.verify().status_code, 403)

    @override_settings(TRIVIA_TEST_OTP_ENABLED=False)
    def test_disabled_mode_keeps_random_code_sms_flow(self):
        with patch('accounts.services.authentication.secrets.randbelow', return_value=654321):
            self.assertEqual(self.request().status_code, 202)
        self.sms.return_value.send.assert_called_once_with(self.phone, '654321')
        self.assertEqual(self.verify().status_code, 400)
        self.assertEqual(self.verify('654321').status_code, 200)

    def test_issued_test_tokens_cannot_be_used_after_promotion_or_disabling(self):
        self.assertEqual(self.request().status_code, 202)
        response = self.verify()
        self.assertEqual(response.status_code, 200)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + response.data['access'])
        # Nested Django overrides reset SETTINGS_MODULE unless it is supplied.
        with override_settings(SETTINGS_MODULE='rideflow.development',
                               TRIVIA_TEST_OTP_PHONES=['+263771234568']):
            self.assertEqual(self.client.get('/api/v1/users/me/').status_code, 401)
        with override_settings(TRIVIA_TEST_OTP_ENABLED=False):
            self.assertEqual(self.client.get('/api/v1/users/me/').status_code, 401)
            self.client.credentials()
            self.assertEqual(self.client.post('/api/v1/auth/token/refresh/', {
                'refresh': response.data['refresh']}).status_code, 401)
        identity = PhoneIdentity.objects.select_related('user').get(phone=self.phone)
        identity.user.is_staff = True
        identity.user.save(update_fields=['is_staff'])
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + response.data['access'])
        self.assertEqual(self.client.get('/api/v1/admin/users/').status_code, 401)
        self.client.credentials()
        self.assertEqual(self.client.post('/api/v1/auth/token/refresh/', {
            'refresh': response.data['refresh']}).status_code, 401)
