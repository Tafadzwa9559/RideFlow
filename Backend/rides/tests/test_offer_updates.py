from django.test import TestCase
from rest_framework.test import APIClient
from rides.tests.helpers import RideFixtures
from rides.services.lifecycle import make_offer, select_offer


class OfferUpdateTests(RideFixtures, TestCase):
    def setUp(self):
        self.setup_ride()
        self.offer = make_offer(self.driver_user, self.ride.pk, 600, note='Preserve')
        self.client = APIClient()
        self.client.force_authenticate(self.driver_user)
        self.url = f'/api/v1/offers/{self.offer.pk}/'

    def test_edit_validates_fare_and_preserves_omitted_fields(self):
        self.assertEqual(self.client.patch(self.url, {'fare_cents': 1}).status_code, 400)
        response = self.client.patch(self.url, {'fare_cents': 700})
        self.assertEqual(response.status_code, 200, response.data)
        self.offer.refresh_from_db()
        self.assertEqual(int(self.offer.amount*100), 700)
        self.assertEqual(self.offer.note, 'Preserve')
        self.assertEqual(self.ride.events.filter(event_type='offer.updated').count(), 1)

    def test_other_drivers_and_post_agreement_edits_rejected(self):
        self.client.force_authenticate(self.other_user)
        self.assertEqual(self.client.patch(self.url, {'fare_cents': 700}).status_code, 403)
        select_offer(self.passenger, self.ride.pk, self.offer.pk)
        self.client.force_authenticate(self.driver_user)
        self.assertIn(self.client.patch(self.url, {'fare_cents': 700}).status_code, [400, 403])
        self.ride.refresh_from_db()
        self.assertEqual(int(self.ride.agreed_fare*100), 600)
