from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIClient
from rides.services.routing import driving_route, RouteUnavailable


@override_settings(
    TRIVIA_ROUTING_URL="https://routing.example", TRIVIA_MAX_SNAP_METRES=250
)
class RoutingTests(SimpleTestCase):
    pickup = {"latitude": -17.82, "longitude": 31.05}
    destination = {"latitude": -17.80, "longitude": 31.03}

    def setUp(self):
        cache.clear()
        self.addCleanup(cache.clear)

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


@override_settings(
    TRIVIA_GEOCODING_URL="", TRIVIA_ROUTING_URL="",
    TRIVIA_GEOAPIFY_API_KEY="test-key", TRIVIA_MAX_SNAP_METRES=250,
)
class GeoapifyTests(SimpleTestCase):
    place = {
        "name": "Avondale", "formatted": "Avondale, Harare, Zimbabwe",
        "lat": -17.80, "lon": 31.03,
    }
    search_url = "/api/v1/locations/search/"

    def setUp(self):
        cache.clear()
        self.addCleanup(cache.clear)
        self.client = APIClient()
        self.client.force_authenticate(get_user_model()(username="map-test"))

    def test_search_aliases_share_cached_zimbabwe_results(self):
        from urllib.parse import parse_qs, urlparse

        with patch("rides.services.routing.provider_json", return_value={"results": [self.place]}) as provider:
            canonical = self.client.get(self.search_url, {"q": "Avondale"})
            legacy = self.client.get("/api/v1/places/", {"q": " avondale "})
        self.assertEqual(canonical.status_code, 200)
        self.assertEqual(canonical.json(), legacy.json())
        self.assertEqual(canonical.json()["results"], [{
            "name": "Avondale", "provider": "Geoapify", "formatted_address": "Avondale, Harare, Zimbabwe",
            "latitude": -17.80, "longitude": 31.03,
        }])
        provider.assert_called_once()
        url = urlparse(provider.call_args.args[0])
        self.assertEqual(url.path, "/v1/geocode/autocomplete")
        self.assertEqual(parse_qs(url.query)["filter"], ["countrycode:zw"])

    def test_blank_and_empty_results(self):
        with patch("rides.services.routing.provider_json", return_value={"results": []}) as provider:
            self.assertEqual(self.client.get(self.search_url, {"q": " "}).json(), {"results": []})
            provider.assert_not_called()
            for _ in range(2):
                self.assertEqual(self.client.get(self.search_url, {"q": "unknown"}).json(), {"results": []})
            provider.assert_called_once()

    def test_invalid_provider_responses(self):
        for result in (None, {"results": {}}, {"results": [{"lat": "NaN"}]}):
            with self.subTest(result=result), patch("rides.services.routing.provider_json", return_value=result):
                self.assertEqual(self.client.get(self.search_url, {"q": "Harare"}).status_code, 503)

    def test_timeout_invalid_json_and_http_error(self):
        from urllib.error import HTTPError

        with patch("rides.services.routing.build_opener") as build:
            opener = build.return_value
            for error in (TimeoutError(), HTTPError("https://example.test", 401, "", {}, None)):
                opener.open.side_effect = error
                self.assertEqual(self.client.get(self.search_url, {"q": "Harare"}).status_code, 503)
            opener.open.side_effect = None
            opener.open.return_value.__enter__.return_value.read.return_value = b"not JSON"
            self.assertEqual(self.client.get(self.search_url, {"q": "Harare"}).status_code, 503)
            self.assertEqual(opener.open.call_args.kwargs["timeout"], 5)

    def test_search_requires_authentication(self):
        anonymous = APIClient()
        for url in (self.search_url, "/api/v1/places/"):
            self.assertEqual(anonymous.get(url, {"q": "Harare"}).status_code, 401)

    @override_settings(TRIVIA_GEOAPIFY_DAILY_REQUEST_LIMIT=1)
    def test_daily_limit_counts_cache_misses_only(self):
        with patch("rides.services.routing.provider_json", return_value={"results": [self.place]}) as provider:
            self.assertEqual(self.client.get(self.search_url, {"q": "Avon"}).status_code, 200)
            self.assertEqual(self.client.get(self.search_url, {"q": "AVON"}).status_code, 200)
            self.assertEqual(self.client.get(self.search_url, {"q": "Harare"}).status_code, 429)
            provider.assert_called_once()

    def test_reverse_geocoding(self):
        with patch("rides.services.routing.provider_json", return_value={"results": [self.place]}) as provider:
            response = self.client.get("/api/v1/locations/reverse-geocode/", {
                "latitude": -17.8, "longitude": 31.03,
            })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["formatted_address"], self.place["formatted"])
        self.assertIn("/v1/geocode/reverse?", provider.call_args.args[0])

    def test_road_legs_must_connect_at_every_stop(self):
        points = [[31.05, -17.82], [31.045, -17.815], [31.03, -17.80]]
        stop = {"latitude": -17.815, "longitude": 31.045}
        feature = {
            "properties": {"distance": 5800.2, "time": 720.2},
            "geometry": {
                "type": "MultiLineString",
                "coordinates": [points[:2], points[1:]],
            },
        }
        with patch("rides.services.routing.geoapify_json", return_value={"features": [feature]}) as provider:
            route = driving_route(RoutingTests.pickup, RoutingTests.destination, stops=[stop])
            self.assertEqual(route["geometry"], points)
            self.assertEqual(provider.call_args.kwargs["waypoints"], "-17.82,31.05|-17.815,31.045|-17.8,31.03")
            cache.clear()
            feature["geometry"]["coordinates"][1] = [[31.0449, -17.815], points[-1]]
            with self.assertRaises(RouteUnavailable):
                driving_route(RoutingTests.pickup, RoutingTests.destination, stops=[stop])

    def test_route_preserves_road_geometry_and_uses_cache(self):
        points = [[31.05, -17.82], [31.045, -17.815], [31.03, -17.80]]
        fixture = {"features": [{
            "properties": {"distance": 5800.2, "time": 720.2},
            "geometry": {"type": "MultiLineString", "coordinates": [points]},
        }]}
        with patch("rides.services.routing.provider_json", return_value=fixture) as provider:
            for _ in range(2):
                route = driving_route(RoutingTests.pickup, RoutingTests.destination)
                self.assertEqual(route, {
                    "distance_metres": 5801, "duration_seconds": 721,
                    "geometry": points, "provider": "Geoapify",
                })
            provider.assert_called_once()
            self.assertIn("mode=drive", provider.call_args.args[0])
