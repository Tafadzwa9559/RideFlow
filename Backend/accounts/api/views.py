import logging

from bson import ObjectId
from redis import RedisError
from core import transactions as transaction
from django.contrib.auth import get_user_model
from django.contrib.sessions.backends.db import SessionStore
from django.db.models import F
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView
from accounts.authentication import SessionJWTAuthentication
from accounts.models import PhoneIdentity
from accounts.services.authentication import SMSUnavailable, normalize_phone, request_code, verify_code


logger = logging.getLogger(__name__)


class PhoneSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=40)

    def validate_phone(self, value):
        return normalize_phone(value)


class CodeSerializer(PhoneSerializer):
    code = serializers.RegexField(r'^\d{6}$')
    legal_acknowledgement = serializers.JSONField(required=False)


class OTPRequestView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_scope = 'otp_request'

    def check_throttles(self, request):
        try:
            super().check_throttles(request)
        except RedisError as exc:
            logger.error('OTP throttle cache unavailable | error_type=%s', type(exc).__name__,
                         extra={'request_id': getattr(request, 'request_id', None)})
            raise SMSUnavailable('OTP is temporarily unavailable. Try again later.') from None

    def post(self, request):
        data = PhoneSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        request_code(data.validated_data['phone'])
        return Response({'detail': 'Verification code requested.'}, status=202)


class OTPVerifyView(OTPRequestView):
    throttle_scope = 'otp_verify'

    def post(self, request):
        data = CodeSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        user, tokens = verify_code(**data.validated_data)
        return Response({**tokens, 'user': profile(user)})


def profile(user):
    from drivers.models import DriverApplication
    status = DriverApplication.objects.filter(user=user).values_list('status', flat=True).first()
    return {'id': str(user.pk), 'first_name': user.first_name, 'last_name': user.last_name,
            'email': user.email, 'phone': getattr(getattr(user, 'phone_identity', None), 'phone', user.username),
            'driver_status': status or 'notRegistered'}


class ProfileSerializer(serializers.Serializer):
    first_name = serializers.CharField(max_length=150, required=False)
    last_name = serializers.CharField(max_length=150, required=False)
    email = serializers.EmailField(required=False, allow_blank=True)


class MeView(APIView):
    def get(self, request):
        return Response(profile(request.user))

    @transaction.atomic
    def patch(self, request):
        data = ProfileSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        user = request.user
        if 'email' in data.validated_data:
            transaction.guard(get_user_model(), user.pk)
            user = get_user_model().objects.get(pk=user.pk)
            email = data.validated_data['email'].lower()
            if email and email != user.email.lower():
                transaction.guard('profile-email', email)
                if get_user_model().objects.filter(email__iexact=email).exclude(pk=user.pk).exists():
                    raise serializers.ValidationError({'email': 'This email address is unavailable.'})
                data.validated_data['email'] = email
        for key, value in data.validated_data.items():
            setattr(user, key, value)
        if data.validated_data:
            user.save(update_fields=list(data.validated_data))
        return Response(profile(user))

    post = patch


class LogoutView(APIView):
    @transaction.atomic
    def post(self, request):
        staff_session = request.auth and request.auth.get('staff_api_session')
        if staff_session:
            transaction.guard(get_user_model(), request.user.pk)
            SessionStore(session_key=staff_session).delete()
            return Response(status=204)

        # Revoke all access/refresh sessions for this phone account immediately.
        transaction.guard(get_user_model(), request.user.pk)
        identity = PhoneIdentity.objects.filter(user=request.user).first()
        if identity:
            identity.session_version = F('session_version') + 1
            identity.save(update_fields=['session_version'])
        from notifications.models import DeviceToken
        DeviceToken.objects.filter(user=request.user).delete()
        raw = request.data.get('refresh')
        if raw:
            try:
                token = RefreshToken(raw)
                if str(token['user_id']) != str(request.user.pk):
                    raise InvalidToken('Token does not belong to this account.')
                token.blacklist()
            except TokenError:
                raise InvalidToken('Invalid refresh token.')
        return Response(status=204)


class RefreshView(TokenRefreshView):
    throttle_scope = 'otp_verify'

    @transaction.atomic
    def post(self, request, *args, **kwargs):
        try:
            token = RefreshToken(request.data.get('refresh', ''))
            if not ObjectId.is_valid(str(token.get('user_id', ''))):
                raise InvalidToken('Sign in again after the database migration.')
            transaction.guard(get_user_model(), token['user_id'])
            transaction.guard('refresh', token['jti'])
            # Revalidate after acquiring guards: another rotation may have committed.
            token = RefreshToken(request.data.get('refresh', ''))
            SessionJWTAuthentication().get_user(token)
        except TokenError as exc:
            raise InvalidToken(str(exc))
        return super().post(request, *args, **kwargs)
