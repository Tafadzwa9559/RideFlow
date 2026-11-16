from asgiref.sync import async_to_sync
from celery import shared_task
from channels.layers import get_channel_layer
from django.utils import timezone
from notifications.models import Notification


@shared_task(autoretry_for=(ConnectionError, OSError), retry_backoff=True, max_retries=5)
def deliver_outbox():
    # At-least-once delivery. Clients deduplicate event_id and recover through REST.
    layer = get_channel_layer()
    for item in Notification.objects.filter(delivered_at__isnull=True).order_by('created_at')[:500]:
        async_to_sync(layer.group_send)(f'user.{item.user_id}', {'type': 'trivia.event', 'envelope': item.envelope})
        if item.envelope['type'] != 'driver.location':
            send_push.delay(str(item.pk))
        Notification.objects.filter(pk=item.pk, delivered_at__isnull=True).update(delivered_at=timezone.now())


@shared_task(autoretry_for=(ConnectionError, OSError), retry_backoff=True, max_retries=5)
def send_push(notification_id):
    from django.conf import settings
    from django.utils.module_loading import import_string
    from notifications.models import DeviceToken
    if not settings.PUSH_PROVIDER:
        return
    item = Notification.objects.get(pk=notification_id)
    from accounts.models import UserPreferences
    if UserPreferences.objects.filter(user=item.user, push_notifications=False).exists():
        return
    adapter = import_string(settings.PUSH_PROVIDER)()
    for device in DeviceToken.objects.filter(user=item.user):
        adapter.send(device.token, device.platform, str(item.event_id), item.envelope['type'])
