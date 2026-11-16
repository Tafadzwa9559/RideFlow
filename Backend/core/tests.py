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
