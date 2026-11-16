"""Maintenance alerts contain metadata only; never document contents or URLs."""
import uuid
from datetime import timedelta
from celery import shared_task
from django.db import OperationalError, IntegrityError
from django.utils import timezone
from pymongo.errors import AutoReconnect, ConnectionFailure
from drivers.models import DriverApplication, DriverDocument, VehicleDocument
from notifications.services.events import notify


@shared_task(autoretry_for=(OperationalError, IntegrityError, AutoReconnect, ConnectionFailure),
             retry_backoff=True, retry_jitter=True, max_retries=5)
def document_expiry_alerts():
    today = timezone.localdate()
    horizon = today + timedelta(days=30)
    sent = 0

    def alert(user_id, kind, key, expires_on):
        nonlocal sent
        # One event per resource/expiry/milestone; retries and repeated beat ticks dedupe.
        remaining = (expires_on - today).days
        milestone = 'expired' if remaining < 0 else '7d' if remaining <= 7 else '30d'
        event_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f'trivia:expiry:{kind}:{key}:{expires_on}:{milestone}'))
        notify(user_id, 'driver.document.expiry', str(key), {
            'resource_type': kind, 'expires_on': expires_on.isoformat(), 'milestone': milestone,
        }, event_id=event_id)
        sent += 1

    # The indexed date window includes recently expired records as recovery after outages.
    window = {'expires_on__gte': today-timedelta(days=30), 'expires_on__lte': horizon, 'approved': True}
    for app in DriverApplication.objects.filter(status='approved', user__is_active=True,
            licence_expires__gte=today-timedelta(days=30), licence_expires__lte=horizon).iterator(chunk_size=200):
        alert(app.user_id, 'licence', app.pk, app.licence_expires)
    for doc in DriverDocument.objects.filter(**window).select_related('application__user').iterator(chunk_size=200):
        if doc.application.status == 'approved' and doc.application.user.is_active:
            alert(doc.application.user_id, 'driver_document', doc.pk, doc.expires_on)
    for doc in VehicleDocument.objects.filter(**window).select_related('vehicle__application__user').iterator(chunk_size=200):
        app = doc.vehicle.application
        if app.status == 'approved' and app.user.is_active and not doc.vehicle.archived:
            alert(app.user_id, 'vehicle_document', doc.pk, doc.expires_on)
    return {'examined_eligible_resources': sent}
