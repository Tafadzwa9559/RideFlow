import asyncio
from channels.testing import WebsocketCommunicator
from django.test import TransactionTestCase
from rest_framework_simplejwt.tokens import RefreshToken
from rideflow.asgi import application
from rides.services.lifecycle import make_offer, select_offer
from notifications.tasks import deliver_outbox
from .helpers import RideFixtures


class WebsocketTests(RideFixtures, TransactionTestCase):
    def setUp(self):
        self.setup_ride()

    def test_authentication_delivery_reconnect_and_room_authorization(self):
        offer = make_offer(self.driver_user, self.ride.pk, 600)
        select_offer(self.passenger, self.ride.pk, offer.pk)
        tokens = {u.pk: str(RefreshToken.for_user(u).access_token) for u in [self.passenger, self.other_user]}

        async def scenario():
            path = f'/ws/v1/passenger/rides/{self.ride.pk}/'
            headers = [(b'origin', b'http://localhost')]
            unauthorized = WebsocketCommunicator(application, path, headers=headers)
            self.assertTrue((await unauthorized.connect(timeout=10))[0])
            await unauthorized.send_json_to({'token': tokens[self.other_user.pk]})
            self.assertEqual((await unauthorized.receive_output(timeout=10))['code'], 4403)
            await unauthorized.disconnect()
            bad = WebsocketCommunicator(application, path, headers=headers)
            await bad.connect(timeout=10)
            await bad.send_json_to({'token': 'bad'})
            self.assertEqual((await bad.receive_output(timeout=10))['code'], 4401)
            await bad.disconnect()
            client = WebsocketCommunicator(application, path, headers=headers)
            await client.connect(timeout=10)
            await client.send_json_to({'token': tokens[self.passenger.pk]})
            self.assertEqual((await client.receive_json_from(timeout=10))['type'], 'connection.ready')
            from channels.db import database_sync_to_async
            await database_sync_to_async(deliver_outbox)()
            received = []
            while not await client.receive_nothing(timeout=.05):
                received.append(await client.receive_json_from(timeout=10))
            self.assertIn('driver.assigned', [e['type'] for e in received])
            self.assertEqual(len({e['event_id'] for e in received}), len(received))
            await client.disconnect()
            again = WebsocketCommunicator(application, path, headers=headers)
            await again.connect(timeout=10)
            await again.send_json_to({'token': tokens[self.passenger.pk]})
            self.assertEqual((await again.receive_json_from(timeout=10))['type'], 'connection.ready')
            await again.disconnect()
        asyncio.run(scenario())

    def test_disallowed_origin(self):
        async def scenario():
            client = WebsocketCommunicator(application, '/ws/v1/notifications/', headers=[(b'origin', b'https://unrelated.example')])
            self.assertFalse((await client.connect(timeout=10))[0])
            await client.disconnect()
        asyncio.run(scenario())
