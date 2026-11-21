import math
from datetime import timedelta
from decimal import Decimal
from django.conf import settings
from core import transactions as transaction
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError
from drivers.models import DriverApplication
from drivers.services.eligibility import driver_for, eligible
from rides.models import Ride, RideOffer, ActiveAssignment, RideEvent, LocationUpdate

from rides.services.intercity import CATEGORY
from rides.services.courier import CATEGORY as COURIER

TERMINAL = ['completed', 'cancelled', 'expired']


def nearby(application, ride):
    if application.user_id == ride.passenger_id:
        return False
    if ride.quote.category == CATEGORY:
        if not application.accepts_intercity or application.vehicle.capacity < ride.passenger_count:
            return False
    elif ride.quote.category == COURIER:
        if not application.accepts_courier:
            return False
    elif application.vehicle.category != ride.quote.category:
        return False
    if not ride.quote.pricing.zone.enabled:
        return False
    lat1, lon1 = float(application.latitude), float(application.longitude)
    point = ride.quote.pickup
    lat2, lon2 = point['latitude'], point['longitude']
    a = math.sin(math.radians(lat2-lat1)/2)**2 + math.cos(math.radians(lat1))*math.cos(math.radians(lat2))*math.sin(math.radians(lon2-lon1)/2)**2
    return 6371 * 2 * math.asin(min(1, math.sqrt(a))) <= settings.DRIVER_MATCH_RADIUS_KM


def emit(ride, event_type, payload=None):
    from notifications.services.events import notify
    ride.sequence += 1
    ride.save(update_fields=['sequence', 'updated_at'])
    from core.identifiers import json_safe
    data = payload if payload is not None else {'status': ride.status}
    if ride.quote.category in {CATEGORY, COURIER}:
        data = {**data, 'service': ride.quote.category}
    event = RideEvent.objects.create(ride=ride, sequence=ride.sequence, event_type=event_type, payload=json_safe(data))
    users = {ride.passenger_id}
    if ride.assigned_driver_id:
        users.add(ride.assigned_driver.user_id)
    if event_type != 'driver.location':
        users.update(RideOffer.objects.filter(ride=ride, driver__isnull=False).values_list('driver__user_id', flat=True))
    for user_id in users:
        notify(user_id, event_type, str(ride.pk), event.payload, sequence=event.sequence, event_id=str(event.id))
    return event


@transaction.atomic
def make_offer(user, ride_id, cents, note='', decision='counteroffer', pickup_minutes=None):
    # All workflows lock ride -> application -> offer, in this order.
    transaction.guard(Ride, ride_id)
    ride = Ride.objects.get(pk=ride_id)
    app = driver_for(user, lock=True)
    eligible(app, online=True)
    if hasattr(app, 'active_assignment') or not nearby(app, ride):
        raise PermissionDenied('This request is outside your eligibility.')
    if ride.currency != 'USD':
        raise ValidationError('Only USD ride offers are supported.')
    if ride.status != 'searching' or not ride.expires_at or ride.expires_at <= timezone.now():
        raise ValidationError('Ride is no longer searching.', code='INVALID_RIDE_STATUS')
    from rides.services.booking import validate_offer
    amount = int(ride.offered_fare * 100) if decision in ['accept', 'decline'] else cents
    validate_offer(ride, amount, offer_type='driver')
    existing = RideOffer.objects.all().filter(ride=ride, driver=app).first()
    if existing:
        if existing.status == ('declined' if decision == 'decline' else 'pending') and existing.amount == Decimal(amount)/100 and existing.note == note and existing.expires_at > timezone.now():
            return existing
        raise ValidationError('A response already exists for this driver and request.')
    offer = RideOffer.objects.create(ride=ride, driver=app, vehicle=app.vehicle, amount=Decimal(amount)/100,
        note=note, offer_type='driver', status='declined' if decision == 'decline' else 'pending', pickup_minutes=pickup_minutes,
        expires_at=min(ride.expires_at, timezone.now() + timedelta(seconds=settings.OFFER_TTL)))
    emit(ride, 'offer.declined' if decision == 'decline' else 'offer.created', {'offer_id': offer.pk})
    return offer


