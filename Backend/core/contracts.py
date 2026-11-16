from core.identifiers import ObjectIdSerializerField
"""Typed wire contracts for computed REST responses and business commands."""
from rest_framework import serializers as s
from rides.api.serializers import PlaceSerializer, RideSerializer, QuoteRequestSerializer
from rides.models import RideEvent


class ErrorSerializer(s.Serializer):
    errors = s.JSONField(help_text='Field errors or a detail message; never internal exception details.')
    code = s.CharField(help_text='Stable machine-readable exception code.')
    field_codes = s.JSONField(help_text='Error codes parallel to errors for field-specific handling.')
    request_id = s.CharField(allow_null=True)


class DetailSerializer(s.Serializer):
    detail = s.CharField()


class IdentifierSerializer(s.Serializer):
    id = ObjectIdSerializerField()


class StatusSerializer(s.Serializer):
    status = s.CharField()


class StateCommandSerializer(s.Serializer):
    status = s.ChoiceField(choices=['arriving', 'arrived', 'inProgress', 'completed', 'cancelled'])
    reason = s.CharField(max_length=500, required=False, allow_blank=True)


class ReasonSerializer(s.Serializer):
    reason = s.CharField(max_length=500)


class OptionalReasonSerializer(s.Serializer):
    reason = s.CharField(max_length=500, required=False, allow_blank=True)


class ActiveSerializer(s.Serializer):
    active = s.BooleanField()


class ApprovedSerializer(s.Serializer):
    approved = s.BooleanField()


class OnlineSerializer(s.Serializer):
    online = s.BooleanField()


class ReviewSerializer(ReasonSerializer):
    reason = s.CharField(max_length=500, required=False)
    decision = s.ChoiceField(choices=['underReview', 'approved', 'rejected', 'suspended'])


class SelectionSerializer(s.Serializer):
    offer_id = ObjectIdSerializerField()


class LogoutSerializer(s.Serializer):
    refresh = s.CharField(required=False, allow_null=True)


class ProfileSerializer(s.Serializer):
    id = ObjectIdSerializerField()
    first_name = s.CharField()
    last_name = s.CharField()
    email = s.CharField(allow_blank=True)
    phone = s.CharField()
    driver_status = s.CharField()


class TokensSerializer(s.Serializer):
    access = s.CharField()
    refresh = s.CharField()
    user = ProfileSerializer()


class PricingSnapshotSerializer(s.Serializer):
    id = ObjectIdSerializerField()
    zone = s.CharField()
    zone_id = ObjectIdSerializerField()
    updated_at = s.DateTimeField()
    category = s.CharField()
    time_multiplier = s.DecimalField(max_digits=6, decimal_places=3)
    base_fare_usd = s.DecimalField(max_digits=10, decimal_places=4)
    per_km_usd = s.DecimalField(max_digits=10, decimal_places=4)
    per_minute_usd = s.DecimalField(max_digits=10, decimal_places=4)
    booking_fee_usd = s.DecimalField(max_digits=10, decimal_places=4)
    minimum_offer_usd = s.DecimalField(max_digits=10, decimal_places=2)
    maximum_offer_usd = s.DecimalField(max_digits=10, decimal_places=2)
    rounding_usd = s.DecimalField(max_digits=10, decimal_places=2)


class QuoteSerializer(s.Serializer):
    id = s.UUIDField()
    geometry = s.ListField(child=s.ListField(child=s.FloatField(), min_length=2, max_length=2))
    distance_metres = s.IntegerField()
    distance_km = s.CharField()
    duration_seconds = s.IntegerField()
    estimated_minutes = s.CharField()
    service_available = s.BooleanField()
    currency = s.ChoiceField(choices=['USD'])
    suggested_fare_cents = s.IntegerField()
    suggested_fare = s.DecimalField(max_digits=12, decimal_places=2)
    minimum_fare_cents = s.IntegerField()
    maximum_fare_cents = s.IntegerField()
    pricing_configuration = PricingSnapshotSerializer()
    routing_provider = s.CharField()
    exchange_rate = s.CharField(allow_null=True, help_text='Legacy field; null in USD-only booking.')
    exchange_rate_timestamp = s.DateTimeField(allow_null=True)
    expires_at = s.DateTimeField()


class RouteSerializer(s.Serializer):
    distance_metres = s.IntegerField()
    duration_seconds = s.IntegerField()
    geometry = s.ListField(child=s.ListField(child=s.FloatField()))
    provider = s.CharField()


