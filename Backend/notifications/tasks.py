from asgiref.sync import async_to_sync
from celery import shared_task
from django.db import OperationalError, connection
from kombu.exceptions import OperationalError as BrokerOperationalError
from pymongo.errors import AutoReconnect, ExecutionTimeout
from redis.exceptions import ConnectionError as RedisConnectionError, TimeoutError as RedisTimeoutError
from channels.exceptions import ChannelFull
from notifications.services.push import TransientPushError
from channels.layers import get_channel_layer
from django.utils import timezone
from notifications.models import Notification


@shared_task(autoretry_for=(ConnectionError, OSError, RedisConnectionError, RedisTimeoutError,
                           BrokerOperationalError, OperationalError, AutoReconnect, ExecutionTimeout,
                           ChannelFull, TransientPushError),
             retry_backoff=True, retry_backoff_max=300, retry_jitter=True, max_retries=5)
def deliver_outbox():
    # At-least-once delivery. Clients deduplicate event_id and recover through REST.
    layer = get_channel_layer()
    for item in Notification.objects.filter(delivered_at__isnull=True).order_by('created_at')[:500]:
        async_to_sync(layer.group_send)(f'user.{item.user_id}', {'type': 'trivia.event', 'envelope': item.envelope})
        if item.envelope['type'] != 'driver.location':
            send_push.delay(str(item.pk))
        Notification.objects.filter(pk=item.pk, delivered_at__isnull=True).update(delivered_at=timezone.now())


@shared_task(autoretry_for=(ConnectionError, OSError, RedisConnectionError, RedisTimeoutError,
                           BrokerOperationalError, OperationalError, AutoReconnect, ExecutionTimeout,
                           ChannelFull, TransientPushError),
             retry_backoff=True, retry_backoff_max=300, retry_jitter=True, max_retries=5)
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
    for device in DeviceToken.objects.filter(user=item.user).order_by('pk'):
        import hashlib
        key = hashlib.sha256(device.token.encode()).hexdigest()
        if key in item.push_receipts:
            continue
        adapter.send(device.token, device.platform, str(item.event_id), item.envelope['type'])
        # Independent nested writes preserve receipts from overlapping retries.
        # A crash between provider acceptance and this write still needs provider
        # event-id deduplication; this is not proof of arrival on a handset.
        result = connection.get_collection(Notification._meta.db_table).update_one(
            {Notification._meta.pk.column: Notification._meta.pk.get_db_prep_value(item.pk, connection)}, {'$set': {f'push_receipts.{key}': timezone.now().isoformat()}},
            session=connection.session)
        if result.matched_count != 1:
            raise Notification.DoesNotExist('Notification removed during push dispatch.')
        item.push_receipts[key] = True
