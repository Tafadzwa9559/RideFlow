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
    pickup = models.JSONField()
    destination = models.JSONField()
    category = models.CharField(max_length=30)
    currency = models.CharField(max_length=3, choices=CURRENCIES)
    distance_metres = models.PositiveIntegerField()
    duration_seconds = models.PositiveIntegerField()
    route_geometry = models.JSONField()
    routing_provider = models.CharField(max_length=100)
    pricing = models.ForeignKey(PricingConfiguration, on_delete=models.PROTECT)
    pricing_snapshot = models.JSONField()
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


class Ride(models.Model):
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
            ]
        ],
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["passenger", "idempotency_key"],
                name="unique_passenger_booking_key",
            )
        ]
