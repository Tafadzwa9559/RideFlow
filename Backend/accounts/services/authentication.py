import secrets
from datetime import timedelta
import phonenumbers
from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password, check_password
from core import transactions as transaction
from django.utils import timezone
from django.utils.module_loading import import_string
from rest_framework.exceptions import ValidationError, Throttled, AuthenticationFailed
from rest_framework_simplejwt.tokens import RefreshToken
from accounts.models import PhoneChallenge, PhoneIdentity
from accounts.test_otp import (
    DEVELOPMENT_CODE, DEVELOPMENT_DIGEST_PREFIX, validate_test_otp_settings,
)


def development_otp_enabled(phone):
    validate_test_otp_settings(settings)
    if not settings.TRIVIA_TEST_OTP_ENABLED:
        return False
    if phone not in settings.TRIVIA_TEST_OTP_PHONES:
        raise ValidationError({'phone': 'Development authentication is unavailable for this number.'})
    # Check both identity ownership and username collisions before creating a challenge/account.
    identity = PhoneIdentity.objects.select_related('user').filter(phone=phone).first()
    user = identity.user if identity else get_user_model().objects.filter(username=phone).first()
    if user and (user.is_staff or user.is_superuser or not user.is_active):
        raise AuthenticationFailed('Development authentication is unavailable for this account.')
    return True


def validate_development_session(identity):
    try:
        if identity is not None and development_otp_enabled(identity.phone):
            return
    except ValidationError as exc:
        raise AuthenticationFailed('Development session unavailable.') from exc
    raise AuthenticationFailed('Development session unavailable.')


def normalize_phone(value):
    try:
        phone = phonenumbers.parse(value, 'ZW')
        if not phonenumbers.is_valid_number(phone):
            raise ValueError()
        return phonenumbers.format_number(phone, phonenumbers.PhoneNumberFormat.E164)
    except (phonenumbers.NumberParseException, ValueError):
        raise ValidationError({'phone': 'Enter a valid international phone number.'})


class LocalSMS:
    """Explicit local facility. Codes remain in process memory and never enter logs."""
    messages = {}

    def send(self, phone, code):
        if not settings.DEBUG or not settings.TRIVIA_LOCAL_OTP:
            raise RuntimeError('Local SMS is disabled')
        self.messages[phone] = code


def sms_provider():
    if not settings.SMS_PROVIDER:
        from rest_framework.exceptions import APIException
        error = APIException('SMS delivery is not configured.')
        error.status_code = 503
        raise error
    return import_string(settings.SMS_PROVIDER)()


@transaction.atomic
def request_code(phone):
    development = development_otp_enabled(phone)
    transaction.guard('otp', phone)
    provider = None if development else sms_provider()
    now = timezone.now()
    # Unique phone row also serializes simultaneous first requests.
    challenge, _ = PhoneChallenge.objects.get_or_create(phone=phone, defaults={
        'digest': '', 'expires_at': now, 'sent_at': now - timedelta(days=1)})
    challenge = PhoneChallenge.objects.all().get(pk=challenge.pk)
    remaining = settings.OTP_RESEND_SECONDS - (now - challenge.sent_at).total_seconds()
    if remaining > 0:
        raise Throttled(wait=int(remaining) + 1)
    code = DEVELOPMENT_CODE if development else f'{secrets.randbelow(1000000):06d}'
    challenge.digest = (DEVELOPMENT_DIGEST_PREFIX if development else '') + make_password(code)
    challenge.sent_at = now
    challenge.expires_at = now + timedelta(seconds=settings.OTP_TTL_SECONDS)
    challenge.attempts = 0
    challenge.consumed = False
    # Normal SMS delivery must be accepted before committing the challenge.
    # Development challenges never invoke an SMS provider.
    if provider is not None:
        provider.send(phone, code)
    challenge.save()


@transaction.retry
def verify_code(phone, code, legal_acknowledgement=None):
    if legal_acknowledgement is not None:
        from accounts.legal import validate_acknowledgement
        legal_acknowledgement = validate_acknowledgement(legal_acknowledgement)
    development = development_otp_enabled(phone)
    # Invalid attempts must commit before raising an API exception.
    with transaction.atomic():
        transaction.guard('otp', phone)
        challenge = PhoneChallenge.objects.all().filter(phone=phone).first()
        valid = False
        if challenge and not challenge.consumed and challenge.expires_at > timezone.now() and challenge.attempts < settings.OTP_MAX_ATTEMPTS:
            challenge.attempts += 1
            test_challenge = challenge.digest.startswith(DEVELOPMENT_DIGEST_PREFIX)
            if test_challenge:
                valid = development and check_password(
                    code, challenge.digest.removeprefix(DEVELOPMENT_DIGEST_PREFIX))
            else:
                valid = not development and check_password(code, challenge.digest)
            if valid:
                challenge.consumed = True
            challenge.save(update_fields=['attempts', 'consumed'])
        if valid:
            identity = PhoneIdentity.objects.all().filter(phone=phone).first()
            if identity is None:
                user, created = get_user_model().objects.get_or_create(username=phone)
                if created:
                    user.set_unusable_password()
                    user.save(update_fields=['password'])
                identity = PhoneIdentity.objects.create(user=user, phone=phone, verified_at=timezone.now())
            transaction.guard(get_user_model(), identity.user_id)
            identity = PhoneIdentity.objects.select_related('user').get(pk=identity.pk)
            if development and (identity.user.is_staff or identity.user.is_superuser):
                raise AuthenticationFailed('Development authentication is unavailable for this account.')
            if not identity.user.is_active:
                raise AuthenticationFailed('Account disabled.')
            if legal_acknowledgement is not None:
                from accounts.legal import record_acknowledgement
                record_acknowledgement(identity.user, legal_acknowledgement)
            refresh = RefreshToken.for_user(identity.user)
            refresh['session_version'] = identity.session_version
            if development:
                refresh['development_otp'] = True
            return identity.user, {'access': str(refresh.access_token), 'refresh': str(refresh)}
    raise ValidationError({'code': 'Invalid, expired or exhausted verification code.'})
