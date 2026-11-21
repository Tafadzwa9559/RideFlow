from ipaddress import ip_address
import re

from django.conf import settings
from django.utils.crypto import constant_time_compare
from rest_framework.exceptions import NotFound
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.renderers import JSONRenderer
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.api.views import profile
from accounts.services import passwords, staff_sessions
from accounts.services.passenger_testing import configuration, passenger_profile
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


class NewPasswordSerializer(serializers.Serializer):
    password = serializers.CharField(min_length=8, max_length=256, trim_whitespace=False, write_only=True)
    password_confirmation = serializers.CharField(max_length=256, trim_whitespace=False, write_only=True)

    def validate(self, data):
        if not constant_time_compare(data['password'], data.pop('password_confirmation')):
            raise serializers.ValidationError({'password_confirmation': 'The passwords must match.'})
        return data


class RegistrationSerializer(NewPasswordSerializer):
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    email = serializers.EmailField(max_length=254)

    def validate_email(self, value):
        return value.lower()

    def validate(self, data):
        protected = {'role', 'roles', 'is_staff', 'is_superuser', 'is_active', 'groups', 'user_permissions'}
        if protected.intersection(self.initial_data):
            raise serializers.ValidationError('Account roles and permissions cannot be set at registration.')
        return super().validate(data)


class RegistrationResultSerializer(serializers.Serializer):
    id = serializers.CharField()
    email = serializers.EmailField()
    email_verified = serializers.BooleanField()
    verification_required = serializers.BooleanField(required=False)


class SignupContactSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(max_length=256, trim_whitespace=False, write_only=True)

    def validate_email(self, value):
        return value.lower()


class SignupVerificationSerializer(SignupContactSerializer):
    code = serializers.RegexField(r'^[0-9]{6}\Z', write_only=True)


class LoginSerializer(PasswordContactSerializer):
    password = serializers.CharField(max_length=256, trim_whitespace=False, write_only=True)


class StaffLoginSerializer(LoginSerializer):
    channel = serializers.ChoiceField(choices=['username', 'email', 'phone'])

    def validate(self, data):
        if data['channel'] == 'username':
            return data
        return super().validate(data)


class RecoveryVerificationSerializer(PasswordContactSerializer):
    code = serializers.RegexField(r'^[0-9]{6}\Z', write_only=True)


class ResetSerializer(NewPasswordSerializer):
    token = serializers.CharField(max_length=1024, write_only=True)


class ChangePasswordSerializer(NewPasswordSerializer):
    current_password = serializers.CharField(max_length=256, trim_whitespace=False, write_only=True)


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


class RegistrationView(PublicPasswordView):
    serializer_class = RegistrationSerializer
    throttle_scope = 'register-ip'
    ip_limit = (10, 3600)

    def process(self, **data):
        identity = passwords.register(**data)
        return Response({
            'id': str(identity.user_id),
            'email': identity.user.email,
            'email_verified': identity.verified_at is not None,
            **({'verification_required': True} if identity.verification_pending else {}),
        }, status=201)


class SignupResendView(PublicPasswordView):
    serializer_class = SignupContactSerializer
    throttle_scope = 'signup-resend-ip'
    ip_limit = (10, 3600)

    def process(self, **data):
        passwords.resend_signup(**data)
        return Response(status=204)


class SignupVerifyView(PublicPasswordView):
    serializer_class = SignupVerificationSerializer
    throttle_scope = 'signup-verify-ip'
    ip_limit = (30, 3600)

    def process(self, **data):
        passwords.verify_signup(**data)
        return Response(status=204)


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


class PassengerTestingView(StaffLoginView):
    throttle_scope = 'passenger-test-ip'

    def post(self, request):
        if not all(configuration()):
            raise NotFound()
        return super().post(request)

    def process(self, **data):
        actor = passwords.staff_login(**data)
        actor, identity = passenger_profile(str(actor.pk))
        refresh = RefreshToken.for_user(identity.user)
        refresh['session_version'] = identity.session_version
        refresh['passenger_test_actor'] = str(actor.pk)
        refresh['passenger_test_password'] = actor.get_session_auth_hash()
        return Response({'access': str(refresh.access_token), 'refresh': str(refresh),
                         'user': profile(identity.user)})


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


class ChangePasswordView(APIView):
    serializer_class = ChangePasswordSerializer
    renderer_classes = [JSONRenderer]

    def post(self, request):
        passwords.limit('password-change-ip', client_ip(request), 20, 900)
        passwords.limit('password-change-user', str(request.user.pk), 8, 900)
        data = self.serializer_class(data=request.data)
        data.is_valid(raise_exception=True)
        passwords.change_password(request.user.pk, **data.validated_data)
        return Response(status=204, headers={'Cache-Control': 'no-store'})
