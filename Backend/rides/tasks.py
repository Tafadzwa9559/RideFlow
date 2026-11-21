from datetime import timedelta
from celery import shared_task
from django.conf import settings
from core import transactions as transaction
from django.utils import timezone
from rest_framework.exceptions import APIException
from drivers.models import DriverApplication
from drivers.services.eligibility import eligible
from notifications.services.events import notify
from rides.models import Ride, RideOffer, LocationUpdate
from rides.services.lifecycle import nearby, emit


@shared_task
def dispatch_request(ride_id):
    ride = Ride.objects.select_related('quote__pricing__zone').get(pk=ride_id)
    if ride.status != 'searching' or ride.expires_at <= timezone.now():
        return
    from drivers.services.matching import nearby_drivers
    for app in nearby_drivers(ride):
        try:
            eligible(app, online=True)
            if not hasattr(app, 'active_assignment') and nearby(app, ride):
                # Stable dispatch identifier makes retries safe; no private notes in event.
                import uuid
                event_id = str(uuid.uuid5(ride.pk, f'dispatch:{app.pk}'))
                notify(app.user_id, 'ride.request', str(ride.pk), {'ride_id': str(ride.pk), 'service': ride.quote.category}, event_id=event_id)
        except APIException:
            continue


@shared_task
@transaction.retry
def maintenance():
    from rides.services.scheduling import MATCHING_LEAD, open_matching

    now = timezone.now()
    due = Ride.objects.filter(status='scheduled', departure_at__lte=now + MATCHING_LEAD)
    for pk in due.order_by('departure_at').values_list('pk', flat=True)[:1000]:
        open_matching(pk, now)
    for pk in Ride.objects.filter(status='searching', expires_at__lte=now).values_list('pk', flat=True)[:1000]:
        with transaction.atomic():
            transaction.guard(Ride, pk)
            ride = Ride.objects.get(pk=pk)
            if ride.status != 'searching':
                continue
            ride.status = 'expired'
            ride.save(update_fields=['status'])
            RideOffer.objects.filter(ride=ride, status='pending').update(status='expired')
            ride.payment.status = 'cancelled'
            ride.payment.save(update_fields=['status'])
            emit(ride, 'ride.expired')
    for pk in RideOffer.objects.filter(status='pending', expires_at__lte=now).values_list('pk', flat=True)[:1000]:
        with transaction.atomic():
            initial = RideOffer.objects.get(pk=pk)
            transaction.guard(Ride, initial.ride_id)
            ride = Ride.objects.get(pk=initial.ride_id)
            offer = RideOffer.objects.all().get(pk=pk)
            if offer.status == 'pending' and offer.expires_at <= now:
                offer.status = 'expired'
                offer.save(update_fields=['status'])
                emit(ride, 'offer.expired', {'offer_id': offer.pk})
    DriverApplication.objects.filter(availability='online', last_seen__lt=now-timedelta(seconds=settings.DRIVER_LOCATION_TTL)).update(availability='offline')
    # Retry-safe discovery also reaches drivers who came online after initial dispatch.
    for pk in Ride.objects.filter(status='searching', expires_at__gt=now).values_list('pk', flat=True)[:1000]:
        dispatch_request(str(pk))


@shared_task
def retention():
    from accounts.models import PhoneChallenge
    PhoneChallenge.objects.filter(expires_at__lt=timezone.now()-timedelta(days=1)).delete()
    cutoff = timezone.now()-timedelta(days=settings.LOCATION_RETENTION_DAYS)
    LocationUpdate.objects.filter(created_at__lt=cutoff).delete()
    from rides.models import RideEvent
    from notifications.models import Notification
    RideEvent.objects.filter(event_type='driver.location', created_at__lt=cutoff).update(payload={'redacted': True})
    Notification.objects.filter(envelope__type='driver.location', created_at__lt=cutoff).delete()
