from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from django.contrib.auth import get_user_model
from django.db import close_old_connections
from django.test import TransactionTestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken
from accounts.models import PhoneIdentity


class SessionConcurrencyTests(TransactionTestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='+263771234567')
        PhoneIdentity.objects.create(user=self.user, phone=self.user.username, verified_at=timezone.now())
        self.refresh = RefreshToken.for_user(self.user)
        self.refresh['session_version'] = 0
        self.raw = str(self.refresh)
        self.access = str(self.refresh.access_token)

    def race(self, *actions):
        barrier = Barrier(len(actions))
        def run(action):
            close_old_connections()
            barrier.wait(timeout=10)
            try:
                return action()
            finally:
                close_old_connections()
        with ThreadPoolExecutor(max_workers=len(actions)) as executor:
            return list(executor.map(run, actions))

    def rotate(self):
        return APIClient().post('/api/v1/auth/token/refresh/', {'refresh': self.raw})

    def test_simultaneous_rotation_consumes_refresh_only_once(self):
        responses = self.race(self.rotate, self.rotate)
        self.assertCountEqual([r.status_code for r in responses], [200, 401])
        winner = next(r for r in responses if r.status_code == 200)
        self.assertEqual(APIClient().post('/api/v1/auth/token/refresh/', {'refresh': winner.data['refresh']}).status_code, 200)

    def test_logout_racing_rotation_revokes_every_issued_session(self):
        def logout():
            client = APIClient()
            client.credentials(HTTP_AUTHORIZATION='Bearer '+self.access)
            return client.post('/api/v1/auth/logout/', {})
        rotated, logged_out = self.race(self.rotate, logout)
        self.assertEqual(logged_out.status_code, 204)
        self.assertIn(rotated.status_code, [200, 401])
        access_tokens = [self.access]
        refresh_tokens = [self.raw]
        if rotated.status_code == 200:
            access_tokens.append(rotated.data['access'])
            refresh_tokens.append(rotated.data['refresh'])
        for raw in access_tokens:
            client = APIClient()
            client.credentials(HTTP_AUTHORIZATION='Bearer '+raw)
            self.assertEqual(client.get('/api/v1/auth/me/').status_code, 401)
        for raw in refresh_tokens:
            self.assertEqual(APIClient().post('/api/v1/auth/token/refresh/', {'refresh': raw}).status_code, 401)
