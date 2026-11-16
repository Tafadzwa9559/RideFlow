import uuid
from datetime import timedelta
from decimal import Decimal
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from payments.models import ExchangeRate, Payment, PaymentMethod
from rides.models import (
    FareQuote,
    PricingConfiguration,
    PricingZone,
    Ride,
    TimeAdjustment,
)

# Deterministic provider fixture: never used outside tests or exposed as live data.
ROAD = {
    "distance_metres": 5800,
    "duration_seconds": 720,
    "geometry": [[31.05, -17.82], [31.04, -17.81], [31.03, -17.80]],
    "provider": "test-road-provider",
}


class BookingAPITests(TestCase):
    def setUp(self):
        from payments.tests.fixtures import direct_methods
        direct_methods()
        cache.clear()
        self.user = get_user_model().objects.create_user(
            username="+263771234567", password=None, first_name="Test"
        )
        self.staff = get_user_model().objects.create_user(
            username="verifier", password=None, is_staff=True
        )
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.zone = PricingZone.objects.create(
            name="Test coverage",
            enabled=True,
            south="-18",
            north="-17",
            west="30",
            east="32",
        )
        self.policy = PricingConfiguration.objects.create(
            zone=self.zone,
            category="Standard",
            enabled=True,
            base_fare_usd="1.00",
            per_km_usd="0.50",
            per_minute_usd="0.10",
            minimum_offer_usd="2.00",
            maximum_offer_usd="50.00",
            rounding_usd="0.25",
        )
        self.payload = {
            "pickup": {"name": "Test pickup", "latitude": -17.82, "longitude": 31.05},
            "destination": {
                "name": "Test destination",
                "latitude": -17.80,
                "longitude": 31.03,
            },
            "category": "Standard",
            "currency": "USD",
        }
        self.route = patch("rides.services.booking.driving_route", return_value=ROAD)
        self.route.start()
        self.addCleanup(self.route.stop)

    def quote(self, **overrides):
        response = self.client.post(
            "/mobile/v1/routes/quote/", {**self.payload, **overrides}, format="json"
        )
        self.assertEqual(response.status_code, 201, response.data)
        return response.data

    def booking(self, quote, **overrides):
        return {
            **self.payload,
            "currency": quote["currency"],
            "quote_id": quote["id"],
            "idempotency_key": str(uuid.uuid4()),
            "fare_cents": quote["suggested_fare_cents"],
            "payment_method_id": "cash-usd",
            **overrides,
        }

    def rate(self, **kwargs):
        now = timezone.now()
        # A test fixture only; no production exchange rate is seeded.
        return ExchangeRate.objects.create(
            usd_to_zwg=Decimal("20"),
            source_url="https://www.rbz.co.zw/test-rate",
            observed_at=now - timedelta(minutes=10),
            valid_until=now + timedelta(hours=1),
            verified_at=now,
            verified_by=self.staff,
            **kwargs,
        )

    def test_configurable_formula_and_rounding_returns_road_data(self):
        q = self.quote()
        # (1 + 5.8*.5 + 12*.1) = 5.10, rounded to nearest .25 = 5.00.
        self.assertEqual(q["suggested_fare_cents"], 500)
        self.assertEqual(q["distance_metres"], 5800)
        self.assertEqual(q["geometry"], ROAD["geometry"])
        self.assertEqual(q["pricing_configuration"]["id"], str(self.policy.pk))

    def test_fee_and_time_adjustment(self):
        self.policy.booking_fee_usd = "0.50"
        self.policy.save()
        now = timezone.now()
        hour = now.astimezone(__import__("zoneinfo").ZoneInfo("Africa/Harare")).hour
        TimeAdjustment.objects.create(
            pricing=self.policy,
            start_hour=hour,
            end_hour=(hour + 1) % 24,
            multiplier="2.000",
        )
        self.assertEqual(self.quote()["suggested_fare_cents"], 1075)

    def test_edit_offer_creates_unpaid_cash_record_without_agreement(self):
        q = self.quote()
        response = self.client.post(
            "/mobile/v1/rides/", self.booking(q, fare_cents=400), format="json"
        )
        self.assertEqual(response.status_code, 201, response.data)
        ride = Ride.objects.get()
        self.assertEqual(ride.offered_fare, Decimal("4"))
        self.assertIsNone(ride.agreed_fare)
        self.assertEqual(ride.quote.suggested_cents, 500)
        self.assertEqual(ride.payment.status, "unverified")
        self.assertEqual(ride.payment.amount, Decimal("4"))
        self.assertEqual(ride.payment.currency, "USD")

    def test_idempotent_retry_returns_same_ride(self):
        data = self.booking(self.quote())
        first = self.client.post("/mobile/v1/rides/", data, format="json")
        second = self.client.post("/mobile/v1/rides/", data, format="json")
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.data["id"], second.data["id"])
        self.assertEqual(Ride.objects.count(), 1)
        changed = self.client.post(
            "/mobile/v1/rides/", {**data, "fare_cents": 600}, format="json"
        )
        self.assertEqual(changed.status_code, 400)

    def test_second_active_request_rejected_with_different_key(self):
        self.client.post("/mobile/v1/rides/", self.booking(self.quote()), format="json")
        second = self.client.post(
            "/mobile/v1/rides/", self.booking(self.quote()), format="json"
        )
        self.assertEqual(second.status_code, 400)
        self.assertEqual(Ride.objects.count(), 1)

    def test_invalid_offers_and_incompatible_methods(self):
        q = self.quote()
        for amount in [0, -1, 199, 5001, "NaN", 5.5]:
            response = self.client.post(
                "/mobile/v1/rides/", self.booking(q, fare_cents=amount), format="json"
            )
            self.assertEqual(response.status_code, 400, (amount, response.data))
        bad = self.client.post(
            "/mobile/v1/rides/",
            self.booking(q, payment_method_id="cash-zwg"),
            format="json",
        )
        self.assertEqual(bad.status_code, 400)
        self.assertFalse(Payment.objects.exists())




    def test_route_currency_category_tampering_or_expiry_rejected(self):
        q = self.quote()
        for changes in [
            {"destination": {**self.payload["destination"], "latitude": -17.81}},
            {"currency": "ZWG"},
            {"category": "XL"},
        ]:
            response = self.client.post(
                "/mobile/v1/rides/", self.booking(q, **changes), format="json"
            )
            self.assertEqual(response.status_code, 400)
        FareQuote.objects.filter(pk=q["id"]).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )
        self.assertEqual(
            self.client.post(
                "/mobile/v1/rides/", self.booking(q), format="json"
            ).status_code,
            409,
        )

    def test_changed_pricing_requires_new_quote(self):
        q = self.quote()
        self.policy.per_km_usd = "0.8"
        self.policy.save()
        self.assertEqual(
            self.client.post(
                "/mobile/v1/rides/", self.booking(q), format="json"
            ).status_code,
            409,
        )

    def test_no_route_or_no_coverage_does_not_create_quote(self):
        from rides.services.routing import RouteUnavailable

        with patch(
            "rides.services.booking.driving_route", side_effect=RouteUnavailable()
        ):
            response = self.client.post(
                "/mobile/v1/routes/quote/", self.payload, format="json"
            )
            self.assertEqual(response.status_code, 503)
        self.zone.enabled = False
        self.zone.save()
        self.assertEqual(
            self.client.post(
                "/mobile/v1/routes/quote/", self.payload, format="json"
            ).status_code,
            400,
        )
        self.assertFalse(FareQuote.objects.exists())

    def test_authentication_ownership_and_cancellation(self):
        q = self.quote()
        first = self.client.post("/mobile/v1/rides/", self.booking(q), format="json")
        pk = first.data["id"]
        other = get_user_model().objects.create_user(username="other", password=None)
        self.client.force_authenticate(other)
        self.assertEqual(self.client.get(f"/mobile/v1/rides/{pk}/").status_code, 404)
        self.assertEqual(
            self.client.post(
                "/mobile/v1/rides/", self.booking(q), format="json"
            ).status_code,
            400,
        )
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get("/mobile/v1/currencies/").status_code, 401)
        self.client.force_authenticate(self.user)
        self.assertEqual(
            self.client.post(
                f"/mobile/v1/rides/{pk}/status/", {"status": "completed"}, format="json"
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.post(
                f"/mobile/v1/rides/{pk}/status/", {"status": "cancelled"}, format="json"
            ).status_code,
            200,
        )
        self.assertEqual(Payment.objects.get().status, "cancelled")



    def test_exact_direct_payment_methods_and_usd_only(self):
        methods = self.client.get('/mobile/v1/payments/methods/').data['items']
        self.assertEqual({m['id'] for m in methods}, {'cash-usd', 'ecocash', 'onemoney'})
        self.assertTrue(all(m['enabled'] for m in methods))
        self.assertEqual(self.client.get('/mobile/v1/currencies/').data['items'], [{'code': 'USD', 'name': 'United States Dollar', 'symbol': 'US$'}])
        for currency in ['ZWG', 'ZIG', 'EUR']:
            response = self.client.post('/mobile/v1/routes/quote/', {**self.payload, 'currency': currency}, format='json')
            self.assertEqual(response.status_code, 400)

    def test_all_preferences_are_unverified_direct_payments(self):
        for code in ['cash-usd', 'ecocash', 'onemoney']:
            response = self.client.post('/mobile/v1/rides/', self.booking(self.quote(), payment_method_id=code, passenger_note='Please call at the gate.'), format='json')
            self.assertEqual(response.status_code, 201, response.data)
            ride = Ride.objects.get(pk=response.data['id'])
            self.assertEqual(ride.payment.status, 'unverified')
            self.assertEqual(ride.payment.method_id, code)
            self.assertEqual(ride.passenger_note, 'Please call at the gate.')
            self.client.post(f'/mobile/v1/rides/{ride.pk}/cancel/', {}, format='json')

    def test_unsupported_payment_and_inconsistent_preference_rejected(self):
        q = self.quote()
        for data in [self.booking(q, payment_method_id='innbucks'), self.booking(q, payment_preference='ecocash')]:
            self.assertEqual(self.client.post('/mobile/v1/rides/', data, format='json').status_code, 400)
