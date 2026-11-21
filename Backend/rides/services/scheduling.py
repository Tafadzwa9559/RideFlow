from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError

from core import transactions as transaction
from rides.models import Ride
from rides.services.lifecycle import emit


MATCHING_LEAD = timedelta(minutes=15)
MAX_ADVANCE = timedelta(days=30)


def validate_departure(departure):
    now = timezone.now()
    if not now + MATCHING_LEAD < departure <= now + MAX_ADVANCE:
        raise ValidationError({
            "departure_at": "Choose a departure more than 15 minutes and at most 30 days from now."
        })


@transaction.atomic
def reschedule(user, ride_id, departure):
    transaction.guard(Ride, ride_id)
    ride = Ride.objects.get(pk=ride_id)
    if ride.passenger_id != user.pk:
        raise PermissionDenied()
    if ride.status != "scheduled" or ride.departure_at <= timezone.now() + MATCHING_LEAD:
        raise ValidationError("Departure can only be edited before matching opens.")
    validate_departure(departure)
    if ride.departure_at != departure:
        ride.departure_at = departure
        ride.save(update_fields=["departure_at"])
        emit(ride, "ride.rescheduled", {"departure_at": departure.isoformat()})
    return ride


@transaction.atomic
def open_matching(ride_id, now):
    transaction.guard(Ride, ride_id)
    ride = Ride.objects.get(pk=ride_id)
    if ride.status != "scheduled" or ride.departure_at > now + MATCHING_LEAD:
        return
    expires = ride.departure_at + timedelta(seconds=settings.RIDE_REQUEST_TTL)
    if expires <= now:
        ride.status = "expired"
        ride.payment.status = "cancelled"
        ride.payment.save(update_fields=["status"])
        event = "ride.expired"
    else:
        ride.status = "searching"
        event = "ride.matching_open"
    ride.expires_at = expires
    ride.save(update_fields=["status", "expires_at"])
    emit(ride, event, {"status": ride.status, "departure_at": ride.departure_at.isoformat()})
