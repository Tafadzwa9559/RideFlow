from unittest.mock import patch
from django.test import SimpleTestCase, override_settings
from rides.services.routing import driving_route, RouteUnavailable


@override_settings(
    TRIVIA_ROUTING_URL="https://routing.example", TRIVIA_MAX_SNAP_METRES=250
)
class RoutingTests(SimpleTestCase):
    pickup = {"latitude": -17.82, "longitude": 31.05}
    destination = {"latitude": -17.80, "longitude": 31.03}

    def test_osrm_road_route_not_straight_line_distance(self):
        fixture = {
            "code": "Ok",
            "routes": [
                {
                    "distance": 5800.2,
                    "duration": 720.2,
                    "geometry": {
                        "type": "LineString",
                        "coordinates": [[31.05, -17.82], [31.03, -17.80]],
                    },
                }
            ],
            "waypoints": [{"distance": 1}, {"distance": 2}],
        }
        with patch(
            "rides.services.routing.provider_json", return_value=fixture
        ) as provider:
            route = driving_route(self.pickup, self.destination)
        self.assertEqual(route["distance_metres"], 5801)
        self.assertEqual(route["duration_seconds"], 721)
        self.assertIn(
            "/route/v1/driving/31.05,-17.82;31.03,-17.8", provider.call_args.args[0]
        )
        self.assertIn("geometries=geojson", provider.call_args.args[0])

    def test_no_route_and_invalid_provider_results_fail(self):
        for payload in [
            {"code": "NoRoute", "routes": []},
            {"code": "Ok", "routes": [{"distance": float("nan"), "duration": 12}]},
        ]:
            with patch("rides.services.routing.provider_json", return_value=payload):
                with self.assertRaises(RouteUnavailable):
                    driving_route(self.pickup, self.destination)
