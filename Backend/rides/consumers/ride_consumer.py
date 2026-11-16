import asyncio
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.utils import timezone
from django.db.models import Q
from rest_framework_simplejwt.exceptions import TokenError, InvalidToken
from rest_framework.exceptions import AuthenticationFailed, APIException
from rest_framework_simplejwt.tokens import AccessToken
from accounts.authentication import SessionJWTAuthentication
from drivers.services.eligibility import driver_for, eligible
from rides.models import Ride


@database_sync_to_async
def authenticate(raw):
    try:
        token = AccessToken(raw)
        user = SessionJWTAuthentication().get_user(token)
        return user, int(token['exp'])
    except (TokenError, InvalidToken, AuthenticationFailed, ValueError, KeyError):
        return None, 0


@database_sync_to_async
def authorized(user, ride_id, driver_requests=False):
    try:
        if driver_requests:
            eligible(driver_for(user), online=True)
            return True
        return Ride.objects.filter(pk=ride_id).filter(Q(passenger=user) | Q(assigned_driver__user=user)).exists() if ride_id else user.is_active
    except APIException:
        return False


class RideConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        self.user = None
        self.joined = False
        self.ride_id = self.scope['url_route']['kwargs'].get('ride_id')
        self.driver_requests = self.scope['path'].endswith('/driver/requests/')
        # Browser clients authenticate in the first frame; native clients may use Authorization.
        # Never put bearer credentials in URLs or access logs.
        self.raw_token = None
        for key, value in self.scope.get('headers', []):
            if key == b'authorization' and value.startswith(b'Bearer '):
                self.raw_token = value[7:].decode()
        await self.accept()
        self.timeout_task = asyncio.create_task(self.auth_timeout())
        if self.raw_token:
            await self.login(self.raw_token)

    async def auth_timeout(self):
        await asyncio.sleep(5)
        if self.user is None:
            await self.close(code=4401)

    async def login(self, raw):
        user, expiry = await authenticate(raw)
        if not user or not await authorized(user, self.ride_id, self.driver_requests):
            await self.close(code=4403 if user else 4401)
            return
        self.user, self.expiry, self.raw_token = user, expiry, raw
        self.group = f'user.{user.pk}'
        await self.channel_layer.group_add(self.group, self.channel_name)
        self.joined = True
        self.expiry_task = asyncio.create_task(self.expire(expiry))
        await self.send_json({'type': 'connection.ready', 'schema_version': 1})

    async def expire(self, expiry):
        await asyncio.sleep(max(0, expiry - timezone.now().timestamp()))
        await self.close(code=4401)

    async def receive_json(self, content, **kwargs):
        if self.user is None:
            token = content.get('token') if isinstance(content, dict) else None
            if not isinstance(token, str) or len(token) > 4096:
                await self.close(code=4401)
                return
            await self.login(token)
        elif content == {'type': 'ping'}:
            user, _ = await authenticate(self.raw_token)
            if not user:
                await self.close(code=4401)
            else:
                await self.send_json({'type': 'pong'})
        else:
            await self.close(code=4400)

    async def trivia_event(self, event):
        user, _ = await authenticate(self.raw_token)
        if not user or not await authorized(user, self.ride_id, self.driver_requests):
            await self.close(code=4403)
            return
        envelope = event['envelope']
        if self.ride_id and envelope['resource_id'] != str(self.ride_id):
            return
        if self.driver_requests and envelope['type'] != 'ride.request':
            return
        await self.send_json(envelope)

    async def disconnect(self, code):
        if self.joined:
            await self.channel_layer.group_discard(self.group, self.channel_name)
        for name in ['timeout_task', 'expiry_task']:
            task = getattr(self, name, None)
            if task:
                task.cancel()
