import uuid
from datetime import timedelta
from decimal import Decimal
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.utils import timezone
from drivers.models import DriverApplication, Vehicle
from rides.models import PricingZone, PricingConfiguration
from rides.services.booking import quote_route, book

ROAD = {'distance_metres': 5800, 'duration_seconds': 720, 'geometry': [[31.05, -17.82], [31.03, -17.80]], 'provider': 'test-only'}


class RideFixtures:
    def setup_ride(self):
        from payments.models import PaymentMethod
        PaymentMethod.objects.get_or_create(code='cash-usd', defaults={'name': 'Cash', 'kind': 'cash', 'supported_currencies': ['USD'], 'enabled': True})
        self.passenger = get_user_model().objects.create_user(username='passenger')
        self.driver_user = get_user_model().objects.create_user(username='driver', first_name='Test Driver')
        self.other_user = get_user_model().objects.create_user(username='other')
        self.driver = self.new_driver(self.driver_user, 'TEST-1')
        self.other_driver = self.new_driver(self.other_user, 'TEST-2')
        self.zone = PricingZone.objects.create(name='Test only', enabled=True, south=-18, north=-17, west=30, east=32)
        self.pricing = PricingConfiguration.objects.create(zone=self.zone, category='Standard', enabled=True,
            base_fare_usd=1, per_km_usd='.50', per_minute_usd='.10', minimum_offer_usd=2, maximum_offer_usd=50)
        self.pickup = {'name': 'Test pickup', 'latitude': -17.82, 'longitude': 31.05}
        self.destination = {'name': 'Test destination', 'latitude': -17.80, 'longitude': 31.03}
        self.ride = self.new_ride(self.passenger)

    def new_driver(self, user, registration):
        app = DriverApplication.objects.create(user=user, status='approved', licence_expires=timezone.localdate()+timedelta(days=365),
            availability='online', latitude='-17.820000', longitude='31.050000', last_seen=timezone.now())
        vehicle = Vehicle.objects.create(application=app, make='Test', model='Test', year=2020, colour='white', registration=registration, capacity=4, category='Standard', approved=True)
        app.active_vehicle = vehicle
        app.save(update_fields=['active_vehicle'])
        return app

    def new_ride(self, user):
        with patch('rides.services.booking.driving_route', return_value=ROAD), patch('rides.tasks.dispatch_request.delay'):
            quote = quote_route(user, self.pickup, self.destination, 'Standard', 'USD')
            ride, _ = book(user, {'quote_id': quote.pk, 'idempotency_key': uuid.uuid4(), 'pickup': self.pickup, 'destination': self.destination,
                'category': 'Standard', 'currency': 'USD', 'fare_cents': quote.suggested_cents, 'payment_method_id': 'cash-usd', 'passenger_note': 'Gate'})
            return ride
