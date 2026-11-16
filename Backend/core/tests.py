from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from accounts.models import AuditEvent
from rides.models import PricingZone


class AdministrativeTests(TestCase):
    def setUp(self):
        self.admin = get_user_model().objects.create_superuser(username='administrator', password='test', email='test@example.test')
        self.client = APIClient()
        self.client.force_authenticate(self.admin)

    def test_configuration_audit_and_actual_empty_statistics(self):
        response = self.client.post('/api/v1/admin/service-areas/', {'name': 'Test only', 'enabled': False, 'south': '-18', 'north': '-17', 'west': '30', 'east': '32'})
        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(AuditEvent.objects.filter(action='configuration.created').exists())
        self.assertFalse(PricingZone.objects.get().enabled)
        response = self.client.get('/api/v1/admin/overview/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['rides_by_status'], [])
        self.assertEqual(response.data['completed_agreed_fares_usd'], '0.00')
        bad = self.client.patch(f'/api/v1/admin/service-areas/{PricingZone.objects.get().pk}/', {'south': '20', 'north': '10'})
        self.assertEqual(bad.status_code, 400)

    def test_suspension_and_audit(self):
        user = get_user_model().objects.create_user(username='test-user')
        response = self.client.post(f'/api/v1/admin/users/{user.pk}/status/', {'active': False})
        self.assertEqual(response.status_code, 200)
        user.refresh_from_db()
        self.assertFalse(user.is_active)
        self.assertTrue(AuditEvent.objects.filter(action='account.status').exists())

    def test_health_and_readiness_failure_do_not_expose_details(self):
        self.assertEqual(self.client.get('/health/').status_code, 200)
        from unittest.mock import patch
        with patch('redis.Redis.from_url', side_effect=ConnectionError('private-host-secret')):
            response = self.client.get('/ready/')
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {'status': 'unavailable'})


from django.test import SimpleTestCase, override_settings
from django.core.exceptions import ImproperlyConfigured
from core.production import validate_production


class ProductionConfigurationTests(SimpleTestCase):
    def config(self, **changes):
        data = dict(uri='mongodb+srv://example.mongodb.net/', hosts=['api.example.test'],
            cors_origins=['https://app.example.test'], csrf_origins=['https://api.example.test'],
            storage_backend='storages.backends.s3.S3Storage', bucket='private-test')
        data.update(changes)
        return validate_production(**data)

    def test_secure_configuration_and_insecure_variants(self):
        self.config()
        for changes in [dict(uri='mongodb://localhost:27017/'), dict(hosts=['*']),
                dict(hosts=['localhost']), dict(uri='mongodb+srv://example.mongodb.net/?tlsInsecure=true'), dict(cors_origins=['http://app.example.test']),
                dict(csrf_origins=['https://example.test/path']), dict(bucket=''),
                dict(storage_backend='django.core.files.storage.FileSystemStorage')]:
            with self.subTest(changes=changes), self.assertRaises(ImproperlyConfigured):
                self.config(**changes)

    def test_test_runner_rejects_atlas_before_database_access(self):
        import os
        import subprocess
        import sys
        env = {**os.environ, 'DJANGO_SETTINGS_MODULE': 'rideflow.testing',
            'MONGODB_TEST_URI': 'mongodb+srv://example.mongodb.net/'}
        result = subprocess.run([sys.executable, '-c', 'import rideflow.testing'], env=env,
            capture_output=True, text=True, timeout=20, cwd=__import__('django.conf', fromlist=['settings']).settings.BASE_DIR)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Atlas/remote URIs are prohibited', result.stderr)

    @override_settings(STORAGES={
        'private': {'BACKEND': 'django.core.files.storage.InMemoryStorage'},
        'default': {'BACKEND': 'django.core.files.storage.InMemoryStorage'},
    })
    def test_private_storage_delegates_without_exposing_urls(self):
        from django.core.files.base import ContentFile
        from drivers.models import PrivateStorage
        storage = PrivateStorage()
        name = storage.save('private/test.png', ContentFile(b'test-image'))
        self.assertTrue(storage.exists(name))
        self.assertEqual(storage.size(name), 10)
        with storage.open(name) as content:
            self.assertEqual(content.read(), b'test-image')
        with self.assertRaises(ValueError):
            storage.url(name)
        self.assertEqual(storage.deconstruct()[0], 'drivers.models.PrivateStorage')
        storage.delete(name)
        self.assertFalse(storage.exists(name))

    def test_readiness_failure_is_safe_and_liveness_remains_available(self):
        from unittest.mock import patch
        from django.test import RequestFactory
        from core.views import ready, health
        request = RequestFactory().get('/ready/')
        with (patch('core.views.check_mongodb', side_effect=RuntimeError('secret-uri')),
                patch('core.views.check_redis', return_value=True), patch('core.views.check_celery', return_value=True)):
            response = ready(request)
        self.assertEqual(response.status_code, 503)
        self.assertNotIn(b'secret-uri', response.content)
        self.assertEqual(health(request).status_code, 200)
