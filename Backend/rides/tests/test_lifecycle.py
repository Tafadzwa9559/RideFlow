from datetime import timedelta
from decimal import Decimal
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from notifications.models import Notification
from rides.models import ActiveAssignment, RideOffer, LocationUpdate
from rides.tasks import maintenance, dispatch_request
from .helpers import RideFixtures


class LifecycleTests(RideFixtures, TestCase):
    def setUp(self):
        cache.clear()
        self.setup_ride()
        self.client = APIClient()

    def as_user(self, user):
        self.client.force_authenticate(user)
        return self.client

    def offer(self, user=None, cents=600):
        response = self.as_user(user or self.driver_user).post(f'/api/v1/rides/{self.ride.pk}/offers/', {'fare_cents': cents}, format='json')
        self.assertEqual(response.status_code, 201, response.data)
        return response.data['id']

    def select(self, offer):
        return self.as_user(self.passenger).post(f'/api/v1/rides/{self.ride.pk}/accept/', {'offer_id': offer})

    def test_full_counteroffer_trip_rating_and_unverified_earnings(self):
        dispatch_request(str(self.ride.pk))
        self.assertTrue(Notification.objects.filter(user=self.driver_user, envelope__type='ride.request').exists())
        response = self.as_user(self.driver_user).get('/api/v1/driver/requests/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['results'][0]['passenger_note'], 'Gate')
        offer = self.offer()
        competing = self.offer(self.other_user, 700)
        response = self.as_user(self.passenger).get(f'/api/v1/rides/{self.ride.pk}/offers/')
        self.assertEqual(len(response.data['results']), 2)
        self.assertIsNone(response.data['results'][0]['rating'])
        self.assertEqual(self.select(offer).status_code, 200)
        self.assertEqual(self.select(offer).status_code, 200)
        self.assertEqual(self.select(competing).status_code, 400)
        self.assertEqual(RideOffer.objects.get(pk=competing).status, 'rejected')
        self.assertEqual(ActiveAssignment.objects.count(), 1)
        self.as_user(self.driver_user)
        self.assertEqual(self.client.post(f'/api/v1/rides/{self.ride.pk}/complete/').status_code, 400)
        for action in ['arriving', 'arrived', 'start', 'complete', 'complete']:
            response = self.client.post(f'/api/v1/rides/{self.ride.pk}/{action}/')
            self.assertEqual(response.status_code, 200, (action, response.data))
        self.ride.refresh_from_db()
        self.assertEqual(self.ride.agreed_fare, Decimal('6.00'))
        self.assertEqual(self.ride.payment.amount, Decimal('6.00'))
        self.assertEqual(self.ride.payment.status, 'unverified')
        self.assertIsNotNone(self.ride.completed_at)
        self.assertFalse(ActiveAssignment.objects.exists())
        self.assertEqual(self.client.get('/api/v1/driver/earnings/').data['completed_trips'], 1)
        self.assertEqual(self.client.post(f'/api/v1/rides/{self.ride.pk}/ratings/', {'score': 5}).status_code, 201)
        self.as_user(self.passenger)
        self.assertEqual(self.client.post(f'/api/v1/rides/{self.ride.pk}/ratings/', {'score': 4}).status_code, 201)
        self.assertEqual(self.client.post(f'/api/v1/rides/{self.ride.pk}/ratings/', {'score': 4}).status_code, 200)
        self.assertEqual(self.client.post(f'/api/v1/rides/{self.ride.pk}/start/').status_code, 403)

    def test_unauthorized_or_stale_driver_cannot_offer(self):
        self.assertEqual(self.as_user(self.passenger).post(f'/api/v1/rides/{self.ride.pk}/offers/', {'fare_cents': 600}).status_code, 403)
        for change in [{'status': 'submitted'}, {'status': 'suspended'}, {'last_seen': timezone.now()-timedelta(minutes=10)}, {'latitude': '-19.000000'}]:
            original = {k: getattr(self.driver, k) for k in change}
            for k, v in change.items():
                setattr(self.driver, k, v)
            self.driver.save()
            response = self.as_user(self.driver_user).post(f'/api/v1/rides/{self.ride.pk}/offers/', {'fare_cents': 600})
            self.assertEqual(response.status_code, 403, response.data)
            for k, v in original.items():
                setattr(self.driver, k, v)
        self.driver.save()
        self.assertEqual(self.client.post(f'/api/v1/rides/{self.ride.pk}/offers/', {'fare_cents': 'bad'}).status_code, 400)

    def test_offer_expiry_withdrawal_and_decline(self):
        offer = self.offer()
        RideOffer.objects.filter(pk=offer).update(expires_at=timezone.now()-timedelta(seconds=1))
        self.assertEqual(self.select(offer).status_code, 400)
        maintenance()
        self.assertEqual(RideOffer.objects.get(pk=offer).status, 'expired')
        response = self.as_user(self.other_user).post(f'/api/v1/rides/{self.ride.pk}/offers/', {'decision': 'decline'})
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'declined')

    def test_withdrawal_and_ownership(self):
        offer = self.offer()
        self.assertEqual(self.as_user(self.other_user).post(f'/api/v1/offers/{offer}/withdraw/').status_code, 403)
        self.assertEqual(self.as_user(self.driver_user).post(f'/api/v1/offers/{offer}/withdraw/').status_code, 200)
        self.assertEqual(self.select(offer).status_code, 400)

    def test_cancellation_and_request_expiry(self):
        offer = self.offer()
        self.assertEqual(self.select(offer).status_code, 200)
        self.assertEqual(self.as_user(self.passenger).post(f'/api/v1/rides/{self.ride.pk}/cancel/').status_code, 200)
        self.assertFalse(ActiveAssignment.objects.exists())
        self.assertEqual(self.select(offer).status_code, 400)
        self.assertEqual(self.as_user(self.driver_user).post(f'/api/v1/rides/{self.ride.pk}/start/').status_code, 400)
        other = self.new_ride(self.passenger)
        other.expires_at = timezone.now()-timedelta(seconds=1)
        other.save()
        maintenance()
        other.refresh_from_db()
        self.assertEqual(other.status, 'expired')

    def test_location_only_assigned_participants_and_retention(self):
        offer = self.offer()
        self.offer(self.other_user, 700)
        self.select(offer)
        self.driver.last_seen = timezone.now()-timedelta(seconds=10)
        self.driver.save()
        with self.captureOnCommitCallbacks(execute=True):
            response = self.as_user(self.driver_user).post('/api/v1/drivers/me/location/', {'latitude': '-17.819000', 'longitude': '31.049000'})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(LocationUpdate.objects.count(), 1)
        self.assertFalse(Notification.objects.filter(user=self.other_user, envelope__type='driver.location').exists())
        self.assertTrue(Notification.objects.filter(user=self.passenger, envelope__type='driver.location').exists())
        self.assertEqual(self.client.post('/api/v1/drivers/me/location/', {'latitude': '-17.819000', 'longitude': '31.049000'}).status_code, 429)
        self.assertEqual(self.as_user(self.other_user).get(f'/api/v1/rides/{self.ride.pk}/events/').status_code, 404)

    def test_safety_share_revoke_and_admin_access(self):
        self.as_user(self.passenger)
        response = self.client.post(f'/api/v1/rides/{self.ride.pk}/share/', {'recipient_id': self.other_user.pk})
        self.assertEqual(response.status_code, 201)
        pk = response.data['id']
        self.assertEqual(self.as_user(self.other_user).get(f'/api/v1/safety/shares/{pk}/').status_code, 200)
        self.assertEqual(self.as_user(self.driver_user).get(f'/api/v1/safety/shares/{pk}/').status_code, 404)
        self.as_user(self.passenger).delete(f'/api/v1/safety/shares/{pk}/')
        self.assertEqual(self.as_user(self.other_user).get(f'/api/v1/safety/shares/{pk}/').status_code, 404)
        self.assertEqual(self.client.get('/api/v1/admin/overview/').status_code, 403)
        self.assertEqual(self.client.get('/api/v1/admin/pricing/').status_code, 403)
        self.assertEqual(self.client.post('/api/v1/support/tickets/', {'ride_id': str(self.ride.pk), 'category': 'safety', 'message': 'Test report'}).status_code, 404)
