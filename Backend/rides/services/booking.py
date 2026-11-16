import hashlib
import json
from datetime import timedelta
from decimal import Decimal, ROUND_HALF_UP, ROUND_CEILING, ROUND_FLOOR
from zoneinfo import ZoneInfo
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import APIException, ValidationError
from payments.models import Payment, PaymentMethod
from payments.services.exchange import verified_rate
from rides.models import FareQuote, PricingConfiguration, Ride, RideOffer
from .routing import driving_route


class QuoteExpired(APIException):
    status_code = 409
    default_detail = (
        "Route, pricing or exchange rate changed. Calculate a new fare before booking."
    )
    default_code = "quote_expired"


def pricing_snapshot(policy, now):
    hour = now.astimezone(ZoneInfo("Africa/Harare")).hour
    multiplier = Decimal(1)
    for band in policy.time_adjustments.filter(enabled=True).order_by(
        "-priority", "pk"
    ):
        inside = (
            band.start_hour <= hour < band.end_hour
            if band.start_hour < band.end_hour
            else hour >= band.start_hour or hour < band.end_hour
        )
        if inside:
            multiplier = band.multiplier
            break
    fields = [
        "base_fare_usd",
        "per_km_usd",
        "per_minute_usd",
        "booking_fee_usd",
        "minimum_offer_usd",
        "maximum_offer_usd",
        "rounding_usd",
    ]
    return {
        "id": policy.pk,
        "zone": policy.zone.name,
        "zone_id": policy.zone_id,
        "updated_at": policy.updated_at.isoformat(),
        "category": policy.category,
        "time_multiplier": str(multiplier),
        **{f: str(getattr(policy, f)) for f in fields},
    }


def cents(value, rounding=ROUND_HALF_UP):
    return int((value * 100).quantize(Decimal(1), rounding=rounding))


def quote_route(user, pickup, destination, category, currency):
    if currency != "USD":
        raise ValidationError({"currency": "Only USD fares are supported."})
    if (
        pickup["latitude"] == destination["latitude"]
        and pickup["longitude"] == destination["longitude"]
    ):
        raise ValidationError("Pickup and destination must differ.")
    policy = next(
        (
            p
            for p in PricingConfiguration.objects.select_related("zone")
            .filter(enabled=True, zone__enabled=True, category=category)
            .order_by("-priority", "pk")
            if p.zone.contains(pickup) and p.zone.contains(destination)
        ),
        None,
    )
    if policy is None:
        raise ValidationError(
            "No configured service coverage or pricing exists for this route and category.", code="OUTSIDE_SERVICE_AREA"
        )
    route = driving_route(pickup, destination)
    if not all(
        policy.zone.contains({"latitude": p[1], "longitude": p[0]})
        for p in route["geometry"]
    ):
        raise ValidationError(
            "The driving route leaves the configured service coverage."
        )
    now = timezone.now()
    rate, factor = verified_rate() if currency == "ZWG" else (None, Decimal(1))
    snapshot = pricing_snapshot(policy, now)
    distance_km = Decimal(route["distance_metres"]) / Decimal(1000)
    duration_minutes = Decimal(route["duration_seconds"]) / Decimal(60)
    base = (
        policy.base_fare_usd
        + distance_km * policy.per_km_usd
        + duration_minutes * policy.per_minute_usd
    )
    raw = (base * Decimal(snapshot["time_multiplier"]) + policy.booking_fee_usd) * factor
    increment = policy.rounding_zwg if currency == "ZWG" else policy.rounding_usd
    minimum = cents(policy.minimum_offer_usd * factor, ROUND_CEILING)
    maximum = cents(policy.maximum_offer_usd * factor, ROUND_FLOOR)
    rounded = cents(
        (raw / increment).quantize(Decimal(1), rounding=ROUND_HALF_UP) * increment
    )
    suggested = max(minimum, rounded)
    if suggested <= 0 or suggested > maximum or maximum > 999999999999:
        raise ValidationError(
            "This route exceeds the configured fare limits. Contact support or choose another route."
        )
    expires = now + timedelta(seconds=settings.TRIVIA_QUOTE_TTL_SECONDS)
    if rate:
        expires = min(
            expires,
            rate.valid_until,
            rate.observed_at + timedelta(seconds=settings.TRIVIA_EXCHANGE_MAX_AGE_SECONDS),
        )
    return FareQuote.objects.create(
        passenger=user,
        pickup=pickup,
        destination=destination,
        category=category,
        currency=currency,
        distance_metres=route["distance_metres"],
        duration_seconds=route["duration_seconds"],
        route_geometry=route["geometry"],
        routing_provider=route["provider"],
        pricing=policy,
        pricing_snapshot=snapshot,
        pricing_version=str(policy.pk) + ":" + snapshot["updated_at"],
        minimum_cents=minimum,
        maximum_cents=maximum,
        suggested_cents=suggested,
        exchange_rate=rate,
        exchange_rate_value=factor if rate else None,
        exchange_rate_timestamp=rate.observed_at if rate else None,
        expires_at=expires,
    )


