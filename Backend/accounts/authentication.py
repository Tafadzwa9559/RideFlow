from bson import ObjectId
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication
from accounts.models import PhoneIdentity


class SessionJWTAuthentication(JWTAuthentication):
    def get_user(self, token):
        if not ObjectId.is_valid(str(token.get('user_id', ''))):
            raise AuthenticationFailed('Sign in again after the database migration.')
        user = super().get_user(token)
        if token.get('development_otp'):
            from accounts.services.authentication import validate_development_session
            identity = PhoneIdentity.objects.filter(user=user).first()
            validate_development_session(identity)
        version = PhoneIdentity.objects.filter(user=user).values_list('session_version', flat=True).first()
        if version is not None and token.get('session_version') != version:
            raise AuthenticationFailed('Session revoked.')
        return user
