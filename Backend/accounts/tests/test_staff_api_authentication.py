from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.test import SimpleTestCase, TransactionTestCase, override_settings
from rest_framework.test import APIClient, APIRequestFactory
from rest_framework_simplejwt.tokens import RefreshToken

from rideflow.urls import staff_documentation


class StaffAuthenticationTests(TransactionTestCase):
    password = 'Transit-Cobalt-Cedar-721'

    def setUp(self):
        self.client = APIClient()
        self.staff = get_user_model().objects.create_user(
            username='dispatcher', email='staff@example.net',
            password=self.password, is_staff=True,
        )
        self.enterContext(patch('accounts.services.passwords.limit'))

    def login(self, identifier='dispatcher', password=None, channel='username', **extra):
        return self.client.post('/api/v1/admin/auth/login/', {
            'channel': channel, 'identifier': identifier,
            'password': self.password if password is None else password,
            **extra,
        }, format='json')

    def refresh(self, token):
        return self.client.post('/api/v1/auth/token/refresh/', {'refresh': token}, format='json')

    def authenticate(self, access):
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access}')

    def test_staff_login_refresh_permission_and_logout(self):
        response = self.login('STAFF@example.net', channel='email')
        self.assertEqual(response.status_code, 200, response.data)
        refresh = self.refresh(response.data['refresh'])
        self.assertEqual(refresh.status_code, 200, refresh.data)
        self.assertEqual(self.refresh(response.data['refresh']).status_code, 401)
        self.authenticate(refresh.data['access'])
        url = '/api/v1/admin/dashboard/overview/'
        self.assertEqual(self.client.get(url).status_code, 403)
        self.staff.user_permissions.add(Permission.objects.get(codename='operate_platform'))
        self.assertEqual(self.client.get(url).status_code, 200)
        self.assertEqual(self.client.get('/api/v1/auth/me/').data['id'], str(self.staff.pk))
        self.assertEqual(self.client.post('/api/v1/auth/logout/').status_code, 204)
        self.assertEqual(self.client.get(url).status_code, 401)
        self.assertEqual(self.refresh(refresh.data['refresh']).status_code, 401)

    def test_invalid_credentials_inactive_staff_and_client_role(self):
        passenger = get_user_model().objects.create_user(username='passenger', password=self.password)
        passenger.user_permissions.add(Permission.objects.get(codename='operate_platform'))
        wrong = self.login(password='wrong')
        self.assertEqual(wrong.status_code, 401)
        self.assertEqual(self.login('passenger', role='admin').data['errors'], wrong.data['errors'])
        self.client.force_authenticate(passenger)
        self.assertEqual(self.client.get('/api/v1/admin/dashboard/overview/').status_code, 403)
        self.client.force_authenticate(None)
        self.staff.is_active = False
        self.staff.save(update_fields=['is_active'])
        self.assertEqual(self.login().data['errors'], wrong.data['errors'])

    def test_phone_login_requires_verification_and_password_change_revokes(self):
        from django.utils import timezone

        from accounts.models import PhoneIdentity

        phone = '+263771234567'
        identity = PhoneIdentity.objects.create(user=self.staff, phone=phone)
        self.assertEqual(self.login(phone, channel='phone').status_code, 401)
        identity.verified_at = timezone.now()
        identity.save(update_fields=['verified_at'])
        result = self.login(phone, channel='phone')
        self.assertEqual(result.status_code, 200, result.data)
        self.staff.set_password('Another-Staff-Password-894')
        self.staff.save(update_fields=['password'])
        self.authenticate(result.data['access'])
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 401)
        self.assertEqual(self.refresh(result.data['refresh']).status_code, 401)

    def test_expiration_demotion_and_unscoped_staff_token(self):
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 401)
        self.authenticate(str(RefreshToken.for_user(self.staff).access_token))
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 401)
        session = self.login().data
        refresh = RefreshToken(session['refresh'])
        expired_access = refresh.access_token
        expired_access.set_exp(lifetime=timedelta(seconds=-1))
        self.authenticate(str(expired_access))
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 401)
        refresh.set_exp(lifetime=timedelta(seconds=-1))
        self.assertEqual(self.refresh(str(refresh)).status_code, 401)

        self.staff.is_staff = False
        self.staff.save(update_fields=['is_staff'])
        self.authenticate(session['access'])
        self.assertEqual(self.client.get('/api/v1/auth/me/').status_code, 401)
        self.assertEqual(self.refresh(session['refresh']).status_code, 401)


class AuthenticationSchemaTests(SimpleTestCase):
    def test_schema_exposes_canonical_authentication_paths(self):
        from drf_spectacular.generators import SchemaGenerator

        paths = SchemaGenerator().get_schema(public=True)['paths']
        for method, suffix in [
            ('post', 'admin/auth/login/'),
            ('post', 'auth/login/'),
            ('post', 'auth/otp/request/'),
            ('post', 'auth/otp/verify/'),
            ('post', 'auth/password/request/'),
            ('post', 'auth/password/verify/'),
            ('post', 'auth/password/reset/'),
            ('post', 'auth/token/refresh/'),
            ('post', 'auth/logout/'),
            ('get', 'auth/me/'),
        ]:
            with self.subTest(suffix=suffix):
                operation = paths[f'/api/v1/{suffix}'][method]
                self.assertIn('Authentication', operation['tags'])
                if method == 'post':
                    self.assertIn('requestBody', operation)
        self.assertIn({'jwtAuth': []}, paths['/api/v1/auth/me/']['get']['security'])

    @override_settings(DEBUG=False)
    def test_staff_documentation_requires_active_staff_session(self):
        from django.contrib.auth.models import AnonymousUser
        from django.http import HttpResponse
        from django.views import View

        class DocumentationView(View):
            def __init__(self, **kwargs):
                super().__init__()
            def get(self, request):
                return HttpResponse('schema')

        # Use the same wrapper as Swagger, ReDoc and the schema views.
        DocumentationView.authentication_classes = []
        DocumentationView.permission_classes = []
        view = staff_documentation(DocumentationView)
        request = APIRequestFactory().get('/api/schema/')
        request.user = AnonymousUser()
        response = view(request)
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response['Location'], '/admin/login/?next=/api/schema/')
        request.user = get_user_model()(is_active=True, is_staff=True)
        self.assertEqual(view(request).status_code, 200)
