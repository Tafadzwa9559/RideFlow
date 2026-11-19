import os
from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from accounts.services import passwords


class PassengerTestingTests(SimpleTestCase):
    @override_settings(SETTINGS_MODULE='rideflow.production')
    def test_production_hides_endpoint_even_with_staging_variables(self):
        with patch.dict(os.environ, TRIVIA_PASSENGER_TEST_ACTOR='507f1f77bcf86cd799439011',
                        TRIVIA_PASSENGER_TEST_PROFILE='507f1f77bcf86cd799439012'):
            with patch.object(passwords, 'limit') as limit:
                response = APIClient().post('/api/v1/auth/passenger-testing/', {}, format='json')
        self.assertEqual(response.status_code, 404)
        limit.assert_not_called()

    def test_testing_login_issues_passenger_token_without_staff_session(self):
        actor = SimpleNamespace(pk='507f1f77bcf86cd799439011', get_session_auth_hash=lambda: 'binding')
        passenger = SimpleNamespace(id='507f1f77bcf86cd799439012')
        identity = SimpleNamespace(user=passenger, session_version=3)
        with (
            patch('accounts.api.passwords.configuration', return_value=(actor.pk, passenger.id)),
            patch.object(passwords, 'limit'),
            patch.object(passwords, 'staff_login', return_value=actor) as login,
            patch('accounts.api.passwords.passenger_profile', return_value=(actor, identity)),
            patch('accounts.api.passwords.profile', return_value={'id': passenger.id}),
            patch('rest_framework_simplejwt.tokens.OutstandingToken.objects.create'),
        ):
            response = APIClient().post('/api/v1/auth/passenger-testing/', {
                'channel': 'username', 'identifier': 'staging-admin', 'password': 'test-only',
            }, format='json')
        login.assert_called_once_with(channel='username', identifier='staging-admin', password='test-only')
        self.assertEqual(response.status_code, 200)
        token = AccessToken(response.data['access'])
        self.assertEqual(token['user_id'], passenger.id)
        self.assertEqual(token['session_version'], 3)
        self.assertNotIn('staff_api_session', token)
