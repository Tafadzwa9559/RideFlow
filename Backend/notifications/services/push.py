"""Operator adapter interface: send(token, platform, event_id, event_type).

Implementations must use event_id for retry deduplication and send generic text.
FCM/APNs credentials belong in the operator's secret manager. No default sender.
"""
from typing import Protocol


class PushProvider(Protocol):
    def send(self, token: str, platform: str, event_id: str, event_type: str) -> None: ...


class TransientPushError(Exception):
    """Adapters raise this for retryable failures, without credentials in text.

    Permanent invalid-device failures should disable/remove the token in the
    adapter rather than treating a provider's HTTP success as handset delivery.
    """

# Adapter contract: return only after durable provider acceptance. Deduplicate
# by (destination device, event_id); never log device credentials or API secrets.
