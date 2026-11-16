from core.identifiers import StorageJSONEncoder
import uuid
from decimal import Decimal
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from payments.models import CURRENCIES

positive = MinValueValidator(Decimal("0.01"))
nonnegative = MinValueValidator(Decimal("0"))


class PricingZone(models.Model):
    name = models.CharField(max_length=100)
    enabled = models.BooleanField(default=False)
    south = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=[MinValueValidator(-90), MaxValueValidator(90)],
    )
    north = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=[MinValueValidator(-90), MaxValueValidator(90)],
    )
    west = models.DecimalField(
        max_digits=10,
        decimal_places=6,
        validators=[MinValueValidator(-180), MaxValueValidator(180)],
    )
    east = models.DecimalField(
        max_digits=10,
        decimal_places=6,
        validators=[MinValueValidator(-180), MaxValueValidator(180)],
    )

    def clean(self):
        if self.south >= self.north or self.west >= self.east:
            raise ValidationError(
                "Zone bounds must define a valid rectangular coverage area."
            )

    def contains(self, place):
        return (
            self.south <= Decimal(str(place["latitude"])) <= self.north
            and self.west <= Decimal(str(place["longitude"])) <= self.east
        )

    def __str__(self):
        return self.name


class PricingConfiguration(models.Model):
    zone = models.ForeignKey(
        PricingZone, on_delete=models.PROTECT, related_name="prices"
    )
    category = models.CharField(
        max_length=30,
        choices=[
            ("Standard", "Trivia Standard"),
            ("Comfort", "Trivia Comfort"),
            ("XL", "Trivia XL"),
        ],
    )
    enabled = models.BooleanField(default=False)
    base_fare_usd = models.DecimalField(
        max_digits=10, decimal_places=4, validators=[nonnegative]
    )
    per_km_usd = models.DecimalField(
        max_digits=10, decimal_places=4, validators=[nonnegative]
    )
    per_minute_usd = models.DecimalField(
        max_digits=10, decimal_places=4, validators=[nonnegative]
    )
    booking_fee_usd = models.DecimalField(
        max_digits=10, decimal_places=4, default=0, validators=[nonnegative]
    )
    minimum_offer_usd = models.DecimalField(
        max_digits=10, decimal_places=2, validators=[positive]
    )
    maximum_offer_usd = models.DecimalField(
        max_digits=10, decimal_places=2, validators=[positive]
    )
    rounding_usd = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal("0.01"), validators=[positive]
    )
    rounding_zwg = models.DecimalField(
        max_digits=10, decimal_places=2, default=Decimal("0.01"), validators=[positive]
    )
    priority = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["zone", "category"], name="one_category_price_per_zone"
            )
        ]

    def clean(self):
        if self.minimum_offer_usd > self.maximum_offer_usd:
            raise ValidationError("Minimum offer must not exceed maximum offer.")

    def __str__(self):
        return f"{self.zone} / {self.category}"


class TimeAdjustment(models.Model):
    pricing = models.ForeignKey(
        PricingConfiguration, on_delete=models.CASCADE, related_name="time_adjustments"
    )
    start_hour = models.PositiveSmallIntegerField(validators=[MaxValueValidator(23)])
    end_hour = models.PositiveSmallIntegerField(validators=[MaxValueValidator(23)])
    multiplier = models.DecimalField(
        max_digits=6, decimal_places=3, validators=[MinValueValidator(Decimal("0.001"))]
    )
    priority = models.PositiveIntegerField(default=0)
    enabled = models.BooleanField(default=True)

    def clean(self):
        if self.start_hour == self.end_hour:
            raise ValidationError(
                "Use distinct start/end hours; overnight windows are supported."
            )

    def save(self, *args, **kwargs):
        result = super().save(*args, **kwargs)
        from django.utils import timezone

        PricingConfiguration.objects.filter(pk=self.pricing_id).update(
            updated_at=timezone.now()
        )
        return result

    def delete(self, *args, **kwargs):
        pricing_id = self.pricing_id
        result = super().delete(*args, **kwargs)
        from django.utils import timezone

        PricingConfiguration.objects.filter(pk=pricing_id).update(
            updated_at=timezone.now()
        )
        return result


