import uuid
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import Group, Permission
from django.contrib.sessions.backends.db import SessionStore
from django.core.management.base import CommandError
from django.db import connection
from django.test import TestCase
from django.utils import timezone
from bson import ObjectId
from pymongo.errors import OperationFailure
from accounts.models import AuditEvent
from core import transactions
from core.services.transfer import import_snapshot
from drivers.services.matching import nearby_drivers
from rides.tests.helpers import RideFixtures


class MongoCompatibilityTests(TestCase):
    def test_contrib_permissions_sessions_and_jwt_token_keys(self):
        from rest_framework_simplejwt.tokens import RefreshToken
        from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
        user = get_user_model().objects.create_user(username='mongo-staff', password='test-password', is_staff=True)
        self.assertIsInstance(user.pk, ObjectId)
        group = Group.objects.create(name='Mongo reviewer')
        permission = Permission.objects.get(codename='review_driver', content_type__app_label='drivers')
        group.permissions.add(permission)
        user.groups.add(group)
        self.assertTrue(get_user_model().objects.get(pk=user.pk).has_perm('drivers.review_driver'))
        session = SessionStore()
        session['_auth_user_id'] = str(user.pk)
        session.save()
        self.assertEqual(SessionStore(session.session_key)['_auth_user_id'], str(user.pk))
        refresh = RefreshToken.for_user(user)
        self.assertIsInstance(OutstandingToken.objects.get(jti=refresh['jti']).pk, ObjectId)
        refresh.blacklist()
        self.assertIsInstance(BlacklistedToken.objects.get().pk, ObjectId)

    def test_official_transaction_rollback_and_post_commit(self):
        calls = []
        with self.assertRaises(RuntimeError):
            with transactions.atomic():
                transactions.guard('rollback-test', '1')
                AuditEvent.objects.create(action='test.rollback', target='1')
                transactions.on_commit(lambda: calls.append('bad'))
                raise RuntimeError('abort')
        self.assertFalse(AuditEvent.objects.filter(action='test.rollback').exists())
        self.assertEqual(calls, [])
        with transactions.atomic():
            transactions.guard('rollback-test', '1')
            AuditEvent.objects.create(action='test.commit', target='1')
            transactions.on_commit(lambda: calls.append('committed'))
        self.assertEqual(calls, ['committed'])

    def test_transient_transaction_retries_whole_command(self):
        attempts = []
        @transactions.atomic
        def work():
            transactions.guard('retry-test', '1')
            AuditEvent.objects.create(action='test.retry', target='1')
            attempts.append(1)
            if len(attempts) == 1:
                raise OperationFailure('simulated server write conflict', code=112,
                    details={'errorLabels': ['TransientTransactionError']})
        work()
        self.assertEqual(len(attempts), 2)
        self.assertEqual(AuditEvent.objects.filter(action='test.retry').count(), 1)

    def test_unknown_commit_retries_commit_without_rerunning_body(self):
        from unittest.mock import patch
        calls = []
        real_commit = connection.commit_mongo
        commits = []
        def uncertain_commit():
            commits.append(1)
            if len(commits) == 1:
                raise OperationFailure('simulated uncertain commit acknowledgement', details={
                    'errorLabels': ['UnknownTransactionCommitResult']})
            return real_commit()
        @transactions.atomic
        def command():
            calls.append('body')
            transactions.guard('commit-retry', '1')
            AuditEvent.objects.create(action='test.commit_retry', target='1')
        with patch.object(connection, 'commit_mongo', side_effect=uncertain_commit):
            command()
        self.assertEqual(calls, ['body'])
        self.assertEqual(len(commits), 2)
        self.assertEqual(AuditEvent.objects.filter(action='test.commit_retry').count(), 1)

    def test_legacy_fixture_import_reconciles_references_and_preserves_login(self):
        # MySQL-shaped records, including explicit integer FK/M2M identities.
        snapshot = {'format': 1, 'models': {
            'contenttypes.contenttype': [{'id': 1, 'app_label': 'auth', 'model': 'user'}],
            'auth.permission': [{'id': 7, 'name': 'Can view user', 'codename': 'view_user', 'content_type_id': 1}],
            'auth.group': [{'id': 2, 'name': 'Imported readers'}],
            'auth.user': [{'id': 9, 'username': 'imported-user', 'password': make_password('preserved-password'),
                           'is_staff': True, 'date_joined': timezone.now().isoformat()}],
            'auth.group_permissions': [{'id': 30, 'group_id': 2, 'permission_id': 7}],
            'auth.user_groups': [{'id': 31, 'user_id': 9, 'group_id': 2}],
        }}
        planned = import_snapshot(snapshot)
        self.assertFalse(planned['applied'])
        self.assertFalse(get_user_model().objects.filter(username='imported-user').exists())
        result = import_snapshot(snapshot, apply=True)
        self.assertTrue(result['verified'])
        user = get_user_model().objects.get(username='imported-user')
        self.assertTrue(user.check_password('preserved-password'))
        self.assertTrue(user.has_perm('auth.view_user'))
        self.assertIsInstance(user.pk, ObjectId)
        repeated = import_snapshot(snapshot, apply=True)
        self.assertTrue(repeated['verified'])
        self.assertEqual(get_user_model().objects.filter(username='imported-user').count(), 1)

    def test_legacy_import_refuses_dangling_references_or_nonempty_target(self):
        dangling = {'format': 1, 'models': {'auth.user_groups': [{'id': 1, 'user_id': 999, 'group_id': 1}]}}
        with self.assertRaises(CommandError):
            import_snapshot(dangling)
        get_user_model().objects.create_user(username='existing-user')
        with self.assertRaises(CommandError):
            import_snapshot({'format': 1, 'models': {}}, apply=True)


class MongoGeospatialTests(RideFixtures, TestCase):
    def setUp(self):
        self.setup_ride()

    def test_2dsphere_index_filters_distance_and_stale_drivers(self):
        indices = connection.get_collection('drivers_driverapplication').index_information()
        self.assertEqual(indices['driver_location_2dsphere']['key'], [('location', '2dsphere')])
        self.assertEqual(set(d.pk for d in nearby_drivers(self.ride)), {self.driver.pk, self.other_driver.pk})
        self.other_driver.longitude = 35
        self.other_driver.save(update_fields=['longitude'])
        self.assertEqual([d.pk for d in nearby_drivers(self.ride)], [self.driver.pk])
        self.driver.last_seen = timezone.now()-timedelta(hours=1)
        self.driver.save(update_fields=['last_seen'])
        self.assertEqual(list(nearby_drivers(self.ride)), [])


class MigratedTokenTests(TestCase):
    def test_integer_identity_tokens_fail_with_401_instead_of_500(self):
        from rest_framework.test import APIClient
        from rest_framework_simplejwt.tokens import AccessToken, RefreshToken
        access = AccessToken()
        access['user_id'] = 17
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION='Bearer ' + str(access))
        self.assertEqual(client.get('/api/v1/auth/me/').status_code, 401)
        client.credentials()
        refresh = RefreshToken()
        refresh['user_id'] = 17
        self.assertEqual(client.post('/api/v1/auth/token/refresh/', {'refresh': str(refresh)}).status_code, 401)
