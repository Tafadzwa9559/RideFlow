from ipaddress import ip_address
import re

from django.conf import settings
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.renderers import JSONRenderer
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.api.views import profile
from accounts.services import passwords, staff_sessions
from accounts.services.authentication import normalize_phone


class PasswordContactSerializer(serializers.Serializer):
    channel = serializers.ChoiceField(choices=['phone', 'email'])
    identifier = serializers.CharField(max_length=254)

    def validate(self, data):
        identifier = data['identifier']
        if data['channel'] == 'phone':
            if not re.fullmatch(r'[+0-9().\s-]+', identifier):
                raise serializers.ValidationError({'identifier': 'Enter a valid phone number.'})
            data['identifier'] = normalize_phone(identifier)
        else:
            data['identifier'] = serializers.EmailField().run_validation(identifier).lower()
        return data


class LoginSerializer(PasswordContactSerializer):
    password = serializers.CharField(max_length=256, trim_whitespace=False, write_only=True)


class StaffLoginSerializer(LoginSerializer):
    channel = serializers.ChoiceField(choices=['username', 'email', 'phone'])

    def validate(self, data):
        if data['channel'] == 'username':
            return data
        return super().validate(data)


class RecoveryVerificationSerializer(PasswordContactSerializer):
    code = serializers.RegexField(r'^[A-Za-z0-9_-]{6,64}\Z', write_only=True)

    def validate(self, data):
        data = super().validate(data)
        if data['channel'] == 'phone' and not (
            len(data['code']) == 6 and data['code'].isdigit()
        ):
            raise serializers.ValidationError({'code': 'Enter the six-digit code.'})
        return data


class ResetSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=1024, write_only=True)
    password = serializers.CharField(max_length=256, trim_whitespace=False, write_only=True)


def client_ip(request):
    # Only trust the edge-supplied header on Render's public ingress.
    remote = request.META.get('REMOTE_ADDR', '')
    value = request.META.get('HTTP_CF_CONNECTING_IP', remote) if settings.PASSWORD_AUTH_RENDER_INGRESS else remote
    try:
        address = ip_address(value)
    except ValueError:
        return 'unknown'
    return str(getattr(address, 'ipv4_mapped', None) or address)


class RecoveryTokenSerializer(serializers.Serializer):
    token = serializers.CharField()


class PublicPasswordView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = []
    renderer_classes = [JSONRenderer]
    ip_limit = (20, 900)

    def post(self, request):
        maximum, seconds = self.ip_limit
        passwords.limit(self.throttle_scope, client_ip(request), maximum, seconds)
        data = self.serializer_class(data=request.data)
        data.is_valid(raise_exception=True)
        response = self.process(**data.validated_data)
        response['Cache-Control'] = 'no-store'
        return response


class PasswordLoginView(PublicPasswordView):
    serializer_class = LoginSerializer
    throttle_scope = 'password-login-ip'

    def process(self, **data):
        user, tokens = passwords.login(**data)
        return Response({**tokens, 'user': profile(user)})


class StaffLoginView(PublicPasswordView):
    serializer_class = StaffLoginSerializer
    throttle_scope = 'staff-login-ip'

    def process(self, **data):
        user = passwords.staff_login(**data)
        return Response({**staff_sessions.tokens_for_staff(user), 'user': profile(user)})


class RecoveryRequestView(PublicPasswordView):
    serializer_class = PasswordContactSerializer
    throttle_scope = 'password-request-ip'
    ip_limit = (10, 3600)

    def process(self, **data):
        passwords.request_recovery(**data)
        return Response({'detail': passwords.ACCEPTED}, status=202)


class RecoveryVerifyView(PublicPasswordView):
    serializer_class = RecoveryVerificationSerializer
    throttle_scope = 'password-verify-ip'
    ip_limit = (30, 3600)

    def process(self, **data):
        return Response({'token': passwords.verify_recovery(**data)})


class RecoveryResetView(PublicPasswordView):
    serializer_class = ResetSerializer
    throttle_scope = 'password-reset-ip'

    def process(self, token, password):
        passwords.reset_password(token, password)
        return Response(status=204)
