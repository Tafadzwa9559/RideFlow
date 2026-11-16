from decimal import Decimal
from rest_framework import serializers
from rest_framework.exceptions import ErrorDetail
from payments.models import CURRENCIES
from rides.models import Ride


class PlaceSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=200)
    latitude = serializers.FloatField(min_value=-90, max_value=90)
    longitude = serializers.FloatField(min_value=-180, max_value=180)

    def validate(self, data):
        import math

        for key in ["latitude", "longitude"]:
            if not math.isfinite(data[key]):
                raise serializers.ValidationError("Coordinates must be finite numbers.")
            data[key] = float(Decimal(str(data[key])).quantize(Decimal("0.000001")))
        return data


class QuoteRequestSerializer(serializers.Serializer):
    pickup = PlaceSerializer()
    destination = PlaceSerializer()
    category = serializers.ChoiceField(choices=["Standard", "Comfort", "XL"])
    currency = serializers.ChoiceField(choices=["USD"], default="USD")


class BookingRequestSerializer(QuoteRequestSerializer):
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
    route_geometry = serializers.ListField(child=serializers.ListField(child=serializers.FloatField(), min_length=2, max_length=2), source="quote.route_geometry")
    distance_metres = serializers.IntegerField(source="quote.distance_metres")
    duration_seconds = serializers.IntegerField(source="quote.duration_seconds")
    suggested_fare_cents = serializers.IntegerField(source="quote.suggested_cents")
    fare_cents = serializers.SerializerMethodField()
    payment_method_id = serializers.CharField(source="payment.method_id")
    assigned_driver_id = serializers.IntegerField(read_only=True, allow_null=True)
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
            "category",
            "status",
            "created_at",
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
