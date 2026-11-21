import hashlib
import json
import logging
import math
import time
from http.client import HTTPException
from urllib.parse import urlencode, urlparse
from urllib.request import Request, HTTPRedirectHandler, build_opener
from django.conf import settings
from django.core.cache import cache
from rest_framework.exceptions import APIException, Throttled


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
    try:
        parsed = urlparse(url)
        if parsed.scheme != "https" or not parsed.hostname:
            raise ValueError("A secure provider URL is required")
        request = Request(
            url,
            headers={
                "User-Agent": "Trivia/1.0 (MOrdec Solutions)",
                "Accept": "application/json",
            },
        )
        with build_opener(NoRedirects()).open(request, timeout=5) as response:
            payload = response.read(2_000_001)
        if len(payload) > 2_000_000:
            raise ValueError("Provider response is too large")
        return json.loads(payload)
    except (OSError, HTTPException, ValueError) as exc:
        logging.getLogger(__name__).warning(
            "Map provider request failed (%s, HTTP %s)",
            type(exc).__name__, getattr(exc, "code", "-"),
        )
        raise RouteUnavailable() from None


def geoapify_json(path, **params):
    now = int(time.time())
    # Shared Redis counters count cache misses across all API workers.
    for window, limit in ((1, 5), (86400, settings.TRIVIA_GEOAPIFY_DAILY_REQUEST_LIMIT)):
        bucket = now // window
        key = f"trivia:geoapify:quota:{window}:{bucket}"
        cache.add(key, 0, timeout=window + 1)
        if cache.incr(key) > limit:
            raise Throttled(
                wait=window - now % window,
                detail="Location and route requests are temporarily limited.",
            )
    return provider_json(
        f"https://api.geoapify.com/v1/{path}?"
        + urlencode({**params, "apiKey": settings.TRIVIA_GEOAPIFY_API_KEY})
    )


def cache_key(operation, *parts):
    digest = hashlib.sha256(repr(parts).encode()).hexdigest()
    return f"trivia:maps:v1:{operation}:{digest}"


def driving_route(pickup, destination, *, stops=()):
    provider = settings.TRIVIA_ROUTING_URL or "geoapify"
    coordinates = tuple(
        point[field] for point in (pickup, *stops, destination)
        for field in ("latitude", "longitude")
    )
    key = cache_key("route", provider, settings.TRIVIA_MAX_SNAP_METRES, coordinates)
    result = cache.get(key)
    if result is None:
        result = fetch_route(pickup, destination, stops=stops) if stops else fetch_route(pickup, destination)
        cache.set(key, result, 300)
    return result


def fetch_route(pickup, destination, *, stops=()):
    locations = (pickup, *stops, destination)
    base = settings.TRIVIA_ROUTING_URL.rstrip("/")
    if not base and settings.TRIVIA_GEOAPIFY_API_KEY:
        return geoapify_route(pickup, destination, stops=stops) if stops else geoapify_route(pickup, destination)
    if not base:
        raise RouteUnavailable(
            "Driving routes are not configured. Please retry once the service is available."
        )
    coordinates = ";".join(f"{p['longitude']},{p['latitude']}" for p in locations)
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
        # Refuse routes snapped unreasonably far from the requested locations.
        waypoints = data["waypoints"]
        if len(waypoints) != len(locations) or any(
            (
                not math.isfinite(float(w["distance"]))
                or not 0 <= float(w["distance"]) <= settings.TRIVIA_MAX_SNAP_METRES
            )
            for w in waypoints
        ):
            raise ValueError("Location too far from a drivable road")
        return validated_route(points, metres, seconds, "OSRM")
    except (KeyError, IndexError, TypeError, ValueError, OverflowError) as exc:
        raise RouteUnavailable() from exc


def validated_route(points, metres, seconds, provider):
    if (
        not math.isfinite(metres)
        or not math.isfinite(seconds)
        or metres <= 0
        or seconds <= 0
        or not isinstance(points, list)
        or len(points) < 2
        or len(points) > 30000
    ):
        raise ValueError("Invalid road result")
    for point in points:
        if (
            not isinstance(point, list)
            or len(point) != 2
            or not all(
                type(v) in (int, float) and math.isfinite(v) for v in point
            )
            or not -180 <= point[0] <= 180
            or not -90 <= point[1] <= 90
        ):
            raise ValueError("Invalid coordinate")
    return {
        "distance_metres": math.ceil(metres),
        "duration_seconds": math.ceil(seconds),
        "geometry": points,
        "provider": provider,
    }


