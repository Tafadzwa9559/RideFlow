import uuid
from django.utils import timezone
from notifications.models import Notification


def notify(user_id, event_type, resource_id, payload, sequence=0, event_id=None):
    event_id = event_id or str(uuid.uuid4())
    return Notification.objects.get_or_create(user_id=user_id, event_id=event_id, defaults={'envelope': {
        'schema_version': 1, 'event_id': event_id, 'type': event_type, 'resource_id': resource_id,
        'timestamp': timezone.now().isoformat(), 'sequence': sequence, 'payload': payload}})[0]
