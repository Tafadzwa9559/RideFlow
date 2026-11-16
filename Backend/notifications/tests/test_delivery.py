from unittest.mock import patch
from celery.exceptions import Retry
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from redis.exceptions import ConnectionError as RedisConnectionError
from notifications.models import Notification, DeviceToken
from notifications.services.events import notify
from notifications.services.push import TransientPushError
from notifications.tasks import deliver_outbox, send_push


class RecordingPush:
    calls = []
    fail_token = None

    def send(self, token, platform, event_id, event_type):
        self.calls.append((token, event_id))
        if token == self.fail_token:
            raise TransientPushError('Provider temporarily unavailable.')


class NotificationDeliveryTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='delivery-owner')
        self.item = notify(self.user.pk, 'ride.assigned', 'test-resource', {'status': 'assigned'})
        RecordingPush.calls = []
        RecordingPush.fail_token = None

    def test_redis_failure_retries_without_marking_outbox_delivered(self):
        class BrokenLayer:
            async def group_send(self, *args):
                raise RedisConnectionError('unavailable')
        with patch('notifications.tasks.get_channel_layer', return_value=BrokenLayer()), \
                patch.object(deliver_outbox, 'retry', side_effect=Retry()) as retry, \
                patch('notifications.tasks.send_push.delay') as push:
            with self.assertRaises(Retry):
                deliver_outbox.run()
            retry.assert_called_once()
            self.assertLessEqual(retry.call_args.kwargs['countdown'], 300)
            push.assert_not_called()
        self.item.refresh_from_db()
        self.assertIsNone(self.item.delivered_at)
        class HealthyLayer:
            async def group_send(self, *args):
                return None
        with patch('notifications.tasks.get_channel_layer', return_value=HealthyLayer()), \
                patch('notifications.tasks.send_push.delay') as push:
            deliver_outbox.run()
            deliver_outbox.run()
            push.assert_called_once_with(str(self.item.pk))
        self.item.refresh_from_db()
        self.assertIsNotNone(self.item.delivered_at)

    @override_settings(PUSH_PROVIDER='notifications.tests.test_delivery.RecordingPush')
    def test_partial_push_success_is_not_resent_on_sequential_retry(self):
        DeviceToken.objects.create(user=self.user, token='first-device', platform='android')
        DeviceToken.objects.create(user=self.user, token='second-device', platform='ios')
        RecordingPush.fail_token = 'second-device'
        with patch.object(send_push, 'retry', side_effect=Retry()):
            with self.assertRaises(Retry):
                send_push.run(str(self.item.pk))
        self.item.refresh_from_db()
        self.assertEqual(len(self.item.push_receipts), 1)
        self.assertNotIn('first-device', str(self.item.push_receipts))
        RecordingPush.fail_token = None
        send_push.run(str(self.item.pk))
        send_push.run(str(self.item.pk))
        self.assertEqual([token for token, event in RecordingPush.calls].count('first-device'), 1)
        self.assertEqual([token for token, event in RecordingPush.calls].count('second-device'), 2)
        self.assertEqual(set(event for token, event in RecordingPush.calls), {str(self.item.event_id)})
        self.item.refresh_from_db()
        self.assertEqual(len(self.item.push_receipts), 2)

    @override_settings(PUSH_PROVIDER='')
    def test_unconfigured_push_makes_no_delivery_claim(self):
        DeviceToken.objects.create(user=self.user, token='device', platform='android')
        send_push.run(str(self.item.pk))
        self.item.refresh_from_db()
        self.assertEqual(self.item.push_receipts, {})

    @override_settings(PUSH_PROVIDER='notifications.tests.test_delivery.RecordingPush')
    def test_push_opt_out_is_honored(self):
        from accounts.models import UserPreferences
        UserPreferences.objects.create(user=self.user, push_notifications=False)
        DeviceToken.objects.create(user=self.user, token='device', platform='android')
        send_push.run(str(self.item.pk))
        self.assertEqual(RecordingPush.calls, [])
