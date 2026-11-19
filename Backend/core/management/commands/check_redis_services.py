import asyncio
import uuid

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from channels_redis.core import RedisChannelLayer
from django.core.cache import caches
from django.core.cache.backends.redis import RedisCache
from django.core.management.base import BaseCommand, CommandError
from rest_framework.exceptions import Throttled

from accounts.services.passwords import limit
from core.views import check_celery, check_password_redis, check_redis


async def check_channels():
    layer = get_channel_layer()
    if not isinstance(layer, RedisChannelLayer):
        return False
    channel = await layer.new_channel('trivia.probe')
    message = {'type': 'trivia.probe'}
    await asyncio.wait_for(layer.send(channel, message), timeout=5)
    return await asyncio.wait_for(layer.receive(channel), timeout=5) == message


def check_cache():
    cache = caches['default']
    if not isinstance(cache, RedisCache):
        return False
    key = f'probe:{uuid.uuid4().hex}'
    cache.set(key, key, timeout=30)
    try:
        return cache.get(key) == key
    finally:
        cache.delete(key)


def check_rate_limit():
    subject = uuid.uuid4().hex
    limit('redis-probe', subject, 1, 30)
    try:
        limit('redis-probe', subject, 1, 30)
    except Throttled:
        return True
    return False


class Command(BaseCommand):
    help = 'Probe Redis services using short-lived keys, without printing connection settings.'

    def add_arguments(self, parser):
        parser.add_argument('--worker', action='store_true', help='Also require a Celery worker reply.')

    def handle(self, *args, **options):
        checks = {
            'Redis PING': check_redis,
            'Auth Redis EVAL': check_password_redis,
            'Django cache': check_cache,
            'Channels round trip': async_to_sync(check_channels),
            'Auth rate limit': check_rate_limit,
        }
        if options['worker']:
            checks['Celery worker via broker'] = check_celery
        failed = False
        for label, check in checks.items():
            try:
                if not check():
                    raise RuntimeError()
            except Exception as exc:
                self.stderr.write(f'{label}: FAILED ({type(exc).__name__})')
                failed = True
            else:
                self.stdout.write(f'{label}: OK')
        if failed:
            raise CommandError('One or more Redis probes failed.')