@transaction.atomic
def update_offer(user, offer_id, changes):
    initial = RideOffer.objects.get(pk=offer_id)
    transaction.guard(Ride, initial.ride_id)
    ride = Ride.objects.get(pk=initial.ride_id)
    app = driver_for(user, lock=True)
    offer = RideOffer.objects.get(pk=offer_id)
    if offer.driver_id != app.pk:
        raise PermissionDenied()
    eligible(app, online=True)
    now = timezone.now()
    if ride.status != 'searching' or not ride.expires_at or ride.expires_at <= now or offer.status != 'pending' or not offer.expires_at or offer.expires_at <= now:
        raise ValidationError('Ride or offer is no longer available.')
    if hasattr(app, 'active_assignment') or offer.vehicle_id != app.active_vehicle_id or not nearby(app, ride):
        raise PermissionDenied('This request is outside your eligibility.')
    from rides.services.booking import validate_offer
    cents = changes.get('fare_cents', int(offer.amount * 100))
    validate_offer(ride, cents, offer_type='driver')
    offer.amount = Decimal(cents) / 100
    for field in ('note', 'pickup_minutes'):
        if field in changes:
            setattr(offer, field, changes[field])
    offer.save(update_fields=['amount', 'note', 'pickup_minutes', 'updated_at'])
    emit(ride, 'offer.updated', {'offer_id': offer.pk})
    return offer


@transaction.atomic
def select_offer(user, ride_id, offer_id, *, expected_fare=None):
    transaction.guard(Ride, ride_id)
    ride = Ride.objects.get(pk=ride_id)
    if ride.passenger_id != user.pk:
        raise PermissionDenied()
    initial = RideOffer.objects.filter(pk=offer_id, ride=ride).first()
    if not initial or not initial.driver_id:
        raise ValidationError('Valid driver offer required.')
    transaction.guard(DriverApplication, initial.driver_id)
    app = DriverApplication.objects.get(pk=initial.driver_id)
    offer = RideOffer.objects.all().get(pk=initial.pk)
    if expected_fare is not None and int(offer.amount * 100) != expected_fare:
        raise ValidationError('This fare has changed. Review the current offer before confirming.', code='OFFER_CHANGED')
    if offer.status == 'accepted' and ride.assigned_driver_id == app.pk and ride.status not in ['cancelled', 'expired']:
        return ride
    now = timezone.now()
    if ride.status != 'searching' or not ride.expires_at or ride.expires_at <= now or offer.status != 'pending' or not offer.expires_at or offer.expires_at <= now:
        raise ValidationError('Ride or offer is no longer available.', code='OFFER_EXPIRED' if offer.expires_at and offer.expires_at <= now else 'RIDE_ALREADY_ASSIGNED')
    from django.contrib.auth import get_user_model
    transaction.guard(get_user_model(), app.user_id)
    if Ride.objects.filter(passenger_id=app.user_id).exclude(status__in=TERMINAL).exists():
        raise ValidationError('Driver has a conflicting passenger request.', code='DRIVER_UNAVAILABLE')
    eligible(app, online=True)
    if offer.vehicle_id != app.vehicle.pk:
        raise ValidationError('The offered vehicle is no longer active.', code='VEHICLE_NOT_APPROVED')
    if not nearby(app, ride) or ActiveAssignment.objects.filter(driver=app).exists():
        raise ValidationError('Driver no longer available.', code='DRIVER_UNAVAILABLE')
    ActiveAssignment.objects.create(ride=ride, driver=app, passenger=user)
    ride.assigned_driver = app
    ride.assigned_vehicle = app.vehicle
    ride.agreed_fare = offer.amount
    ride.status = 'assigned'
    ride.accepted_at = now
    ride.save()
    offer.status, offer.accepted = 'accepted', True
    offer.save(update_fields=['status', 'accepted'])
    RideOffer.objects.filter(ride=ride, status='pending').exclude(pk=offer.pk).update(status='rejected')
    app.availability = 'assigned'
    app.save(update_fields=['availability'])
    ride.payment.amount = offer.amount
    ride.payment.save(update_fields=['amount'])
    emit(ride, 'driver.assigned', {'status': ride.status, 'offer_id': offer.pk})
    return ride