class FareQuote(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    passenger = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    pickup = models.JSONField(encoder=StorageJSONEncoder, )
    destination = models.JSONField(encoder=StorageJSONEncoder, )
    category = models.CharField(max_length=30)
    currency = models.CharField(max_length=3, choices=CURRENCIES)
    distance_metres = models.PositiveIntegerField()
    duration_seconds = models.PositiveIntegerField()
    route_geometry = models.JSONField(encoder=StorageJSONEncoder, )
    routing_provider = models.CharField(max_length=100)
    pricing = models.ForeignKey(PricingConfiguration, on_delete=models.PROTECT)
    pricing_snapshot = models.JSONField(encoder=StorageJSONEncoder, )
    pricing_version = models.CharField(max_length=100, blank=True, default="")
    minimum_cents = models.PositiveBigIntegerField()
    maximum_cents = models.PositiveBigIntegerField()
    suggested_cents = models.PositiveBigIntegerField()
    exchange_rate = models.ForeignKey(
        "payments.ExchangeRate", null=True, on_delete=models.PROTECT
    )
    exchange_rate_value = models.DecimalField(
        max_digits=20, decimal_places=8, null=True
    )
    exchange_rate_timestamp = models.DateTimeField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()


class RideOffer(models.Model):
    driver = models.ForeignKey('drivers.DriverApplication', null=True, on_delete=models.PROTECT, related_name='offers')
    vehicle = models.ForeignKey('drivers.Vehicle', null=True, on_delete=models.PROTECT)
    status = models.CharField(max_length=20, default='pending', choices=[(s, s) for s in ['pending', 'accepted', 'rejected', 'withdrawn', 'expired', 'declined']])
    expires_at = models.DateTimeField(null=True)
    pickup_minutes = models.PositiveSmallIntegerField(null=True, blank=True)
    offer_type = models.CharField(
        max_length=20,
        choices=[("passenger", "Passenger"), ("driver", "Driver")],
        default="driver",
    )
    ride = models.ForeignKey(
        "Ride",
        on_delete=models.CASCADE,
        related_name="counteroffers",
    )
    amount = models.DecimalField(max_digits=12, decimal_places=2, validators=[positive])
    note = models.TextField(blank=True, default="")
    accepted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.UniqueConstraint(fields=['ride', 'driver'], name='one_driver_offer_per_ride')]


class Ride(models.Model):
    assigned_driver = models.ForeignKey('drivers.DriverApplication', null=True, on_delete=models.PROTECT, related_name='trips')
    assigned_vehicle = models.ForeignKey('drivers.Vehicle', null=True, on_delete=models.PROTECT)
    expires_at = models.DateTimeField(null=True, db_index=True)
    accepted_at = models.DateTimeField(null=True)
    arrived_at = models.DateTimeField(null=True)
    started_at = models.DateTimeField(null=True)
    completed_at = models.DateTimeField(null=True)
    cancelled_at = models.DateTimeField(null=True)
    cancellation_reason = models.CharField(max_length=500, blank=True)
    sequence = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    passenger = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="trivia_rides"
    )
    quote = models.OneToOneField(FareQuote, on_delete=models.PROTECT)
    idempotency_key = models.UUIDField()
    request_fingerprint = models.CharField(max_length=64)
    currency = models.CharField(max_length=3, choices=CURRENCIES)
    offered_fare = models.DecimalField(
        max_digits=12, decimal_places=2, validators=[positive]
    )
    agreed_fare = models.DecimalField(
        max_digits=12, decimal_places=2, null=True, blank=True, validators=[positive]
    )
    payment_preference = models.CharField(
        max_length=20,
        choices=[
            ("ecocash", "EcoCash"),
            ("onemoney", "OneMoney"),
            ("cash", "Cash"),
        ],
        default="cash",
    )
    passenger_note = models.TextField(blank=True, default="")
    pricing_version = models.CharField(max_length=100, blank=True, default="")
    status = models.CharField(
        max_length=20,
        default="searching",
        choices=[
            (s, s)
            for s in [
                "searching",
                "assigned",
                "arriving",
                "arrived",
                "inProgress",
                "completed",
                "cancelled",
                "expired",
            ]
        ],
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["status", "created_at"]), models.Index(fields=["passenger", "status"])]
        constraints = [
            models.UniqueConstraint(
                fields=["passenger", "idempotency_key"],
                name="unique_passenger_booking_key",
            )
        ]


class ActiveAssignment(models.Model):
    """Unconditional unique keys work on MySQL, unlike conditional indexes."""
    ride = models.OneToOneField(Ride, on_delete=models.PROTECT, related_name='active_assignment')
    driver = models.OneToOneField('drivers.DriverApplication', on_delete=models.PROTECT, related_name='active_assignment')
    passenger = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='active_assignment')


class RideEvent(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ride = models.ForeignKey(Ride, on_delete=models.PROTECT, related_name='events')
    sequence = models.PositiveIntegerField()
    event_type = models.CharField(max_length=80)
    payload = models.JSONField(encoder=StorageJSONEncoder, default=dict)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['ride', 'sequence'], name='unique_ride_event_sequence')]
        ordering = ['sequence']


class LocationUpdate(models.Model):
    ride = models.ForeignKey(Ride, on_delete=models.CASCADE, related_name='locations')
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=10, decimal_places=6)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)


class Rating(models.Model):
    ride = models.ForeignKey(Ride, on_delete=models.PROTECT, related_name='ratings')
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='ratings_given')
    subject = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='ratings_received')
    score = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.CharField(max_length=500, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['ride', 'author'], name='one_rating_per_ride_author')]


class SupportTicket(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    ride = models.ForeignKey(Ride, null=True, blank=True, on_delete=models.PROTECT)
    category = models.CharField(max_length=20, choices=[(s, s) for s in ['support', 'safety']])
    message = models.CharField(max_length=2000)
    status = models.CharField(max_length=20, default='open', choices=[(s, s) for s in ['open', 'investigating', 'resolved']])
    created_at = models.DateTimeField(auto_now_add=True)


class SavedPlace(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    label = models.CharField(max_length=80)
    place = models.JSONField(encoder=StorageJSONEncoder, )


class EmergencyContact(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    phone = models.CharField(max_length=16)


class TripShare(models.Model):
    ride = models.ForeignKey(Ride, on_delete=models.CASCADE)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='trip_shares_created')
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='trip_shares_received')
    expires_at = models.DateTimeField()
    revoked = models.BooleanField(default=False)
