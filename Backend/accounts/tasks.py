"""Celery task discovery for account recovery delivery."""
from accounts.services.passwords import deliver_recovery

__all__ = ['deliver_recovery']
