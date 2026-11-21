from decimal import Decimal
from rest_framework import serializers
from rest_framework.exceptions import ErrorDetail
from payments.models import CURRENCIES
from rides.models import PricingConfiguration, Ride
from rides.services.intercity import CATEGORY, CITIES, validate_cities
from rides.services.courier import CATEGORY as COURIER


class PlaceSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=200)
    city = serializers.ChoiceField(choices=list(CITIES), required=False)
    latitude = serializers.FloatField(min_value=-90, max_value=90)
    longitude = serializers.FloatField(min_value=-180, max_value=180)

    def validate(self, data):
        import math

        for key in ["latitude", "longitude"]:
            if not math.isfinite(data[key]):
                raise serializers.ValidationError("Coordinates must be finite numbers.")
            data[key] = float(Decimal(str(data[key])).quantize(Decimal("0.000001")))
        return data


class GeocodedPlaceSerializer(PlaceSerializer):
    formatted_address = serializers.CharField(max_length=500)
    provider = serializers.CharField(required=False)


class QuoteRequestSerializer(serializers.Serializer):
    pickup = PlaceSerializer()
    destination = PlaceSerializer()
    stops = serializers.ListField(child=PlaceSerializer(), max_length=3, required=False)
    category = serializers.ChoiceField(choices=PricingConfiguration._meta.get_field("category").choices)
    currency = serializers.ChoiceField(choices=["USD"], default="USD")

    def validate(self, data):
        stops = data.get("stops", [])
        if stops and data["category"] == COURIER:
            raise serializers.ValidationError({"stops": "Courier requests support one delivery address."})
        if any("city" in stop for stop in stops):
            raise serializers.ValidationError({"stops": "Select specific stop locations."})
        points = [data["pickup"], *stops, data["destination"]]
        coordinates = {(p["latitude"], p["longitude"]) for p in points}
        if len(coordinates) != len(points):
            raise serializers.ValidationError("Pickup, stops and destination must all differ.")
        if data["category"] == CATEGORY:
            validate_cities(data["pickup"], data["destination"])
        elif any("city" in data[field] for field in ("pickup", "destination")):
            raise serializers.ValidationError("City selection applies to City-to-City rides.")
        return data


class ScheduleSerializer(serializers.Serializer):
    departure_at = serializers.DateTimeField(help_text="Pickup time as an ISO 8601 timestamp with offset.")


class ParcelSerializer(serializers.Serializer):
    sender_name = serializers.CharField(max_length=100)
    sender_phone = serializers.CharField(max_length=30)
    recipient_name = serializers.CharField(max_length=100)
    recipient_phone = serializers.CharField(max_length=30)
    description = serializers.CharField(max_length=250)
    instructions = serializers.CharField(max_length=250, required=False, allow_blank=True, default="")
    size = serializers.ChoiceField(choices=["small", "medium", "large"])
    weight_kg = serializers.FloatField(min_value=0.1, max_value=20)
    permitted_goods = serializers.BooleanField()

    def validate(self, data):
        from math import isfinite
        from accounts.services.authentication import normalize_phone

        if not data["permitted_goods"]:
            raise serializers.ValidationError({"permitted_goods": "Hazardous, prohibited and illegal goods are excluded."})
        if not isfinite(data["weight_kg"]):
            raise serializers.ValidationError({"weight_kg": "Enter a finite weight."})
        for field in ("sender_phone", "recipient_phone"):
            try:
                data[field] = normalize_phone(data[field])
            except serializers.ValidationError as error:
                raise serializers.ValidationError({field: "Enter a valid phone number."}) from error
        return data


class BookingRequestSerializer(QuoteRequestSerializer):
    parcel = ParcelSerializer(required=False)
    passenger_count = serializers.IntegerField(min_value=1, max_value=6, required=False)
    luggage = serializers.ChoiceField(choices=["none", "small", "large"], required=False)
    departure_at = serializers.DateTimeField(required=False, help_text="Pickup time as an ISO 8601 timestamp with offset.")
    quote_id = serializers.UUIDField()
    idempotency_key = serializers.UUIDField()
    fare_cents = serializers.IntegerField(min_value=1, max_value=999999999999)
    payment_method_id = serializers.SlugField()
    payment_preference = serializers.ChoiceField(
        choices=["ecocash", "onemoney", "cash"],
        required=False,
        default="cash",
    )
    passenger_note = serializers.CharField(max_length=250, required=False, allow_blank=True, default="")

    def validate(self, data):
        data = super().validate(data)
        if data["category"] == COURIER:
            if "parcel" not in data:
                raise serializers.ValidationError({"parcel": "Enter the parcel and handover details."})
            if "departure_at" in data:
                raise serializers.ValidationError({"departure_at": "Courier requests are for immediate pickup."})
        elif "parcel" in data:
            raise serializers.ValidationError({"parcel": "Parcel details apply to courier requests."})
        if data["category"] != CATEGORY and ("passenger_count" in data or "luggage" in data):
            raise serializers.ValidationError("Passenger count and luggage apply to City-to-City rides.")
        preference = {'cash-usd': 'cash', 'ecocash': 'ecocash', 'onemoney': 'onemoney'}.get(data['payment_method_id'])
        if preference is None:
            raise serializers.ValidationError({'payment_method_id': ErrorDetail('Choose cash-usd, ecocash or onemoney.', code='INVALID_PAYMENT_METHOD')})
        if 'payment_preference' in self.initial_data and data['payment_preference'] != preference:
            raise serializers.ValidationError({'payment_preference': 'Must match the selected payment method.'})
        data['payment_preference'] = preference
        return data


