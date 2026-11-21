from bson import ObjectId
from django.utils.crypto import constant_time_compare
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication
from accounts.models import EmailIdentity, PhoneIdentity
from accounts.services.staff_sessions import validate_staff_session


class SessionJWTAuthentication(JWTAuthentication):
    def get_user(self, token):
        if not ObjectId.is_valid(str(token.get('user_id', ''))):
            raise AuthenticationFailed('Sign in again after the database migration.')
        user = super().get_user(token)
        if 'passenger_test_actor' in token:
            from accounts.services.passenger_testing import passenger_profile
            actor, identity = passenger_profile(token['passenger_test_actor'])
            if (identity.user_id != user.pk or token.get('session_version') != identity.session_version
                    or not constant_time_compare(token.get('passenger_test_password', ''), actor.get_session_auth_hash())):
                raise AuthenticationFailed('Passenger testing session unavailable.')
            return user
        validate_staff_session(user, token)
        if token.get('staff_api_session'):
            return user
        if 'email_session_version' in token:
            identity = EmailIdentity.objects.filter(user=user).first()
            if (identity is None or identity.verification_pending
                    or token['email_session_version'] != identity.session_version):
                raise AuthenticationFailed('Session revoked.')
            return user
        if token.get('development_otp'):
            from accounts.services.authentication import validate_development_session
            identity = PhoneIdentity.objects.filter(user=user).first()
            validate_development_session(identity)
        version = PhoneIdentity.objects.filter(user=user).values_list('session_version', flat=True).first()
        if version is not None and token.get('session_version') != version:
            raise AuthenticationFailed('Session revoked.')
        return user
