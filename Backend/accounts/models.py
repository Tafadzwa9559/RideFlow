from core.identifiers import StorageJSONEncoder
import uuid
from django.conf import settings
from django.db import models
from drivers.models import PrivateStorage, document_key


class PhoneIdentity(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='phone_identity')
    phone = models.CharField(max_length=16, unique=True)
    verified_at = models.DateTimeField(null=True)
    session_version = models.PositiveIntegerField(default=0)


class EmailIdentity(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='email_identity')
    verified_at = models.DateTimeField(null=True)
    session_version = models.PositiveIntegerField(default=0)


class PhoneChallenge(models.Model):
    phone = models.CharField(max_length=16, unique=True)
    digest = models.CharField(max_length=128)
    expires_at = models.DateTimeField()
    sent_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed = models.BooleanField(default=False)


    class Meta:
        indexes = [models.Index(fields=['expires_at'], name='otp_expiry_cleanup')]


class AuditEvent(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=80)
    target = models.CharField(max_length=100)
    summary = models.JSONField(encoder=StorageJSONEncoder, default=dict)
    request_id = models.CharField(max_length=64, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)


class UserPreferences(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='preferences')
    language = models.CharField(max_length=8, default='en', choices=[('en', 'English'), ('sn', 'Shona'), ('nd', 'Ndebele')])
    push_notifications = models.BooleanField(default=True)
    marketing_notifications = models.BooleanField(default=False)
    allow_trip_sharing = models.BooleanField(default=True)
    avatar = models.FileField(storage=PrivateStorage(), upload_to=document_key, blank=True)
