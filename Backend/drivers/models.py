from core.identifiers import StorageJSONEncoder
import uuid
from django.conf import settings
from django.db import models
from django_mongodb_backend.managers import MongoManager
from django.core.files.storage import FileSystemStorage, Storage, storages
from django.utils.deconstruct import deconstructible
from django.core.validators import MinValueValidator, MaxValueValidator


@deconstructible
class PrivateStorage(Storage):
    """Stable migration identity; retrieval always uses authorized API views."""
    @property
    def backend(self):
        if settings.STORAGES['private']['BACKEND'] == 'django.core.files.storage.FileSystemStorage':
            return FileSystemStorage(location=settings.PRIVATE_MEDIA_ROOT)
        return storages['private']

    def _open(self, name, mode='rb'):
        return self.backend.open(name, mode)

    def _save(self, name, content):
        return self.backend.save(name, content)

    def exists(self, name):
        return self.backend.exists(name)

    def size(self, name):
        return self.backend.size(name)

    def delete(self, name):
        return self.backend.delete(name)

    def path(self, name):
        return self.backend.path(name)

    def url(self, name):
        raise ValueError('Private documents require authenticated retrieval.')


def document_key(instance, filename):
    return f'private-images/{uuid.uuid4().hex}'


class DriverApplication(models.Model):
    objects = MongoManager()
    location = models.JSONField(encoder=StorageJSONEncoder, null=True, default=None, blank=True)
    active_vehicle = models.ForeignKey('Vehicle', null=True, blank=True, on_delete=models.PROTECT, related_name='+')
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='driver_application')
    status = models.CharField(max_length=20, default='draft', choices=[(s, s) for s in ['draft', 'submitted', 'underReview', 'approved', 'rejected', 'suspended']])
    legal_name = models.CharField(max_length=200, blank=True)
    licence_number = models.CharField(max_length=80, blank=True)
    licence_class = models.CharField(max_length=30, blank=True)
    licence_expires = models.DateField(null=True, blank=True)
    experience_years = models.PositiveSmallIntegerField(default=0)
    rejection_reason = models.CharField(max_length=500, blank=True)
    resubmission_allowed = models.BooleanField(default=True)
    submitted_at = models.DateTimeField(null=True)
    reviewed_at = models.DateTimeField(null=True)
    reviewed_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.PROTECT, related_name='driver_reviews')
    availability = models.CharField(max_length=20, default='offline', db_index=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, validators=[MinValueValidator(-90), MaxValueValidator(90)])
    longitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, validators=[MinValueValidator(-180), MaxValueValidator(180)])
    last_seen = models.DateTimeField(null=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        fields = kwargs.get('update_fields')
        if fields is None or {'latitude', 'longitude'}.intersection(fields):
            self.location = None if self.latitude is None or self.longitude is None else {
                'type': 'Point', 'coordinates': [float(self.longitude), float(self.latitude)]}
            if fields is not None:
                kwargs['update_fields'] = [*fields, 'location']
        return super().save(*args, **kwargs)

    @property
    def vehicle(self):
        vehicle = self.active_vehicle if self.active_vehicle_id else None
        if vehicle is None or vehicle.archived:
            raise AttributeError('No active vehicle.')
        return vehicle

    class Meta:
        indexes = [models.Index(fields=['status', 'licence_expires'], name='driver_licence_expiry')]
        permissions = [('review_driver', 'Review driver applications'), ('operate_platform', 'Operate rides and safety')]


class Vehicle(models.Model):
    application = models.ForeignKey(DriverApplication, on_delete=models.PROTECT, related_name='vehicles')
    archived = models.BooleanField(default=False)
    make = models.CharField(max_length=60)
    model = models.CharField(max_length=60)
    year = models.PositiveSmallIntegerField(validators=[MinValueValidator(1950), MaxValueValidator(2100)])
    colour = models.CharField(max_length=40)
    registration = models.CharField(max_length=30, unique=True)
    capacity = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(20)])
    category = models.CharField(max_length=30, choices=[(s, s) for s in ['Standard', 'Comfort', 'XL']])
    approved = models.BooleanField(default=False)


class DocumentRequirement(models.Model):
    code = models.SlugField(primary_key=True)
    label = models.CharField(max_length=100)
    scope = models.CharField(max_length=10, default='driver', choices=[('driver', 'Driver'), ('vehicle', 'Vehicle')])
    required = models.BooleanField(default=True)
    expiry_required = models.BooleanField(default=True)
    enabled = models.BooleanField(default=True)


class DriverDocument(models.Model):
    application = models.ForeignKey(DriverApplication, on_delete=models.PROTECT, related_name='documents')
    requirement = models.ForeignKey(DocumentRequirement, on_delete=models.PROTECT)
    file = models.FileField(storage=PrivateStorage(), upload_to=document_key)
    content_type = models.CharField(max_length=50)
    expires_on = models.DateField(null=True, blank=True)
    approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=['expires_on'], name='driver_document_expiry')]
        constraints = [models.UniqueConstraint(fields=['application', 'requirement'], name='one_driver_document_type')]


class VehicleDocument(models.Model):
    vehicle = models.ForeignKey(Vehicle, on_delete=models.PROTECT, related_name='documents')
    requirement = models.ForeignKey(DocumentRequirement, on_delete=models.PROTECT)
    file = models.FileField(storage=PrivateStorage(), upload_to=document_key)
    content_type = models.CharField(max_length=50)
    expires_on = models.DateField(null=True, blank=True)
    approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=['expires_on'], name='vehicle_document_expiry')]
        constraints = [models.UniqueConstraint(fields=['vehicle', 'requirement'], name='one_vehicle_document_type')]