class OfferSerializer(s.Serializer):
    id = s.CharField()
    driver_name = s.CharField()
    vehicle = s.CharField()
    colour = s.CharField()
    registration = s.CharField()
    fare_cents = s.IntegerField()
    currency = s.ChoiceField(choices=['USD'])
    status = s.ChoiceField(choices=['pending', 'accepted', 'rejected', 'withdrawn', 'expired', 'declined'])
    rating = s.FloatField(allow_null=True)
    completed_trips = s.IntegerField()
    pickup_minutes = s.IntegerField(allow_null=True)
    verified = s.BooleanField()
    expires_at = s.DateTimeField(allow_null=True)
    note = s.CharField(allow_blank=True)


class OfferCreatedSerializer(s.Serializer):
    id = s.CharField()
    status = s.CharField()


class ActiveRideSerializer(s.Serializer):
    ride = RideSerializer(allow_null=True)


class RideStatusSerializer(s.Serializer):
    id = s.UUIDField()
    status = s.CharField()
    sequence = s.IntegerField()
    updated_at = s.DateTimeField()


class LocationSerializer(s.Serializer):
    latitude = s.DecimalField(max_digits=9, decimal_places=6)
    longitude = s.DecimalField(max_digits=10, decimal_places=6)
    created_at = s.DateTimeField()


class TrackingSerializer(s.Serializer):
    ride_id = s.UUIDField()
    status = s.CharField()
    location = LocationSerializer(allow_null=True)


class ReceiptSerializer(s.Serializer):
    ride_id = s.UUIDField()
    currency = s.ChoiceField(choices=['USD'])
    agreed_fare = s.DecimalField(max_digits=12, decimal_places=2)
    payment_preference = s.ChoiceField(choices=['ecocash', 'onemoney', 'cash'])
    payment_receipt_verified = s.BooleanField(default=False)
    platform_processed_payment = s.BooleanField(default=False)
    notice = s.CharField()
    started_at = s.DateTimeField(allow_null=True)
    completed_at = s.DateTimeField(allow_null=True)
    trip_duration_seconds = s.IntegerField(allow_null=True)


class EventPayloadSerializer(s.Serializer):
    status = s.CharField(required=False)
    offer_id = ObjectIdSerializerField(required=False)
    ride_id = s.UUIDField(required=False)
    latitude = s.CharField(required=False)
    longitude = s.CharField(required=False)
    at = s.DateTimeField(required=False)
    redacted = s.BooleanField(required=False)


class TimelineEventSerializer(s.ModelSerializer):
    payload = EventPayloadSerializer()

    class Meta:
        model = RideEvent
        fields = ['id', 'sequence', 'event_type', 'payload', 'created_at']


class EventsSerializer(s.Serializer):
    sequence = s.IntegerField()
    results = TimelineEventSerializer(many=True)


class NotificationSerializer(s.Serializer):
    id = s.UUIDField()
    schema_version = s.IntegerField()
    event_id = s.UUIDField()
    type = s.CharField()
    resource_id = s.CharField()
    timestamp = s.DateTimeField()
    sequence = s.IntegerField()
    payload = EventPayloadSerializer()
    read_at = s.DateTimeField(allow_null=True)


class CountSerializer(s.Serializer):
    count = s.IntegerField()


class UpdatedSerializer(s.Serializer):
    updated = s.IntegerField()


class ReadSerializer(s.Serializer):
    read_at = s.DateTimeField()


class DeviceRequestSerializer(s.Serializer):
    token = s.CharField(max_length=512, write_only=True)
    platform = s.ChoiceField(choices=['android', 'ios'])


class DeviceSerializer(s.Serializer):
    id = ObjectIdSerializerField()
    platform = s.ChoiceField(choices=['android', 'ios'])


class TokenDeleteSerializer(s.Serializer):
    token = s.CharField(max_length=512)


class EarningsSerializer(s.Serializer):
    currency = s.ChoiceField(choices=['USD'])
    completed_trips = s.IntegerField()
    agreed_fares = s.DecimalField(max_digits=14, decimal_places=2)
    payment_receipt_verified = s.BooleanField()


class PeriodTotalsSerializer(s.Serializer):
    day = s.DecimalField(max_digits=14, decimal_places=2)
    week = s.DecimalField(max_digits=14, decimal_places=2)
    month = s.DecimalField(max_digits=14, decimal_places=2)


class EarningsSummarySerializer(s.Serializer):
    currency = s.ChoiceField(choices=['USD'])
    totals = PeriodTotalsSerializer()
    completed_trips = s.IntegerField()
    payment_receipt_verified = s.BooleanField()
    commission = s.DecimalField(max_digits=14, decimal_places=2, allow_null=True)


