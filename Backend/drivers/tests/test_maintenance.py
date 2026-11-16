from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from drivers.models import DocumentRequirement, DriverDocument, VehicleDocument
from drivers.tasks import document_expiry_alerts
from notifications.models import Notification
from rides.tests.helpers import RideFixtures


class DocumentExpiryTests(RideFixtures, TestCase):
    def setUp(self):
        self.setup_ride()

    def test_retry_and_repeated_schedules_deduplicate_and_preserve_private_data(self):
        self.driver.licence_expires = timezone.localdate()+timedelta(days=5)
        self.driver.save(update_fields=['licence_expires'])
        req = DocumentRequirement.objects.create(code='expiry-test', label='Test', scope='driver')
        DriverDocument.objects.create(application=self.driver, requirement=req, file='secret/identity.png',
            content_type='image/png', approved=True, expires_on=timezone.localdate()+timedelta(days=20))
        VehicleDocument.objects.create(vehicle=self.driver.vehicle, requirement=req, file='secret/vehicle.png',
            content_type='image/png', approved=True, expires_on=timezone.localdate()-timedelta(days=1))
        document_expiry_alerts()
        document_expiry_alerts()
        events = Notification.objects.filter(envelope__type='driver.document.expiry')
        self.assertEqual(events.count(), 3)
        self.assertEqual(set(e.envelope['payload']['milestone'] for e in events), {'7d', '30d', 'expired'})
        self.assertEqual(set(e.user_id for e in events), {self.driver_user.pk})
        self.assertNotIn('secret/', str(list(events.values_list('envelope', flat=True))))

    def test_suspended_and_inactive_drivers_are_not_alerted(self):
        self.driver.licence_expires = timezone.localdate()
        self.driver.status = 'suspended'
        self.driver.save(update_fields=['licence_expires', 'status'])
        document_expiry_alerts()
        self.assertFalse(Notification.objects.filter(envelope__type='driver.document.expiry').exists())
