from core import transactions as transaction
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError
from accounts.models import AuditEvent
from drivers.models import DriverApplication, Vehicle
from drivers.services.eligibility import check_documents


@transaction.atomic
def save_draft(user, data, allow_revision=False):
    from django.contrib.auth import get_user_model
    transaction.guard(get_user_model(), user.pk)
    application, _ = DriverApplication.objects.get_or_create(user=user)
    transaction.guard(DriverApplication, application.pk)
    application = DriverApplication.objects.get(pk=application.pk)
    if application.status == 'approved' and allow_revision:
        if hasattr(application, 'active_assignment'):
            raise ValidationError('Finish the assigned trip before revising verification details.')
        application.status = 'draft'
        application.availability = 'offline'
        AuditEvent.objects.create(actor=user, action='driver.revisionRequested', target=str(application.pk), summary={'fields': sorted(data)})
    if application.status not in ['draft', 'rejected'] or (application.status == 'rejected' and not application.resubmission_allowed):
        raise ValidationError('This application cannot be edited.')
    vehicle = data.pop('vehicle', None)
    if vehicle:
        if Vehicle.objects.filter(registration=vehicle['registration']).exclude(application=application).exists():
            raise ValidationError({'vehicle': 'Registration already belongs to another application.'})
        current = application.vehicles.filter(archived=False).order_by('pk').first()
        if current:
            for key, value in vehicle.items():
                setattr(current, key, value)
            current.approved = False
            current.save()
        else:
            current = Vehicle.objects.create(application=application, **vehicle)
        application.active_vehicle = current
    for key, value in data.items():
        setattr(application, key, value)
    application.status = 'draft'
    application.save()
    return application


@transaction.atomic
def submit(user):
    from drivers.services.eligibility import driver_for
    application = driver_for(user, lock=True)
    if application.status == 'submitted':
        return application
    if application.status != 'draft':
        raise ValidationError('Only a draft application can be submitted.')
    if not all([application.legal_name, application.licence_number, application.licence_class, application.licence_expires, hasattr(application, 'vehicle')]):
        raise ValidationError('Complete personal, licence and vehicle details first.')
    if application.licence_expires < timezone.localdate():
        raise ValidationError('Licence expired.')
    check_documents(application, approved=False)
    application.status = 'submitted'
    application.submitted_at = timezone.now()
    application.save(update_fields=['status', 'submitted_at', 'updated_at'])
    return application


@transaction.atomic
def review(actor, application_id, decision, reason='', request_id=''):
    if not actor.has_perm('drivers.review_driver'):
        raise PermissionDenied('Driver verification permission required.')
    from django.shortcuts import get_object_or_404
    transaction.guard(DriverApplication, application_id)
    application = get_object_or_404(DriverApplication, pk=application_id)
    if actor.pk == application.user_id:
        raise PermissionDenied('Self review is prohibited.')
    if decision not in ['underReview', 'approved', 'rejected', 'suspended']:
        raise ValidationError('Unsupported review decision.')
    allowed = {'submitted': ['underReview', 'approved', 'rejected'], 'underReview': ['approved', 'rejected'], 'approved': ['suspended'], 'suspended': ['approved', 'rejected']}
    if decision not in allowed.get(application.status, []):
        raise ValidationError('Invalid review transition.')
    if decision in ['rejected', 'suspended'] and not reason:
        raise ValidationError('A reason is required.')
    if decision == 'approved':
        if not application.licence_expires or application.licence_expires < timezone.localdate() or not hasattr(application, 'vehicle'):
            raise ValidationError('Current licence and vehicle required.')
        check_documents(application, approved=False)
        application.documents.update(approved=True)
        from core.services.administration import vehicle_review
        vehicle_review(actor, application.vehicle.pk, True, request_id=request_id)
        application.vehicle.approved = True
        application.vehicle.save(update_fields=['approved'])
    application.status = decision
    application.rejection_reason = reason
    application.reviewed_by = actor
    application.reviewed_at = timezone.now()
    if decision != 'approved':
        application.availability = 'offline'
    application.save()
    AuditEvent.objects.create(actor=actor, action='driver.' + decision, target=str(application.pk), summary={'reason': reason}, request_id=request_id)
    from notifications.services.events import notify
    notify(application.user_id, 'verification.updated', str(application.pk), {'status': decision})
    return application