class StatisticsSerializer(s.Serializer):
    completed_trips = s.IntegerField()
    cancelled_trips = s.IntegerField()
    rating = s.FloatField(allow_null=True)


class AvailabilitySerializer(s.Serializer):
    status = s.CharField()
    last_seen = s.DateTimeField(allow_null=True)
    location_fresh = s.BooleanField()
    active_vehicle_id = ObjectIdSerializerField(allow_null=True)


class LastSeenSerializer(s.Serializer):
    last_seen = s.DateTimeField()


class RequirementSerializer(s.Serializer):
    scope = s.ChoiceField(choices=['driver', 'vehicle'])
    code = s.SlugField()
    label = s.CharField()
    required = s.BooleanField()
    expiry_required = s.BooleanField()


class RatingRequestSerializer(s.Serializer):
    score = s.IntegerField(min_value=1, max_value=5)
    comment = s.CharField(max_length=500, required=False)


class RatingCreatedSerializer(s.Serializer):
    id = ObjectIdSerializerField()
    score = s.IntegerField()


class MessageSerializer(s.Serializer):
    message = s.CharField(max_length=2000)


class ShareRequestSerializer(s.Serializer):
    recipient_id = ObjectIdSerializerField()


class ShareSerializer(s.Serializer):
    id = ObjectIdSerializerField()
    expires_at = s.DateTimeField()


class SharedTripSerializer(s.Serializer):
    ride_id = s.UUIDField()
    status = s.CharField()
    pickup = PlaceSerializer()
    destination = PlaceSerializer()
    driver_location = LocationSerializer(allow_null=True)


class StatusCountSerializer(s.Serializer):
    status = s.CharField()
    count = s.IntegerField()


class OverviewSerializer(s.Serializer):
    rides_by_status = StatusCountSerializer(many=True)
    completed_agreed_fares_usd = s.DecimalField(max_digits=16, decimal_places=2)
    drivers_by_status = StatusCountSerializer(many=True)
    open_tickets = s.IntegerField()
    payment_receipt_verified = s.BooleanField()


class RideAnalyticsRowSerializer(StatusCountSerializer):
    date = s.DateField()
    agreed_fares = s.DecimalField(max_digits=16, decimal_places=2, allow_null=True)


class DriverAnalyticsRowSerializer(StatusCountSerializer):
    availability = s.CharField()


class PaymentMethodSerializer(s.Serializer):
    id = s.CharField()
    name = s.CharField()
    kind = s.CharField()
    currencies = s.ListField(child=s.ChoiceField(choices=['USD']))
    enabled = s.BooleanField()
    description = s.CharField()


class CurrencySerializer(s.Serializer):
    code = s.ChoiceField(choices=['USD'])
    name = s.CharField()
    symbol = s.CharField()


class CurrenciesSerializer(s.Serializer):
    items = CurrencySerializer(many=True)
    default = s.ChoiceField(choices=['USD'])


class PaymentHistoryRowSerializer(s.Serializer):
    id = s.CharField()
    ride_id = s.CharField()
    name = s.CharField()
    method = s.CharField()
    currency = s.CharField()
    amount = s.DecimalField(max_digits=12, decimal_places=2)
    status = s.CharField()
    description = s.CharField()


_collections = {}

def collection(name, child, key='results', paginated=False, extra=None):
    if name in _collections:
        return _collections[name]
    fields = {key: child(many=True)}
    if paginated:
        fields.update({'count': s.IntegerField(), 'next': s.URLField(allow_null=True), 'previous': s.URLField(allow_null=True)})
    fields.update(extra or {})
    _collections[name] = type(name, (s.Serializer,), fields)
    return _collections[name]


class OfferUpdatedSerializer(s.Serializer):
    id = ObjectIdSerializerField()
    status = s.CharField()
    fare_cents = s.IntegerField()


class DriverDeclineSerializer(s.Serializer):
    id = s.UUIDField()
    offer_id = ObjectIdSerializerField(required=False)
    status = s.CharField()
    message = s.CharField(required=False)


class RideSyncSerializer(s.Serializer):
    id = s.UUIDField()
    status = s.CharField()
    assigned_driver_id = ObjectIdSerializerField(allow_null=True)
    assigned_vehicle_id = ObjectIdSerializerField(allow_null=True)
    agreed_fare = s.CharField(allow_null=True)
    payment_preference = s.CharField()
    current_trip_stage = s.CharField()
    latest_sequence = s.IntegerField()
    server_timestamp = s.DateTimeField()
    pending_actions = s.ListField(child=s.CharField())
    request_expires_at = s.DateTimeField(allow_null=True)
    updated_at = s.DateTimeField()