def snap_distance(requested, coordinate):
    lon, lat = map(math.radians, coordinate)
    target_lat, target_lon = map(
        math.radians, (requested["latitude"], requested["longitude"])
    )
    a = (
        math.sin((lat - target_lat) / 2) ** 2
        + math.cos(lat) * math.cos(target_lat) * math.sin((lon - target_lon) / 2) ** 2
    )
    return 12_742_000 * math.asin(math.sqrt(min(1, a)))


def geoapify_route(pickup, destination, *, stops=()):
    locations = (pickup, *stops, destination)
    waypoints = "|".join(
        f"{p['latitude']},{p['longitude']}" for p in locations
    )
    data = geoapify_json(
        "routing", waypoints=waypoints, mode="drive", units="metric", format="geojson"
    )
    try:
        feature = data["features"][0]
        geometry, properties = feature["geometry"], feature["properties"]
        line = geometry["coordinates"]
        if geometry["type"] == "MultiLineString":
            legs = line
        elif geometry["type"] == "LineString" and not stops:
            legs = [line]
        else:
            raise ValueError("Invalid road geometry")
        if not isinstance(legs, list) or len(legs) != len(locations) - 1:
            raise ValueError("Expected a driving leg between each pair of locations")
        points = []
        for index, leg in enumerate(legs):
            if not isinstance(leg, list) or len(leg) < 2:
                raise ValueError("Invalid driving leg")
            if points and points[-1] != leg[0]:
                raise ValueError("Driving legs are disjoint")
            for requested, point in ((locations[index], leg[0]), (locations[index + 1], leg[-1])):
                if snap_distance(requested, point) > settings.TRIVIA_MAX_SNAP_METRES:
                    raise ValueError("Location too far from a drivable road")
            points.extend(leg if not points else leg[1:])
        return validated_route(
            points, float(properties["distance"]), float(properties["time"]), "Geoapify"
        )
    except (KeyError, IndexError, TypeError, ValueError, OverflowError) as exc:
        raise RouteUnavailable() from exc


class GeocodingUnavailable(APIException):
    status_code = 503
    default_detail = "Location search is unavailable. Retry or choose a map pin."
    default_code = "geocoding_unavailable"


def normalized_place(place, geoapify):
    lat, lon = float(place["lat"]), float(place["lon"])
    if not -90 <= lat <= 90 or not -180 <= lon <= 180:
        raise ValueError("Invalid coordinate")
    address = place["formatted"] if geoapify else place["display_name"]
    name = address
    if geoapify:
        name = place.get("name") or place.get("address_line1") or address
    if not all(isinstance(value, str) and value.strip() for value in (name, address)):
        raise ValueError("Invalid place name or address")
    return {
        **({"provider": "Geoapify"} if geoapify else {}),
        "name": name.strip()[:200],
        "formatted_address": address.strip()[:500],
        "latitude": lat,
        "longitude": lon,
    }


def geocode(operation, params, base):
    try:
        if base:
            return provider_json(f"{base}/{operation}?" + urlencode({
                **params, "format": "jsonv2",
            }))
        if settings.TRIVIA_GEOAPIFY_API_KEY:
            if operation == "search":
                params = {"text": params["q"], "limit": params["limit"],
                          "filter": "countrycode:zw", "bias": "countrycode:zw"}
                operation = "autocomplete"
            results = geoapify_json(f"geocode/{operation}", **params, format="json")["results"]
            if isinstance(results, list):
                return results
    except (RouteUnavailable, KeyError, TypeError) as exc:
        raise GeocodingUnavailable() from exc
    raise GeocodingUnavailable()


def search_places(query):
    query = " ".join(query.split())
    if not query:
        return []
    base = settings.TRIVIA_GEOCODING_URL.rstrip("/")
    key = cache_key("search", base, query.casefold())
    result = cache.get(key)
    if result is not None:
        return result
    data = geocode("search", {"q": query, "limit": 8, "countrycodes": "zw"}, base)
    try:
        if not isinstance(data, list):
            raise ValueError("Expected a list of places")
        result = [normalized_place(place, not base) for place in data[:8]]
    except (KeyError, TypeError, ValueError, OverflowError) as exc:
        raise GeocodingUnavailable() from exc
    cache.set(key, result, 86400 if result else 300)
    return result


def reverse_geocode(point):
    lat, lon = float(point["latitude"]), float(point["longitude"])
    base = settings.TRIVIA_GEOCODING_URL.rstrip("/")
    key = cache_key("reverse", base, lat, lon)
    result = cache.get(key)
    if result is not None:
        return result
    try:
        data = geocode("reverse", {"lat": lat, "lon": lon}, base)
        result = normalized_place(data if base else data[0], not base)
    except (GeocodingUnavailable, KeyError, IndexError, TypeError, ValueError, OverflowError) as exc:
        raise GeocodingUnavailable("No address could be resolved for this location.") from exc
    cache.set(key, result, 86400)
    return result