def quote_json(quote):
    return {
        "id": str(quote.pk),
        "geometry": quote.route_geometry,
        "distance_metres": quote.distance_metres,
        "distance_km": str(Decimal(quote.distance_metres) / 1000),
        "duration_seconds": quote.duration_seconds,
        "estimated_minutes": str(Decimal(quote.duration_seconds) / 60),
        "service_available": True,
        "currency": quote.currency,
        "suggested_fare_cents": quote.suggested_cents,
        "suggested_fare": f"{Decimal(quote.suggested_cents)/100:.2f}",
        "minimum_fare_cents": quote.minimum_cents,
        "maximum_fare_cents": quote.maximum_cents,
        "pricing_configuration": quote.pricing_snapshot,
        "routing_provider": quote.routing_provider,
        "exchange_rate": (
            str(quote.exchange_rate_value) if quote.exchange_rate_id else None
        ),
        "exchange_rate_timestamp": quote.exchange_rate_timestamp,
        "expires_at": quote.expires_at,
    }


class RideSerializer(serializers.ModelSerializer):
    pickup = PlaceSerializer(source="quote.pickup")
    destination = PlaceSerializer(source="quote.destination")
    category = serializers.CharField(source="quote.category")
    stops = PlaceSerializer(source="quote.stops", many=True, read_only=True)
    route_geometry = serializers.ListField(child=serializers.ListField(child=serializers.FloatField(), min_length=2, max_length=2), source="quote.route_geometry")
    distance_metres = serializers.IntegerField(source="quote.distance_metres")
    duration_seconds = serializers.IntegerField(source="quote.duration_seconds")
    suggested_fare_cents = serializers.IntegerField(source="quote.suggested_cents")
    fare_cents = serializers.SerializerMethodField()
    parcel_size = serializers.CharField(source="parcel.size", required=False, read_only=True)
    parcel_weight_kg = serializers.FloatField(source="parcel.weight_kg", required=False, read_only=True)
    payment_method_id = serializers.CharField(source="payment.method_id")
    assigned_driver_id = serializers.CharField(read_only=True, allow_null=True)
    sequence = serializers.IntegerField(read_only=True)
    payment_status = serializers.CharField(source="payment.status")
    payment_method_name = serializers.CharField(source="payment.method.name")
    payment_preference = serializers.ChoiceField(choices=["cash", "ecocash", "onemoney"])
    passenger_note = serializers.CharField(allow_blank=True, required=False)
    exchange_rate = serializers.DecimalField(
        source="quote.exchange_rate_value",
        max_digits=20,
        decimal_places=8,
        allow_null=True,
    )
    exchange_rate_timestamp = serializers.DateTimeField(
        source="quote.exchange_rate_timestamp", allow_null=True
    )

    class Meta:
        model = Ride
        fields = [
            "id",
            "assigned_driver_id",
            "sequence",
            "pickup",
            "destination",
            "stops",
            "category",
            "status",
            "created_at",
            "departure_at",
            "currency",
            "offered_fare",
            "agreed_fare",
            "fare_cents",
            "suggested_fare_cents",
            "payment_method_id",
            "payment_method_name",
            "payment_status",
            "payment_preference",
            "passenger_note",
            "passenger_count",
            "luggage",
            "parcel_size",
            "parcel_weight_kg",
            "distance_metres",
            "duration_seconds",
            "route_geometry",
            "exchange_rate",
            "exchange_rate_timestamp",
        ]
        read_only_fields = fields

    def get_fare_cents(self, ride) -> int:
        return int(
            (ride.agreed_fare if ride.agreed_fare is not None else ride.offered_fare)
            * 100
        )
