"""City-to-city booking rules shared by quoting and matching."""

from math import asin, cos, radians, sin, sqrt

from rest_framework.exceptions import ValidationError


# Centres used to validate that a selected point is near its stated city.
CITIES = {
    "Harare": (-17.8292, 31.0522),
    "Bulawayo": (-20.1325, 28.6265),
    "Gweru": (-19.4510, 29.8167),
    "Mutare": (-18.9707, 32.6709),
    "Masvingo": (-20.0637, 30.8277),
    "Kwekwe": (-18.9281, 29.8149),
    "Chinhoyi": (-17.3667, 30.2000),
    "Kadoma": (-18.3333, 29.9167),
    "Marondera": (-18.1853, 31.5519),
    "Bindura": (-17.3019, 31.3306),
    "Victoria Falls": (-17.9318, 25.8250),
}
CATEGORY = "Intercity"
CITY_RADIUS_KM = 20


def validate_cities(pickup, destination):
    cities = []
    for field, point in (("pickup", pickup), ("destination", destination)):
        city = point.get("city")
        if city not in CITIES:
            raise ValidationError({field: "Select a supported city."})
        lat, lng = CITIES[city]
        a = sin(radians(point["latitude"] - lat) / 2) ** 2
        a += cos(radians(lat)) * cos(radians(point["latitude"])) * sin(
            radians(point["longitude"] - lng) / 2
        ) ** 2
        if 6371 * 2 * asin(min(1, sqrt(a))) > CITY_RADIUS_KM:
            raise ValidationError({field: f"Choose a point within {CITY_RADIUS_KM} km of {city}."})
        cities.append(city)
    if cities[0] == cities[1]:
        raise ValidationError({"destination": "Choose a different arrival city."})
