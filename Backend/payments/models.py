from decimal import Decimal
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models

CURRENCIES = [("USD", "United States Dollar")]


class PaymentMethod(models.Model):
    code = models.SlugField(primary_key=True)
    name = models.CharField(max_length=80)
    kind = models.CharField(
        max_length=16, choices=[("cash", "Cash"), ("mobile_money", "Mobile money")]
    )
    supported_currencies = models.JSONField(default=list)
    enabled = models.BooleanField(default=False)

    def clean(self):
        if not isinstance(self.supported_currencies, list) or any(
            c not in dict(CURRENCIES) for c in self.supported_currencies
        ):
            raise ValidationError(
                {"supported_currencies": "Use a list containing USD and/or ZWG."}
            )

    @property
    def operational(self):
        # No authorized gateway is integrated in this project yet. Merely
        # enabling an admin row must never turn on a nonexistent payment flow.
        return self.enabled and self.code in {"cash-usd", "ecocash", "onemoney"} and "USD" in self.supported_currencies

    def __str__(self):
        return self.name


class ExchangeRate(models.Model):
    """Audited, manually verified USD/ZWG rate, never a permanent default."""

    usd_to_zwg = models.DecimalField(
        max_digits=20,
        decimal_places=8,
        validators=[MinValueValidator(Decimal("0.00000001"))],
    )
    source_url = models.URLField(
        help_text="Authoritative HTTPS publication used for verification, e.g. RBZ."
    )
    observed_at = models.DateTimeField(
        help_text="Time the authoritative rate applies to."
    )
    valid_until = models.DateTimeField()
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def clean(self):
        from urllib.parse import urlparse

        if urlparse(self.source_url).scheme != "https":
            raise ValidationError(
                {"source_url": "An authoritative HTTPS source is required."}
            )
        if (
            self.observed_at
            and self.valid_until
            and self.valid_until <= self.observed_at
        ):
            raise ValidationError(
                {"valid_until": "Expiry must be after the observation."}
            )
        if self.pk:
            # Conversion snapshots refer to this audit record. Correct a rate
            # by creating a new record rather than rewriting historical evidence.
            old = type(self).objects.get(pk=self.pk)
            for field in (
                "usd_to_zwg",
                "source_url",
                "observed_at",
                "valid_until",
                "verified_at",
                "verified_by_id",
            ):
                if getattr(old, field) != getattr(self, field):
                    raise ValidationError(
                        "Exchange-rate records are immutable. Create a new verified record."
                    )

    def save(self, *args, **kwargs):
        self.full_clean()
        return super().save(*args, **kwargs)


class Payment(models.Model):
    ride = models.OneToOneField(
        "rides.Ride", on_delete=models.PROTECT, related_name="payment"
    )
    method = models.ForeignKey(PaymentMethod, on_delete=models.PROTECT)
    currency = models.CharField(max_length=3, choices=CURRENCIES)
    amount = models.DecimalField(
        max_digits=12, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))]
    )
    status = models.CharField(
        max_length=32,
        default="unverified",
        choices=[
            ("unverified", "Direct payment — receipt unverified"),
            ("pending_cash", "Historical cash due to driver"),
            ("awaiting_confirmation", "Awaiting provider confirmation"),
            ("paid", "Paid"),
            ("failed", "Failed"),
            ("cancelled", "Cancelled"),
        ],
    )
    created_at = models.DateTimeField(auto_now_add=True)
