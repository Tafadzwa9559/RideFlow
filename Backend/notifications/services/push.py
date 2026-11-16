"""Operator adapter interface: send(token, platform, event_id, event_type).

Implementations must use event_id for retry deduplication and send generic text.
FCM/APNs credentials belong in the operator's secret manager. No default sender.
"""
from typing import Protocol


class PushProvider(Protocol):
    def send(self, token: str, platform: str, event_id: str, event_type: str) -> None: ...
