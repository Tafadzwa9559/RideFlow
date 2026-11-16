from datetime import timedelta
from io import BytesIO
from tempfile import TemporaryDirectory
from unittest.mock import patch
from PIL import Image
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from accounts.services.authentication import LocalSMS
from drivers.models import DriverDocument, DocumentRequirement, PrivateStorage
from rides.models import PricingZone, PricingConfiguration, Ride
from .helpers import ROAD


@override_settings(DEBUG=True)
class EndToEndTests(TestCase):
    def login(self, phone):
        client = APIClient()
        self.assertEqual(client.post('/api/v1/auth/otp/request/', {'phone': phone}).status_code, 202)
        response = client.post('/api/v1/auth/otp/verify/', {'phone': phone, 'code': LocalSMS.messages[phone]})
        self.assertEqual(response.status_code, 200, response.data)
        client.credentials(HTTP_AUTHORIZATION='Bearer ' + response.data['access'])
        return client

    def test_phone_onboarding_admin_negotiation_trip_and_reporting(self):
        from payments.tests.fixtures import direct_methods
        direct_methods()
        cache.clear()
        passenger = self.login('+263771234567')
        driver = self.login('+263772345678')
        admin = APIClient()
        admin.force_authenticate(get_user_model().objects.create_superuser(username='admin', email='admin@example.test', password='test'))
        DocumentRequirement.objects.create(code='test-id', label='Test requirement', expiry_required=False)
        zone = PricingZone.objects.create(name='Test area', enabled=True, south=-18, north=-17, west=30, east=32)
        PricingConfiguration.objects.create(zone=zone, category='Standard', enabled=True, base_fare_usd=1, per_km_usd='.5', per_minute_usd='.1', minimum_offer_usd=2, maximum_offer_usd=50)
        response = driver.patch('/api/v1/drivers/applications/me/', {'legal_name': 'Integration Driver', 'licence_number': 'TEST', 'licence_class': 'TEST',
            'licence_expires': str(timezone.localdate()+timedelta(days=300)), 'vehicle': {'make': 'Test', 'model': 'Car', 'year': 2020, 'colour': 'white', 'registration': 'E2E-TEST', 'capacity': 4, 'category': 'Standard'}}, format='json')
        self.assertEqual(response.status_code, 200, response.data)
        app_id = response.data['id']
        image = BytesIO()
        Image.new('RGB', (4, 4)).save(image, 'PNG')
        with TemporaryDirectory() as directory, override_settings(PRIVATE_MEDIA_ROOT=directory):
            field = DriverDocument._meta.get_field('file')
            original = field.storage
            field.storage = PrivateStorage()
            try:
                uploaded = driver.post('/api/v1/drivers/applications/me/documents/', {'requirement': 'test-id', 'file': SimpleUploadedFile('document.png', image.getvalue())})
                self.assertEqual(uploaded.status_code, 201, uploaded.data)
                self.assertEqual(driver.post('/api/v1/drivers/applications/me/submit/').status_code, 200)
                self.assertEqual(admin.post(f'/api/v1/admin/drivers/{app_id}/review/', {'decision': 'approved'}).status_code, 200)
                self.assertEqual(driver.post('/api/v1/drivers/me/location/', {'latitude': '-17.820000', 'longitude': '31.050000'}).status_code, 200)
                self.assertEqual(driver.post('/api/v1/drivers/me/go-online/').status_code, 200)
                with patch('rides.services.booking.driving_route', return_value=ROAD):
                    quote = passenger.post('/api/v1/routes/quote/', {'pickup': {'name': 'Pickup', 'latitude': -17.82, 'longitude': 31.05}, 'destination': {'name': 'Destination', 'latitude': -17.8, 'longitude': 31.03}, 'category': 'Standard', 'currency': 'USD'}, format='json')
                self.assertEqual(quote.status_code, 201, quote.data)
                import uuid
                from rides.models import FareQuote
                q = FareQuote.objects.get(pk=quote.data['id'])
                response = passenger.post('/api/v1/rides/', {'pickup': q.pickup, 'destination': q.destination, 'category': 'Standard', 'currency': 'USD',
                    'quote_id': str(q.pk), 'idempotency_key': str(uuid.uuid4()), 'fare_cents': 400, 'payment_method_id': 'ecocash', 'passenger_note': 'Main entrance'}, format='json')
                self.assertEqual(response.status_code, 201, response.data)
                ride_id = response.data['id']
                self.assertEqual(driver.get('/api/v1/driver/requests/').data['results'][0]['id'], ride_id)
                offer = driver.post(f'/api/v1/rides/{ride_id}/offers/', {'fare_cents': 600})
                self.assertEqual(offer.status_code, 201, offer.data)
                self.assertEqual(len(passenger.get(f'/api/v1/rides/{ride_id}/offers/').data['results']), 1)
                self.assertEqual(passenger.post(f'/api/v1/rides/{ride_id}/select-offer/', {'offer_id': offer.data['id']}).status_code, 200)
                for action in ['arriving', 'arrived', 'start', 'complete']:
                    self.assertEqual(driver.post(f'/api/v1/rides/{ride_id}/{action}/').status_code, 200)
                self.assertEqual(passenger.post(f'/api/v1/rides/{ride_id}/ratings/', {'score': 5}).status_code, 201)
                self.assertEqual(driver.get('/api/v1/driver/earnings/').data['completed_trips'], 1)
                self.assertEqual(admin.get('/api/v1/admin/overview/').data['completed_agreed_fares_usd'], '6.00')
                ride = Ride.objects.get(pk=ride_id)
                self.assertEqual(ride.payment_preference, 'ecocash')
                self.assertEqual(ride.payment.status, 'unverified')
            finally:
                field.storage = original
