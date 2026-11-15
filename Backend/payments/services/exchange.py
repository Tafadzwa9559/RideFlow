from datetime import timedelta
from decimal import Decimal
from urllib.parse import urlparse
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from rest_framework.exceptions import APIException
from payments.models import ExchangeRate


class ExchangeUnavailable(APIException):
    status_code = 503
    default_detail = "A current verified USD/ZiG exchange rate is unavailable. Try USD or retry later."
    default_code = "exchange_unavailable"


def verified_rate():
    now = timezone.now()
    maximum_age = timedelta(seconds=settings.TRIVIA_EXCHANGE_MAX_AGE_SECONDS)
    # A new verified row or an expiry changes the cache key; revocation is checked
    # on every call. Never serve an unbounded stale-while-revalidate rate.
    rate = (
        ExchangeRate.objects.filter(
            verified_by__is_staff=True,
            verified_at__lte=now,
            observed_at__lte=now,
            observed_at__gte=now - maximum_age,
            valid_until__gt=now,
        )
        .order_by("-observed_at", "-pk")
        .first()
    )
    if (
        rate is None
        or rate.usd_to_zwg <= 0
        or urlparse(rate.source_url).hostname
        not in settings.TRIVIA_EXCHANGE_SOURCE_HOSTS
    ):
        raise ExchangeUnavailable()
    key = f"trivia:exchange:{rate.pk}"
    value = cache.get(key)
    if value is None:
        value = str(rate.usd_to_zwg)
        ttl = max(
            1,
            min(
                300,
                int(
                    (
                        min(rate.valid_until, rate.observed_at + maximum_age) - now
                    ).total_seconds()
                ),
            ),
        )
        cache.set(key, value, ttl)
    return rate, Decimal(value)
