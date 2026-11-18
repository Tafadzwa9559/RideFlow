"""Revocable staff API sessions backed by Django's session table."""
from django.contrib.sessions.backends.db import SessionStore
from django.utils.crypto import constant_time_compare
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.tokens import RefreshToken


def tokens_for_staff(user):
    session = SessionStore()
    session['staff_api_user'] = str(user.pk)
    session['staff_api_password'] = user.get_session_auth_hash()
    session.set_expiry(api_settings.REFRESH_TOKEN_LIFETIME)
    session.create()

    refresh = RefreshToken.for_user(user)
    refresh['staff_api_session'] = session.session_key
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}


def validate_staff_session(user, token):
    session_key = token.get('staff_api_session')
    if session_key is None and not (user.is_staff or user.is_superuser):
        return
    if user.is_active and user.is_staff and isinstance(session_key, str):
        session = SessionStore(session_key=session_key)
        if (
            session.get('staff_api_user') == str(user.pk)
            and constant_time_compare(
                session.get('staff_api_password', ''), user.get_session_auth_hash()
            )
        ):
            return
    raise AuthenticationFailed('Staff API session unavailable. Sign in again.')
