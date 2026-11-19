import os
import unittest
import uuid
from datetime import timedelta
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core import mail
from django.test import TransactionTestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import EmailIdentity, PhoneIdentity
from accounts.services import passwords
from drivers.models import DriverApplication

TEST_REDIS = os.environ.get('TRIVIA_PASSWORD_TEST_REDIS_URL')
PHONE = '+263771234567'
EMAIL = 'passenger@example.net'
PASSWORD = 'Dining-Train-Atlas-592'
NEW_PASSWORD = 'Horizon-Teak-Glass-187'


class InMemorySMS:
    messages = {}

    def send(self, phone, code):
        self.messages[phone] = code


@unittest.skipUnless(TEST_REDIS, 'Set TRIVIA_PASSWORD_TEST_REDIS_URL to an isolated Redis instance.')
@override_settings(
    PASSWORD_AUTH_REDIS_URL=TEST_REDIS,
    SMS_PROVIDER='accounts.tests.test_password_access.InMemorySMS',
    TRIVIA_RECOVERY_EMAIL_ENABLED=True,
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    DEFAULT_FROM_EMAIL='trivia@example.net',
)
class PasswordAccessTests(TransactionTestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = get_user_model().objects.create_user(
            username=PHONE, email=EMAIL, password=PASSWORD, first_name='Rudo',
        )
        self.identity = PhoneIdentity.objects.create(
            user=self.user, phone=PHONE, verified_at=timezone.now(),
        )
        self.enterContext(override_settings(
            TRIVIA_VERIFIED_RECOVERY_EMAILS={str(self.user.pk): EMAIL},
        ))
        prefix = uuid.uuid4().hex
        run_script = passwords.run_script
        self.enterContext(patch.object(
            passwords, 'run_script',
            side_effect=lambda script, key, *args: run_script(script, f'test:{prefix}:{key}', *args),
        ))
        InMemorySMS.messages.clear()
        mail.outbox = []

    def post(self, path, **body):
        return self.client.post(f'/api/v1/auth/{path}/', body, format='json')

    def login(self, channel='phone', identifier=PHONE, password=PASSWORD):
        return self.post('login', channel=channel, identifier=identifier, password=password)

    def verify(self, channel, identifier, code):
        return self.post('password/verify', channel=channel, identifier=identifier, code=code)

    def request_code(self, channel, identifier):
        response = self.post('password/request', channel=channel, identifier=identifier)
        self.assertEqual(response.status_code, 202)
        self.assertEqual(response.data, {'detail': passwords.ACCEPTED})
        if channel == 'phone':
            return InMemorySMS.messages[PHONE]
        return mail.outbox[-1].body.splitlines()[0].split(': ')[-1]

    def register(self, **overrides):
        fields = {
            'first_name': ' Tariro ', 'last_name': 'Moyo',
            'email': '  NEW@example.net  ', 'password': NEW_PASSWORD,
        }
        return self.post('register', **{**fields, **overrides})

    @override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.PBKDF2PasswordHasher'])
    def test_email_registration_login_refresh_and_logout(self):
        response = self.register()
        self.assertEqual(response.status_code, 201, response.data)
        user = get_user_model().objects.get(email='new@example.net')
        self.assertEqual(response.data, {
            'id': str(user.pk), 'email': user.email, 'email_verified': False,
        })
        self.assertEqual(response['Cache-Control'], 'no-store')
        self.assertEqual((user.first_name, user.last_name), ('Tariro', 'Moyo'))
        self.assertTrue(user.is_active)
        self.assertFalse(user.is_staff or user.is_superuser)
        self.assertTrue(user.check_password(NEW_PASSWORD))
        self.assertNotEqual(user.password, NEW_PASSWORD)
        self.assertIsNone(EmailIdentity.objects.get(user=user).verified_at)
        self.assertFalse(PhoneIdentity.objects.filter(user=user).exists())
        self.assertEqual(self.login('email', user.email, 'incorrect').data['code'], 'INVALID_CREDENTIALS')
        login = self.login('email', ' NEW@EXAMPLE.NET ', NEW_PASSWORD)
        self.assertEqual(login.status_code, 200, login.data)
        self.assertEqual(login.data['user']['phone'], '')
        self.assertEqual(login.data['user']['driver_status'], 'notRegistered')
        refresh = self.post('token/refresh', refresh=login.data['refresh'])
        self.assertEqual(refresh.status_code, 200, refresh.data)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh.data['access']}")
        self.assertEqual(self.client.get('/api/v1/users/me/').data['id'], str(user.pk))
        self.assertEqual(self.client.get('/api/v1/admin/dashboard/overview/').status_code, 403)
        self.assertEqual(self.post('logout').status_code, 204)
        self.assertEqual(self.client.get('/api/v1/users/me/').status_code, 401)
        self.assertEqual(self.post('token/refresh', refresh=refresh.data['refresh']).status_code, 401)

    def test_registration_rejects_duplicate_and_invalid_inputs(self):
        duplicate = self.register(email=f' {EMAIL.upper()} ')
        self.assertEqual(duplicate.status_code, 409, duplicate.data)
        self.assertEqual(duplicate.data['code'], 'DUPLICATE_EMAIL')
        self.assertEqual(self.register().status_code, 201)
        self.assertEqual(self.register(email='new@EXAMPLE.NET').status_code, 409)
        for overrides in [
            {'password': 'short'}, {'password': '12345678901234567890'},
            {'first_name': ' '}, {'last_name': ''}, {'email': 'invalid'},
        ]:
            with self.subTest(overrides=overrides):
                response = self.register(**overrides)
                self.assertEqual(response.status_code, 400, response.data)
                self.assertIn('code', response.data)
        self.assertEqual(EmailIdentity.objects.count(), 1)

    def test_registration_and_staff_login_are_isolated(self):
        self.assertEqual(self.register(role='administrator', is_staff=True).status_code, 400)
        staff = get_user_model().objects.create_superuser(
            username='staff-user', email='staff@example.net', password=PASSWORD,
        )
        self.assertEqual(self.register(email=staff.email.upper()).status_code, 409)
        self.assertEqual(self.login('email', staff.email).status_code, 401)
        self.assertEqual(self.register().status_code, 201)
        response = self.client.post('/api/v1/admin/auth/login/', {
            'channel': 'email', 'identifier': 'new@example.net', 'password': NEW_PASSWORD,
        }, format='json')
        self.assertEqual(response.status_code, 401, response.data)
        self.assertEqual(response.data['code'], 'INVALID_CREDENTIALS')

    def test_unverified_registration_cannot_recover_by_email(self):
        self.assertEqual(self.register().status_code, 201)
        user = get_user_model().objects.get(email='new@example.net')
        with override_settings(TRIVIA_VERIFIED_RECOVERY_EMAILS={str(user.pk): user.email}):
            passwords.deliver_recovery('email', user.email)
            PhoneIdentity.objects.create(user=user, phone='+263772345678', verified_at=timezone.now())
            passwords.deliver_recovery('email', user.email)
        self.assertEqual(mail.outbox, [])
        self.assertEqual(self.verify('email', user.email, '123456').status_code, 400)

    def test_registration_rate_limits_email_and_ip(self):
        self.assertEqual(self.register().status_code, 201)
        for _ in range(4):
            self.assertEqual(self.register().status_code, 409)
        contact_limit = self.register(email='NEW@EXAMPLE.NET')
        self.assertEqual(contact_limit.status_code, 429)
        self.assertEqual(contact_limit.data['code'], 'THROTTLED')
        for _ in range(4):
            self.assertEqual(self.register(email='bad-email').status_code, 400)
        self.assertEqual(self.register(email='distinct@example.net').status_code, 429)

    def test_registration_leaves_phone_otp_available(self):
        self.assertEqual(self.register().status_code, 201)
        phone = '+263772345678'
        response = self.post('otp/request', phone=phone)
        self.assertEqual(response.status_code, 202, response.data)
        response = self.post('otp/verify', phone=phone, code=InMemorySMS.messages[phone])
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['user']['phone'], phone)
        self.assertTrue(PhoneIdentity.objects.get(phone=phone).verified_at)
        self.assertEqual(EmailIdentity.objects.count(), 1)

    def test_phone_email_profile_refresh_and_logout(self):
        response = self.login(identifier='077 123 4567')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['user']['driver_status'], 'notRegistered')
        DriverApplication.objects.create(user=self.user, status='approved')
        response = self.login('email', EMAIL.upper())
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['user']['driver_status'], 'approved')
        refresh = self.post('token/refresh', refresh=response.data['refresh'])
        self.assertEqual(refresh.status_code, 200, refresh.data)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh.data['access']}")
        self.assertEqual(self.client.get('/api/v1/users/me/').data['id'], str(self.user.pk))
        self.assertEqual(self.post('logout').status_code, 204)
        self.assertEqual(self.client.get('/api/v1/users/me/').status_code, 401)
        self.assertEqual(self.post('token/refresh', refresh=refresh.data['refresh']).status_code, 401)

    @override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.PBKDF2PasswordHasher'])
    def test_superuser_login_with_real_redis_and_secure_password_hash(self):
        from django.contrib.auth.hashers import identify_hasher

        staff = get_user_model().objects.create_superuser(
            username='staff-dispatch', email='staff@example.test', password=PASSWORD,
        )
        self.assertEqual(identify_hasher(staff.password).algorithm, 'pbkdf2_sha256')
        url = '/api/v1/admin/auth/login/'
        credentials = {'channel': 'username', 'identifier': staff.username}
        wrong = self.client.post(url, {**credentials, 'password': 'incorrect'}, format='json')
        self.assertEqual(wrong.status_code, 401, wrong.data)
        passenger = self.client.post(url, {
            'channel': 'username', 'identifier': self.user.username, 'password': PASSWORD,
        }, format='json')
        self.assertEqual(passenger.status_code, 401, passenger.data)
        login = self.client.post(url, {**credentials, 'password': PASSWORD}, format='json')
        self.assertEqual(login.status_code, 200, login.data)
        self.assertEqual(login.data['user']['id'], str(staff.pk))
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        self.assertEqual(self.client.get('/api/v1/admin/dashboard/overview/').status_code, 200)
        rotated = self.post('token/refresh', refresh=login.data['refresh'])
        self.assertEqual(rotated.status_code, 200, rotated.data)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {rotated.data['access']}")
        self.assertEqual(self.post('logout').status_code, 204)
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 401)

    def test_generic_credentials_validation_and_limits(self):
        wrong = self.login(password='incorrect')
        unknown = self.login(identifier='+263772345678')
        self.assertEqual(wrong.status_code, 401)
        self.assertEqual(unknown.status_code, 401)
        self.assertEqual(wrong.data['errors'], unknown.data['errors'])
        self.assertEqual(self.login(identifier='bad').status_code, 400)
        self.assertEqual(self.login('email', 'bad').status_code, 400)
        self.assertEqual(self.post('login', channel='phone', identifier=PHONE).status_code, 400)
        for _ in range(7):
            self.assertEqual(self.login(password='incorrect').status_code, 401)
        self.assertEqual(self.login().status_code, 429)
        for _ in range(7):
            self.assertEqual(self.login(identifier='bad').status_code, 400)
        self.assertEqual(self.login(identifier='+263772345678').status_code, 429)
        self.assertEqual(get_user_model().objects.count(), 1)

    def test_phone_recovery_single_use_revokes_sessions(self):
        session = self.login().data
        code = self.request_code('phone', PHONE)
        self.assertEqual(self.post('password/request', channel='phone', identifier=PHONE).status_code, 429)
        result = self.verify('phone', PHONE, code)
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(self.verify('phone', PHONE, code).status_code, 400)
        token = result.data['token']
        self.assertEqual(self.post('password/reset', token=token, password='123').status_code, 400)
        self.assertEqual(self.post('password/reset', token=token, password=NEW_PASSWORD).status_code, 204)
        self.assertEqual(self.post('password/reset', token=token, password=PASSWORD).status_code, 400)
        self.assertEqual(self.post('token/refresh', refresh=session['refresh']).status_code, 401)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {session['access']}")
        self.assertEqual(self.client.get('/api/v1/users/me/').status_code, 401)
        self.assertEqual(self.login().status_code, 401)
        self.assertEqual(self.login(password=NEW_PASSWORD).status_code, 200)

    def test_email_recovery_and_expired_grant(self):
        code = self.request_code('email', EMAIL)
        result = self.verify('email', EMAIL, code)
        self.assertEqual(result.status_code, 200, result.data)
        token = result.data['token']
        with patch('django.core.signing.time.time', return_value=(
            timezone.now() + timedelta(seconds=settings.OTP_TTL_SECONDS + 1)
        ).timestamp()):
            self.assertEqual(self.post('password/reset', token=token, password=NEW_PASSWORD).status_code, 400)
        self.assertEqual(self.post('password/reset', token=token, password=NEW_PASSWORD).status_code, 204)
        self.assertEqual(self.login('email', EMAIL, NEW_PASSWORD).status_code, 200)

    def test_expired_code_and_attempt_limit(self):
        with override_settings(OTP_TTL_SECONDS=1):
            code = self.request_code('phone', PHONE)
        # Expire the Redis challenge immediately to avoid wall-clock sleeps.
        passwords.run_script("return redis.call('EXPIRE', KEYS[1], 0)", passwords.recovery_key('phone', PHONE))
        self.assertEqual(self.verify('phone', PHONE, code).status_code, 400)
        token = self.request_code('email', EMAIL)
        for _ in range(settings.OTP_MAX_ATTEMPTS):
            self.assertEqual(self.verify('email', EMAIL, 'invalid').status_code, 400)
        self.assertEqual(self.verify('email', EMAIL, token).status_code, 400)

    def test_unknown_unverified_and_ambiguous_email_delivery(self):
        with override_settings(TRIVIA_VERIFIED_RECOVERY_EMAILS={}):
            denied = self.post('password/request', channel='email', identifier=EMAIL)
        unknown = self.post('password/request', channel='email', identifier='unknown@example.net')
        self.assertEqual(denied.data, unknown.data)
        self.assertEqual(denied.status_code, 202)
        self.assertEqual(mail.outbox, [])
        get_user_model().objects.create_user(username='legacy-duplicate', email=EMAIL.upper())
        self.assertEqual(self.login('email', EMAIL).status_code, 401)

    @override_settings(SMS_PROVIDER='', TRIVIA_RECOVERY_EMAIL_ENABLED=False)
    def test_delivery_disabled(self):
        for channel, identifier in [('phone', PHONE), ('email', EMAIL)]:
            self.assertEqual(self.post('password/request', channel=channel, identifier=identifier).status_code, 503)
        self.assertEqual(InMemorySMS.messages, {})
        self.assertEqual(mail.outbox, [])

    def test_passwordless_account_can_enroll_with_verified_recovery(self):
        self.user.set_unusable_password()
        self.user.save(update_fields=['password'])
        self.assertEqual(self.login().status_code, 401)
        code = self.request_code('phone', PHONE)
        proof = self.verify('phone', PHONE, code).data['token']
        self.assertEqual(self.post('password/reset', token=proof, password=NEW_PASSWORD).status_code, 204)
        self.assertEqual(self.login(password=NEW_PASSWORD).status_code, 200)
