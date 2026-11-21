from datetime import timedelta
from hmac import compare_digest

from django.utils import timezone
from django.utils.crypto import salted_hmac
from rest_framework.exceptions import PermissionDenied, ValidationError

from core import transactions as transaction
from rides.models import Ride

CATEGORY = "Courier"
MAX_ATTEMPTS = 5
COOLDOWN = timedelta(minutes=15)


def confirmation_code(ride):
    digest = salted_hmac("trivia.courier.delivery", str(ride.pk), algorithm="sha256").hexdigest()
    return f"{int(digest, 16) % 100_000_000:08d}"


@transaction.atomic
def confirm_delivery(user, ride_id, code):
    transaction.guard(Ride, ride_id)
    ride = Ride.objects.select_related("assigned_driver", "quote").get(pk=ride_id)
    if ride.quote.category != CATEGORY or not ride.assigned_driver or ride.assigned_driver.user_id != user.pk:
        raise PermissionDenied()
    if ride.status == "completed":
        return ride
    if ride.status != "inProgress":
        raise ValidationError("Confirm parcel pickup before completing delivery.")
    now = timezone.now()
    if ride.proof_blocked_until and ride.proof_blocked_until > now:
        return None
    if not compare_digest(code, confirmation_code(ride)):
        ride.proof_attempts = (0 if ride.proof_blocked_until else ride.proof_attempts) + 1
        ride.proof_blocked_until = now + COOLDOWN if ride.proof_attempts >= MAX_ATTEMPTS else None
        ride.save(update_fields=["proof_attempts", "proof_blocked_until"])
        return None
    from rides.services.lifecycle import transition
    return transition(user, ride_id, "completed", delivery_proven=True)
