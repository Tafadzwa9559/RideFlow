from datetime import timedelta
from uuid import uuid4
from unittest.mock import patch

from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from notifications.models import Notification
from rides.models import Ride
from rides.services.scheduling import MATCHING_LEAD, open_matching
from rides.tests.helpers import ROAD, RideFixtures


class PlatformServiceTests(RideFixtures, TestCase):
    def setUp(self):
        cache.clear()
        self.setup_ride()
        self.ride.status = "cancelled"
        self.ride.save(update_fields=["status"])
        route = patch("rides.services.booking.driving_route", return_value=ROAD)
        self.route = route.start()
        self.addCleanup(route.stop)
        self.client = APIClient()
        self.client.force_authenticate(self.passenger)

    def request_data(self, category="Standard", **route_fields):
        payload = {
            "pickup": self.pickup, "destination": self.destination,
            "category": category, **route_fields,
        }
        quote = self.client.post("/api/v1/fares/estimate/", payload, format="json")
        self.assertEqual(quote.status_code, 201, quote.data)
        return {
            **payload, "quote_id": quote.data["id"], "idempotency_key": str(uuid4()),
            "fare_cents": quote.data["suggested_fare_cents"], "payment_method_id": "cash-usd",
        }

    def post(self, path, data):
        return self.client.post(f"/api/v1/{path}/", data, format="json")

    def test_schedule_is_editable_only_before_matching_and_worker_is_idempotent(self):
        request = self.request_data()
        departure = timezone.now() + timedelta(hours=3)
        self.assertEqual(self.post("rides", {**request, "departure_at": timezone.now().isoformat()}).status_code, 400)
        ride = self.post("rides", {**request, "departure_at": departure.isoformat()})
        self.assertEqual(ride.status_code, 201, ride.data)
        self.assertEqual(ride.data["status"], "scheduled")
        pk = ride.data["id"]
        edit = self.client.patch(f"/api/v1/rides/{pk}/schedule/", {
            "departure_at": (departure + timedelta(hours=1)).isoformat(),
        }, format="json")
        self.assertEqual(edit.status_code, 200, edit.data)
        open_matching(pk, departure - MATCHING_LEAD)
        self.assertEqual(Ride.objects.get(pk=pk).status, "scheduled")
        opening = departure + timedelta(hours=1) - MATCHING_LEAD
        open_matching(pk, opening)
        open_matching(pk, opening)
        self.assertEqual(Ride.objects.get(pk=pk).status, "searching")
        self.assertEqual(Notification.objects.filter(envelope__type="ride.matching_open", envelope__resource_id=pk).count(), 1)

    def test_stop_order_is_bound_to_quote(self):
        first = {"name": "First stop", "latitude": -17.81, "longitude": 31.04}
        second = {"name": "Second stop", "latitude": -17.815, "longitude": 31.045}
        request = self.request_data(stops=[first, second])
        self.route.assert_called_with(self.pickup, self.destination, stops=[first, second])
        bad = self.post("rides", {**request, "stops": [second, first]})
        self.assertEqual(bad.status_code, 400, bad.data)
        good = self.post("rides", request)
        self.assertEqual(good.status_code, 201, good.data)
        self.assertEqual(good.data["stops"], [first, second])

    def test_courier_handover_privacy_and_proof(self):
        self.pricing.category = "Courier"
        self.pricing.save(update_fields=["category"])
        request = self.request_data(category="Courier")
        parcel = {
            "sender_name": "Sender", "sender_phone": "+263771234567",
            "recipient_name": "Recipient", "recipient_phone": "+263772334567",
            "description": "Documents", "size": "small", "weight_kg": 1,
            "permitted_goods": True,
        }
        denied = self.post("rides", {**request, "parcel": {**parcel, "permitted_goods": False}})
        self.assertEqual(denied.status_code, 400, denied.data)
        ride = self.post("rides", {**request, "parcel": parcel})
        self.assertEqual(ride.status_code, 201, ride.data)
        self.assertNotIn("parcel", ride.data)
        pk = ride.data["id"]
        path = f"rides/{pk}"
        self.client.force_authenticate(self.driver_user)
        self.assertEqual(self.client.get(f"/api/v1/{path}/parcel/").status_code, 404)
        self.assertEqual(self.post(f"{path}/offers", {"decision": "accept"}).status_code, 403)
        self.post("drivers/me/service-preferences", {"accepts_courier": True})
        offer = self.post(f"{path}/offers", {"decision": "accept"})
        self.assertEqual(offer.status_code, 201, offer.data)
        self.client.force_authenticate(self.passenger)
        accepted = self.post(f"{path}/select-offer", {"offer_id": offer.data["id"]})
        self.assertEqual(accepted.status_code, 200, accepted.data)
        self.client.force_authenticate(self.driver_user)
        for step in ["arriving", "arrived", "start"]:
            changed = self.post(f"{path}/{step}", {})
            self.assertEqual(changed.status_code, 200, changed.data)
        details = self.client.get(f"/api/v1/{path}/parcel/")
        self.assertEqual(details.status_code, 200, details.data)
        self.assertNotIn("confirmation_code", details.data)
        self.assertEqual(self.post(f"{path}/complete", {}).status_code, 400)
        self.client.force_authenticate(self.passenger)
        code = self.client.get(f"/api/v1/{path}/parcel/").data["confirmation_code"]
        self.assertEqual(self.post(f"{path}/parcel/confirm", {"code": code}).status_code, 403)
        self.client.force_authenticate(self.driver_user)
        wrong = "00000000" if code != "00000000" else "00000001"
        self.assertEqual(self.post(f"{path}/parcel/confirm", {"code": wrong}).status_code, 400)
        delivered = self.post(f"{path}/parcel/confirm", {"code": code})
        self.assertEqual(delivered.status_code, 200, delivered.data)
        self.assertEqual(delivered.data["status"], "completed")
        self.assertEqual(self.client.get(f"/api/v1/{path}/parcel/").status_code, 404)
