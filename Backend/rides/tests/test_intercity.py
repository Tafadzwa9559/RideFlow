from uuid import uuid4
from unittest.mock import patch

from django.test import TestCase
from rest_framework.test import APIClient

from rides.models import Ride
from rides.tests.helpers import RideFixtures


class IntercityTests(RideFixtures, TestCase):
    def setUp(self):
        self.setup_ride()
        self.ride.status = "cancelled"
        self.ride.save(update_fields=["status"])
        self.zone.south = -21
        self.zone.west = 28
        self.zone.save()
        self.pricing.category = "Intercity"
        self.pricing.per_km_usd = "0.10"
        self.pricing.maximum_offer_usd = 100
        self.pricing.save()
        self.payload = {
            "category": "Intercity",
            "pickup": {**self.pickup, "city": "Harare"},
            "destination": {
                "name": "Bulawayo meeting point",
                "city": "Bulawayo",
                "latitude": -20.13,
                "longitude": 28.63,
            },
        }
        route = {
            "distance_metres": 439000,
            "duration_seconds": 19000,
            "geometry": [[31.05, -17.82], [28.63, -20.13]],
            "provider": "test-only",
        }
        route_patch = patch("rides.services.booking.driving_route", return_value=route)
        route_patch.start()
        self.addCleanup(route_patch.stop)
        self.client = APIClient()
        self.client.force_authenticate(self.passenger)

    def quote(self, payload):
        return self.client.post("/api/v1/fares/estimate/", payload, format="json")

    def book(self, passenger_count):
        response = self.quote(self.payload)
        self.assertEqual(response.status_code, 201, response.data)
        result = self.client.post("/api/v1/rides/", {
            **self.payload,
            "quote_id": response.data["id"],
            "idempotency_key": str(uuid4()),
            "fare_cents": response.data["suggested_fare_cents"],
            "payment_method_id": "cash-usd",
            "passenger_count": passenger_count,
            "luggage": "large",
        }, format="json")
        self.assertEqual(result.status_code, 201, result.data)
        return result.data

    def test_same_city_and_point_outside_selected_city_are_rejected(self):
        same_city = {**self.pickup, "city": "Harare", "name": "Another point"}
        self.assertEqual(self.quote({**self.payload, "destination": same_city}).status_code, 400)
        wrong_city = {**self.payload["destination"], "city": "Mutare"}
        self.assertEqual(self.quote({**self.payload, "destination": wrong_city}).status_code, 400)

    def test_driver_opt_in_and_capacity_enforced_through_offer_acceptance(self):
        ride = self.book(passenger_count=4)
        self.assertEqual(ride["pickup"]["city"], "Harare")
        self.assertEqual(ride["passenger_count"], 4)
        self.assertEqual(ride["luggage"], "large")
        offers = f"/api/v1/rides/{ride['id']}/offers/"
        preference = "/api/v1/drivers/me/service-preferences/"
        self.assertEqual(self.client.post(preference, {"accepts_intercity": True}).status_code, 403)
        self.client.force_authenticate(self.driver_user)
        self.assertEqual(self.client.post(offers, {"decision": "accept"}).status_code, 403)
        response = self.client.post(preference, {"accepts_intercity": True})
        self.assertEqual(response.status_code, 200, response.data)
        vehicle = self.driver.active_vehicle
        vehicle.capacity = 3
        vehicle.save(update_fields=["capacity"])
        self.assertEqual(self.client.post(offers, {"decision": "accept"}).status_code, 403)
        vehicle.capacity = 4
        vehicle.save(update_fields=["capacity"])
        requests = self.client.get("/api/v1/drivers/me/requests/")
        self.assertEqual(requests.status_code, 200, requests.data)
        self.assertIn(ride["id"], [request["id"] for request in requests.data["results"]])
        offer = self.client.post(offers, {"decision": "accept"})
        self.assertEqual(offer.status_code, 201, offer.data)
        self.client.force_authenticate(self.passenger)
        result = self.client.post(f"/api/v1/rides/{ride['id']}/accept/", {"offer_id": offer.data["id"]})
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(Ride.objects.get(pk=ride["id"]).status, "assigned")