def fingerprint(data):
    return hashlib.sha256(
        json.dumps(data, sort_keys=True, default=str).encode()
    ).hexdigest()


@transaction.atomic
def _validate_route_quote(quote, data, now):
    if quote.expires_at <= now:
        raise QuoteExpired()
    if not quote.pricing.enabled or not quote.pricing.zone.enabled:
        raise QuoteExpired()
    if quote.pricing_snapshot != pricing_snapshot(quote.pricing, now):
        raise QuoteExpired()
    for field in ["pickup", "destination", "category", "currency"]:
        if getattr(quote, field) != data[field]:
            raise ValidationError(
                f"{field} does not match the route quote. Recalculate the fare."
            )
    if not all(
        quote.pricing.zone.contains({"latitude": p[1], "longitude": p[0]})
        for p in quote.route_geometry
    ):
        raise QuoteExpired()
    if quote.exchange_rate_id and verified_rate()[0].pk != quote.exchange_rate_id:
        raise QuoteExpired()


@transaction.atomic
def book(user, data):
    get_user_model().objects.select_for_update().get(pk=user.pk)
    from rides.models import ActiveAssignment
    if ActiveAssignment.objects.filter(driver__user=user).exists():
        raise ValidationError('Finish your driver assignment before requesting a passenger ride.')
    key = data["idempotency_key"]
    digest = fingerprint(data)
    existing = (
        Ride.objects.select_related("quote", "payment__method")
        .filter(passenger=user, idempotency_key=key)
        .first()
    )
    if existing:
        if existing.request_fingerprint != digest:
            raise ValidationError(
                "This request key was already used for a different booking."
            )
        return existing, False
    if (
        Ride.objects.filter(passenger=user)
        .exclude(status__in=["completed", "cancelled", "expired"])
        .exists()
    ):
        raise ValidationError(
            "Complete or cancel your current ride before requesting another."
        )
    quote = (
        FareQuote.objects.select_for_update()
        .select_related("pricing__zone", "exchange_rate")
        .filter(pk=data["quote_id"], passenger=user)
        .first()
    )
    if quote is None:
        raise ValidationError(
            "A valid route quote belonging to this passenger is required."
        )
    now = timezone.now()
    _validate_route_quote(quote, data, now)
    amount = data["fare_cents"]
    if not quote.minimum_cents <= amount <= quote.maximum_cents:
        raise ValidationError(
            {
                "fare_cents": "Offer must respect the minimum and maximum returned by the current quote."
            }
        )
    method = (
        PaymentMethod.objects.select_for_update()
        .filter(pk=data["payment_method_id"])
        .first()
    )
    if method is None or quote.currency not in method.supported_currencies:
        raise ValidationError(
            {
                "payment_method_id": "Choose a payment method compatible with the selected currency."
            }
        )
    if not method.operational:
        raise ValidationError(
            {
                "payment_method_id": "Choose an enabled direct-payment preference."
            }
        )
    if Ride.objects.filter(quote=quote).exists():
        raise ValidationError("This quote was already used. Calculate a new fare.")
    ride = Ride.objects.create(
        passenger=user,
        quote=quote,
        currency=quote.currency,
        idempotency_key=key,
        request_fingerprint=digest,
        offered_fare=Decimal(amount) / 100,
        payment_preference={"cash-usd": "cash", "ecocash": "ecocash", "onemoney": "onemoney"}[method.pk],
        expires_at=now + timedelta(seconds=settings.RIDE_REQUEST_TTL),
        passenger_note=data.get("passenger_note", "")[:250],
        pricing_version=quote.pricing_version,
    )
    Payment.objects.create(
        ride=ride,
        method=method,
        currency=quote.currency,
        amount=ride.offered_fare,
        status="unverified",
    )
    from rides.services.lifecycle import emit
    emit(ride, "ride.created")
    from rides.tasks import dispatch_request
    transaction.on_commit(lambda: dispatch_request.delay(str(ride.pk)), robust=True)
    return ride, True


def validate_offer(ride, amount, *, offer_type="passenger"):
    if amount <= 0:
        raise ValidationError({"fare_cents": "Offer must be greater than zero."})
    if amount < ride.quote.minimum_cents:
        raise ValidationError(
            {"fare_cents": f"Offer must be at least {ride.quote.minimum_cents} cents."}
        )
    if ride.quote.maximum_cents and amount > ride.quote.maximum_cents:
        raise ValidationError(
            {"fare_cents": f"Offer may not exceed {ride.quote.maximum_cents} cents."}
        )
    if not ride.quote.pricing_snapshot:
        raise ValidationError({"fare_cents": "Quote is invalid or expired."})
    if offer_type == "driver" and amount <= 0:
        raise ValidationError({"fare_cents": "Driver offers must be positive."})
    return True
