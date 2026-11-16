from core.identifiers import StorageJSONEncoder
import uuid
from django.conf import settings
from django.db import models


class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    event_id = models.UUIDField(default=uuid.uuid4)
    envelope = models.JSONField(encoder=StorageJSONEncoder, )
    delivered_at = models.DateTimeField(null=True, db_index=True)
    read_at = models.DateTimeField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['user', 'event_id'], name='one_user_event_notification')]
        indexes = [models.Index(fields=['user', 'created_at'])]


class DeviceToken(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(max_length=10, choices=[('android', 'Android'), ('ios', 'iOS')])
    updated_at = models.DateTimeField(auto_now=True)
