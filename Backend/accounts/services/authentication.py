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
    transaction.guard('otp', phone)
    provider = sms_provider()
    now = timezone.now()
    # Unique phone row also serializes simultaneous first requests.
    challenge, _ = PhoneChallenge.objects.get_or_create(phone=phone, defaults={
        'digest': '', 'expires_at': now, 'sent_at': now - timedelta(days=1)})
    challenge = PhoneChallenge.objects.all().get(pk=challenge.pk)
    remaining = settings.OTP_RESEND_SECONDS - (now - challenge.sent_at).total_seconds()
    if remaining > 0:
        raise Throttled(wait=int(remaining) + 1)
    code = f'{secrets.randbelow(1000000):06d}'
    challenge.digest = make_password(code)
    challenge.sent_at = now
    challenge.expires_at = now + timedelta(seconds=settings.OTP_TTL_SECONDS)
    challenge.attempts = 0
    challenge.consumed = False
    # A provider must durably accept delivery before this challenge is committed.
    # Delivery is synchronous to avoid persisting plaintext OTPs in a broker/outbox.
    provider.send(phone, code)
    challenge.save()


@transaction.retry
def verify_code(phone, code):
    # Invalid attempts must commit before raising an API exception.
    with transaction.atomic():
        transaction.guard('otp', phone)
        challenge = PhoneChallenge.objects.all().filter(phone=phone).first()
        valid = False
        if challenge and not challenge.consumed and challenge.expires_at > timezone.now() and challenge.attempts < settings.OTP_MAX_ATTEMPTS:
            challenge.attempts += 1
            valid = check_password(code, challenge.digest)
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
            if not identity.user.is_active:
                raise AuthenticationFailed('Account disabled.')
            refresh = RefreshToken.for_user(identity.user)
            refresh['session_version'] = identity.session_version
            return identity.user, {'access': str(refresh.access_token), 'refresh': str(refresh)}
    raise ValidationError({'code': 'Invalid, expired or exhausted verification code.'})