@transaction.atomic
def withdraw(user, offer_id):
    initial = RideOffer.objects.get(pk=offer_id)
    transaction.guard(Ride, initial.ride_id)
    ride = Ride.objects.get(pk=initial.ride_id)
    app = driver_for(user, lock=True)
    offer = RideOffer.objects.all().get(pk=offer_id)
    if offer.driver_id != app.pk:
        raise PermissionDenied()
    if offer.status == 'withdrawn':
        return offer
    if offer.status != 'pending' or ride.status != 'searching':
        raise ValidationError('Offer can no longer be withdrawn.')
    offer.status = 'withdrawn'
    offer.save(update_fields=['status'])
    emit(ride, 'offer.withdrawn', {'offer_id': offer.pk})
    return offer


@transaction.atomic
def transition(user, ride_id, target, reason='', administrative=False, *, delivery_proven=False):
    transaction.guard(Ride, ride_id)
    ride = Ride.objects.get(pk=ride_id)
    app = None
    if ride.assigned_driver_id:
        transaction.guard(DriverApplication, ride.assigned_driver_id)
        app = DriverApplication.objects.get(pk=ride.assigned_driver_id)
    is_driver = app is not None and app.user_id == user.pk
    if administrative:
        if not user.has_perm('drivers.operate_platform'):
            raise PermissionDenied()
    elif target == 'cancelled':
        if ride.passenger_id != user.pk and not is_driver:
            raise PermissionDenied()
    elif not is_driver:
        raise PermissionDenied('Only the assigned driver can progress a trip.')
    if ride.status == target:
        return ride
    if target == 'cancelled':
        if ride.status not in ['scheduled', 'searching', 'assigned', 'arriving', 'arrived']:
            raise ValidationError('Ride cannot be cancelled in this state.')
    else:
        eligible(app)
        transitions = {'assigned': 'arriving', 'arriving': 'arrived', 'arrived': 'inProgress', 'inProgress': 'completed'}
        if transitions.get(ride.status) != target:
            raise ValidationError('Invalid ride state transition.', code='INVALID_RIDE_STATUS')
    if target == 'completed' and ride.quote.category == COURIER and not delivery_proven:
        raise ValidationError('Enter the recipient confirmation code to complete this delivery.')
    if target == 'inProgress' and ride.departure_at and timezone.now() < ride.departure_at:
        raise ValidationError('Wait until the scheduled departure to start this trip.')
    ride.status = target
    now = timezone.now()
    timestamp = {'arrived': 'arrived_at', 'inProgress': 'started_at', 'completed': 'completed_at', 'cancelled': 'cancelled_at'}.get(target)
    if timestamp:
        setattr(ride, timestamp, now)
    if target == 'cancelled':
        ride.cancellation_reason = reason
        ride.payment.status = 'cancelled'
        ride.payment.save(update_fields=['status'])
    ride.save()
    if app:
        app.availability = {'arriving': 'arriving', 'arrived': 'arriving', 'inProgress': 'onTrip'}.get(target, 'offline')
        app.save(update_fields=['availability'])
    if target in TERMINAL:
        ActiveAssignment.objects.filter(ride=ride).delete()
        RideOffer.objects.filter(ride=ride, status='pending').update(status='rejected')
    emit(ride, 'ride.' + target)
    if administrative:
        from accounts.models import AuditEvent
        AuditEvent.objects.create(actor=user, action='ride.cancelled', target=str(ride.pk), summary={'reason': reason})
    return ride


@transaction.atomic
def publish_location(app):
    assignment = ActiveAssignment.objects.filter(driver=app).first()
    if not assignment:
        return
    transaction.guard(Ride, assignment.ride_id)
    ride = Ride.objects.get(pk=assignment.ride_id)
    if ride.status in TERMINAL:
        return
    LocationUpdate.objects.create(ride=ride, latitude=app.latitude, longitude=app.longitude)
    emit(ride, 'driver.location', {'latitude': str(app.latitude), 'longitude': str(app.longitude), 'at': app.last_seen.isoformat()})
