from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest import skipUnless
from django.contrib.auth import get_user_model
from django.db import connection, close_old_connections
from django.test import TransactionTestCase
from rest_framework.exceptions import APIException
from rides.models import ActiveAssignment, Ride, RideOffer
from rides.services.lifecycle import make_offer, select_offer, withdraw, transition
from .helpers import RideFixtures


@skipUnless(connection.vendor == 'mongodb', 'Requires an actual MongoDB replica set')
class MongoConcurrencyTests(RideFixtures, TransactionTestCase):
    def setUp(self):
        self.setup_ride()

    def race(self, *actions):
        barrier = Barrier(len(actions))
        def run(action):
            close_old_connections()
            barrier.wait(timeout=10)
            try:
                action()
                return 'ok'
            except APIException:
                return 'rejected'
            finally:
                close_old_connections()
        with ThreadPoolExecutor(max_workers=len(actions)) as executor:
            return list(executor.map(run, actions))

    def test_two_drivers_one_ride(self):
        a = make_offer(self.driver_user, self.ride.pk, 600)
        b = make_offer(self.other_user, self.ride.pk, 700)
        result = self.race(lambda: select_offer(self.passenger, self.ride.pk, a.pk), lambda: select_offer(self.passenger, self.ride.pk, b.pk))
        self.assertCountEqual(result, ['ok', 'rejected'])
        self.assertEqual(ActiveAssignment.objects.count(), 1)
        self.assertEqual(RideOffer.objects.filter(status='accepted').count(), 1)

    def test_one_driver_two_passengers(self):
        second = get_user_model().objects.create_user(username='second-passenger')
        other_ride = self.new_ride(second)
        a = make_offer(self.driver_user, self.ride.pk, 600)
        b = make_offer(self.driver_user, other_ride.pk, 700)
        result = self.race(lambda: select_offer(self.passenger, self.ride.pk, a.pk), lambda: select_offer(second, other_ride.pk, b.pk))
        self.assertCountEqual(result, ['ok', 'rejected'])
        self.assertEqual(ActiveAssignment.objects.count(), 1)

    def test_selection_races_with_withdrawal(self):
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        result = self.race(lambda: select_offer(self.passenger, self.ride.pk, offer.pk), lambda: withdraw(self.driver_user, offer.pk))
        self.assertCountEqual(result, ['ok', 'rejected'])
        offer.refresh_from_db()
        self.assertIn(offer.status, ['accepted', 'withdrawn'])
        self.assertEqual(ActiveAssignment.objects.count(), int(offer.status == 'accepted'))

    def test_cancellation_races_with_assignment(self):
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        self.race(lambda: select_offer(self.passenger, self.ride.pk, offer.pk), lambda: transition(self.passenger, self.ride.pk, 'cancelled'))
        self.ride.refresh_from_db()
        self.assertEqual(self.ride.status, 'cancelled')
        self.assertFalse(ActiveAssignment.objects.exists())

    def test_repeated_completion_is_idempotent(self):
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        select_offer(self.passenger, self.ride.pk, offer.pk)
        for state in ['arriving', 'arrived', 'inProgress']:
            transition(self.driver_user, self.ride.pk, state)
        self.assertEqual(self.race(lambda: transition(self.driver_user, self.ride.pk, 'completed'), lambda: transition(self.driver_user, self.ride.pk, 'completed')), ['ok', 'ok'])
        self.assertEqual(self.ride.events.filter(event_type='ride.completed').count(), 1)

    def test_duplicate_offer_submission(self):
        self.assertEqual(self.race(lambda: make_offer(self.driver_user, self.ride.pk, 600), lambda: make_offer(self.driver_user, self.ride.pk, 600)), ['ok', 'ok'])
        self.assertEqual(RideOffer.objects.filter(ride=self.ride).count(), 1)

    def test_duplicate_booking_key(self):
        import uuid
        from unittest.mock import patch
        from rides.services.booking import book, quote_route
        from .helpers import ROAD
        transition(self.passenger, self.ride.pk, 'cancelled')
        with patch('rides.services.booking.driving_route', return_value=ROAD):
            quote = quote_route(self.passenger, self.pickup, self.destination, 'Standard', 'USD')
        data = {'quote_id': quote.pk, 'idempotency_key': uuid.uuid4(), 'pickup': self.pickup, 'destination': self.destination,
            'category': 'Standard', 'currency': 'USD', 'fare_cents': quote.suggested_cents, 'payment_method_id': 'cash-usd'}
        with patch('rides.tasks.dispatch_request.delay'):
            self.assertEqual(self.race(lambda: book(self.passenger, data), lambda: book(self.passenger, data)), ['ok', 'ok'])
        self.assertEqual(Ride.objects.filter(passenger=self.passenger, status='searching').count(), 1)

    def test_selection_races_with_vehicle_activation(self):
        from drivers.models import Vehicle
        from rest_framework.test import APIClient
        from rest_framework.exceptions import ValidationError
        previous_vehicle = self.driver.vehicle
        other_vehicle = Vehicle.objects.create(application=self.driver, make='Test', model='Other', year=2021, colour='blue', registration='RACE-VEHICLE', capacity=4, category='Standard', approved=True)
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        def switch_vehicle():
            client = APIClient()
            client.force_authenticate(self.driver_user)
            response = client.post(f'/api/v1/drivers/me/vehicles/{other_vehicle.pk}/activate/')
            if response.status_code != 200:
                raise ValidationError('Vehicle activation lost the race.')
        results = self.race(lambda: select_offer(self.passenger, self.ride.pk, offer.pk), switch_vehicle)
        self.assertCountEqual(results, ['ok', 'rejected'])
        self.ride.refresh_from_db()
        if self.ride.status == 'assigned':
            self.assertEqual(self.ride.assigned_vehicle_id, previous_vehicle.pk)
            self.assertEqual(ActiveAssignment.objects.filter(ride=self.ride).count(), 1)
        else:
            self.assertFalse(ActiveAssignment.objects.filter(ride=self.ride).exists())
