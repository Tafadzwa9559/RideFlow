from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import F
from django.shortcuts import get_object_or_404
from rest_framework.exceptions import PermissionDenied, ValidationError
from accounts.models import AuditEvent, PhoneIdentity
from drivers.models import DriverApplication, Vehicle, DocumentRequirement
from django.utils import timezone


def audit(actor, action, obj, summary, request_id=''):
    return AuditEvent.objects.create(actor=actor, action=action, target=str(obj.pk), summary=summary, request_id=request_id)


@transaction.atomic
def account_status(actor, pk, active, request_id=''):
    if not actor.is_staff or not actor.has_perm('auth.change_user'):
        raise PermissionDenied()
    user = get_object_or_404(get_user_model().objects.select_for_update(), pk=pk, is_staff=False, is_superuser=False)
    user.is_active = active
    user.save(update_fields=['is_active'])
    PhoneIdentity.objects.filter(user=user).update(session_version=F('session_version')+1)
    DriverApplication.objects.filter(user=user).update(availability='offline')
    audit(actor, 'account.status', user, {'active': active}, request_id)
    return user


@transaction.atomic
def request_changes(actor, pk, reason, request_id=''):
    if not actor.is_staff or not actor.has_perm('drivers.review_driver'):
        raise PermissionDenied()
    app = get_object_or_404(DriverApplication.objects.select_for_update(), pk=pk)
    if app.user_id == actor.pk:
        raise PermissionDenied('Self review is prohibited.')
    if app.status not in ['submitted', 'underReview']:
        raise ValidationError('Only pending applications may be returned for changes.', code='INVALID_RIDE_STATUS')
    app.status = 'draft'
    app.rejection_reason = reason
    app.reviewed_by = actor
    app.reviewed_at = timezone.now()
    app.save()
    audit(actor, 'driver.changesRequested', app, {'reason': reason}, request_id)
    return app


@transaction.atomic
def vehicle_review(actor, pk, approved, reason='', request_id=''):
    if not actor.is_staff or not actor.has_perm('drivers.review_driver'):
        raise PermissionDenied()
    initial = get_object_or_404(Vehicle, pk=pk)
    app = DriverApplication.objects.select_for_update().get(pk=initial.application_id)
    vehicle = Vehicle.objects.select_for_update().get(pk=pk)
    if app.user_id == actor.pk or vehicle.archived:
        raise PermissionDenied('Self review or archived vehicle review is prohibited.')
    if approved:
        for req in DocumentRequirement.objects.filter(enabled=True, required=True, scope='vehicle'):
            doc = vehicle.documents.filter(requirement=req).first()
            if not doc or (req.expiry_required and not doc.expires_on) or (doc.expires_on and doc.expires_on < timezone.localdate()):
                raise ValidationError('Current required vehicle documents are missing.')
        vehicle.documents.update(approved=True)
    vehicle.approved = approved
    vehicle.save(update_fields=['approved'])
    if not approved:
        app.availability = 'offline'
        app.save(update_fields=['availability'])
    audit(actor, 'vehicle.reviewed', vehicle, {'approved': approved, 'reason': reason}, request_id)
    return vehicle
