from datetime import timedelta
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from accounts.models import PhoneChallenge, PhoneIdentity
from accounts.services.authentication import LocalSMS


@override_settings(DEBUG=True)
class AuthenticationTests(TestCase):
    phone = '+263771234567'

    def setUp(self):
        cache.clear()
        self.client = APIClient()

    def request_code(self):
        response = self.client.post('/api/v1/auth/otp/request/', {'phone': '0771234567'})
        self.assertEqual(response.status_code, 202, response.data)
        self.assertNotIn('code', response.data)
        return LocalSMS.messages[self.phone]

    def verify(self, code):
        return self.client.post('/api/v1/auth/otp/verify/', {'phone': self.phone, 'code': code})

    def test_phone_otp_login_refresh_and_logout_revoke_all_sessions(self):
        code = self.request_code()
        response = self.verify(code)
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(PhoneIdentity.objects.get().phone, self.phone)
        self.assertFalse(PhoneIdentity.objects.get().user.has_usable_password())
        self.assertEqual(self.verify(code).status_code, 400)
        refreshed = self.client.post('/api/v1/auth/token/refresh/', {'refresh': response.data['refresh']})
        self.assertEqual(refreshed.status_code, 200, refreshed.data)
        self.assertEqual(self.client.post('/api/v1/auth/token/refresh/', {'refresh': response.data['refresh']}).status_code, 401)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + refreshed.data['access'])
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 200)
        self.assertEqual(self.client.post('/api/v1/auth/logout/', {'refresh': refreshed.data['refresh']}).status_code, 204)
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 401)
        self.client.credentials()
        self.assertEqual(self.client.post('/api/v1/auth/token/refresh/', {'refresh': refreshed.data['refresh']}).status_code, 401)

    def test_cooldown_attempt_limit_expiry_and_invalid_phone(self):
        code = self.request_code()
        self.assertEqual(self.client.post('/api/v1/auth/otp/request/', {'phone': self.phone}).status_code, 429)
        bad = '000000' if code != '000000' else '111111'
        for _ in range(5):
            self.assertEqual(self.verify(bad).status_code, 400)
        self.assertEqual(PhoneChallenge.objects.get().attempts, 5)
        self.assertEqual(self.verify(code).status_code, 400)
        PhoneChallenge.objects.update(attempts=0, expires_at=timezone.now()-timedelta(seconds=1))
        self.assertEqual(self.verify(code).status_code, 400)
        self.assertEqual(self.client.post('/api/v1/auth/otp/request/', {'phone': 'abc'}).status_code, 400)

    @override_settings(DEBUG=False)
    def test_local_provider_cannot_deliver_in_production(self):
        with self.assertRaises(RuntimeError):
            LocalSMS().send(self.phone, '123456')

    @override_settings(SMS_PROVIDER='')
    def test_unconfigured_provider_fails_closed(self):
        self.assertEqual(self.client.post('/api/v1/auth/otp/request/', {'phone': self.phone}).status_code, 503)
        self.assertFalse(PhoneChallenge.objects.exists())

    def test_anonymous_access_and_ip_rate_limit(self):
        self.assertEqual(self.client.get('/api/v1/me/').status_code, 401)
        for _ in range(10):
            self.client.post('/api/v1/auth/otp/request/', {'phone': 'invalid'})
        self.assertEqual(self.client.post('/api/v1/auth/otp/request/', {'phone': self.phone}).status_code, 429)
