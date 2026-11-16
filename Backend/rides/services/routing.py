import json
import math
from urllib.error import URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, HTTPRedirectHandler, build_opener
from django.conf import settings
from rest_framework.exceptions import APIException


class RouteUnavailable(APIException):
    status_code = 503
    default_detail = (
        "The driving route could not be calculated. Check your locations and retry."
    )
    default_code = "route_unavailable"


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def provider_json(url):
    # Provider hosts are operator-configured; passenger input never supplies URLs.
    if urlparse(url).scheme != "https":
        raise RouteUnavailable(
            "A secure routing/geocoding provider must be configured."
        )
    try:
        request = Request(
            url,
            headers={
                "User-Agent": "Trivia/1.0 (MOrdec Solutions)",
                "Accept": "application/json",
            },
        )
        with build_opener(NoRedirects()).open(request, timeout=10) as response:
            payload = response.read(2_000_001)
        if len(payload) > 2_000_000:
            raise ValueError("Provider response is too large")
        return json.loads(payload)
    except (URLError, TimeoutError, OSError, ValueError) as exc:
        raise RouteUnavailable() from exc


def driving_route(pickup, destination):
    base = settings.TRIVIA_ROUTING_URL.rstrip("/")
    if not base:
        raise RouteUnavailable(
            "Driving routes are not configured. Please retry once the service is available."
        )
    coordinates = f"{pickup['longitude']},{pickup['latitude']};{destination['longitude']},{destination['latitude']}"
    data = provider_json(
        f"{base}/route/v1/driving/{coordinates}?"
        + urlencode(
            {
                "overview": "full",
                "geometries": "geojson",
                "alternatives": "false",
                "steps": "false",
            }
        )
    )
    try:
        if not isinstance(data, dict) or data.get("code") != "Ok":
            raise ValueError("No route")
        route = data["routes"][0]
        if route["geometry"]["type"] != "LineString":
            raise ValueError("Invalid road geometry")
        points = route["geometry"]["coordinates"]
        metres, seconds = float(route["distance"]), float(route["duration"])
        if (
            not math.isfinite(metres)
            or not math.isfinite(seconds)
            or metres <= 0
            or seconds <= 0
            or len(points) < 2
            or len(points) > 30000
        ):
            raise ValueError("Invalid road result")
        for point in points:
            if (
                len(point) != 2
                or not all(
                    isinstance(v, (int, float)) and math.isfinite(v) for v in point
                )
                or not -180 <= point[0] <= 180
                or not -90 <= point[1] <= 90
            ):
                raise ValueError("Invalid coordinate")
        # Refuse routes snapped unreasonably far from the requested locations.
        waypoints = data["waypoints"]
        if len(waypoints) != 2 or any(
            (
                not math.isfinite(float(w["distance"]))
                or not 0 <= float(w["distance"]) <= settings.TRIVIA_MAX_SNAP_METRES
            )
            for w in waypoints
        ):
            raise ValueError("Location too far from a drivable road")
        return {
            "distance_metres": math.ceil(metres),
            "duration_seconds": math.ceil(seconds),
            "geometry": points,
            "provider": "OSRM",
        }
    except (KeyError, IndexError, TypeError, ValueError, OverflowError) as exc:
        raise RouteUnavailable() from exc


def search_places(query):
    base = settings.TRIVIA_GEOCODING_URL.rstrip("/")
    if not base:
        raise RouteUnavailable(
            "Address search is not configured. Select a map pin or use GPS instead."
        )
    # Nominatim-compatible configured provider. No public endpoint is assumed.
    data = provider_json(
        f"{base}/search?"
        + urlencode({"q": query, "format": "jsonv2", "limit": 8, "countrycodes": "zw"})
    )
    try:
        result = []
        for p in data[:8]:
            lat, lng = float(p["lat"]), float(p["lon"])
            if (
                not math.isfinite(lat)
                or not math.isfinite(lng)
                or not -90 <= lat <= 90
                or not -180 <= lng <= 180
            ):
                raise ValueError("Invalid place")
            result.append(
                {"name": p["display_name"][:200], "latitude": lat, "longitude": lng}
            )
        return result
    except (TypeError, KeyError, ValueError, OverflowError) as exc:
        raise RouteUnavailable(
            "Address search is unavailable. Retry or choose a map pin."
        ) from exc


def reverse_geocode(point):
    base = settings.TRIVIA_GEOCODING_URL.rstrip('/')
    if not base:
        raise RouteUnavailable('Reverse geocoding is not configured.')
    data = provider_json(base + '/reverse?' + urlencode({'lat': point['latitude'], 'lon': point['longitude'], 'format': 'jsonv2'}))
    try:
        name = data['display_name']
        lat, lon = float(data['lat']), float(data['lon'])
        if not isinstance(name, str) or not name or not math.isfinite(lat) or not math.isfinite(lon) or not -90 <= lat <= 90 or not -180 <= lon <= 180:
            raise ValueError()
        return {'name': name[:200], 'latitude': lat, 'longitude': lon}
    except (KeyError, TypeError, ValueError):
        raise RouteUnavailable('Reverse geocoding returned an invalid place.')
