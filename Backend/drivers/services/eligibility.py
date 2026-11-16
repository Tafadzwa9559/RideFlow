from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError
from drivers.models import DocumentRequirement, DriverApplication


def check_documents(application, approved=True):
    today = timezone.localdate()
    for req in DocumentRequirement.objects.filter(enabled=True, required=True, scope='driver'):
        doc = application.documents.filter(requirement=req).first()
        if not doc or (approved and not doc.approved) or (req.expiry_required and not doc.expires_on) or (doc.expires_on and doc.expires_on < today):
            raise ValidationError('Required verification documents are missing, unapproved or expired.')


def eligible(application, *, online=False):
    if application.status != 'approved' or not application.user.is_active:
        raise PermissionDenied('An approved active driver account is required.', code='DRIVER_NOT_APPROVED')
    if not application.licence_expires or application.licence_expires < timezone.localdate():
        raise PermissionDenied('A current driving licence is required.')
    if not hasattr(application, 'vehicle') or not application.vehicle.approved:
        raise PermissionDenied('An approved vehicle is required.', code='VEHICLE_NOT_APPROVED')
    check_documents(application)
    today = timezone.localdate()
    for req in DocumentRequirement.objects.filter(enabled=True, required=True, scope='vehicle'):
        doc = application.vehicle.documents.filter(requirement=req).first()
        if not doc or not doc.approved or (req.expiry_required and not doc.expires_on) or (doc.expires_on and doc.expires_on < today):
            raise PermissionDenied('Current approved vehicle documents are required.', code='VEHICLE_NOT_APPROVED')
    if online and (application.availability != 'online' or not application.last_seen or application.last_seen < timezone.now() - timedelta(seconds=settings.DRIVER_LOCATION_TTL) or application.latitude is None):
        raise PermissionDenied('Go online and publish a fresh location first.', code='DRIVER_UNAVAILABLE')
    return application


def driver_for(user, lock=False):
    qs = DriverApplication.objects.select_related('user', 'active_vehicle').prefetch_related('vehicles')
    if lock:
        # Lock only the application: MySQL cannot lock nullable outer joins safely.
        qs = DriverApplication.objects.select_for_update()
    application = qs.filter(user=user).first()
    if not application:
        raise PermissionDenied('Driver registration is required.')
    return application
