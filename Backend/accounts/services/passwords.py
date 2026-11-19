"""Passenger registration, password authentication and recovery."""
import logging
import secrets
import uuid
from functools import lru_cache
from types import SimpleNamespace

from celery import shared_task
from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.password_validation import validate_password
from django.core import signing
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.db.models import F
from django.utils.crypto import salted_hmac
from redis import Redis, RedisError
from redis.backoff import NoBackoff
from redis.retry import Retry
from core.middleware import request_id_context
from rest_framework.exceptions import APIException, Throttled, ValidationError
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import EmailIdentity, PhoneIdentity
from accounts.services.authentication import sms_provider
from accounts.test_otp import validate_test_otp_settings
from core import transactions as transaction

logger = logging.getLogger(__name__)
RESET_SALT = 'trivia.password-reset'
INVALID_PROOF = 'Invalid or expired verification. Request a new code.'
ACCEPTED = 'If the account is eligible, a verification code will be sent.'


class Unavailable(APIException):
    status_code = 503
    default_detail = 'Password recovery is temporarily unavailable. Try again later.'


class InvalidCredentials(APIException):
    status_code = 401
    default_detail = 'The account details or password are incorrect.'
    default_code = 'invalid_credentials'


@lru_cache(maxsize=4)
def redis_client(url):
    try:
        tls = {'ssl_cert_reqs': 'required', 'ssl_check_hostname': True} if url.startswith('rediss://') else {}
        return Redis.from_url(url, socket_timeout=3, socket_connect_timeout=3,
                              retry=Retry(NoBackoff(), 0), **tls)
    except (AttributeError, ValueError) as exc:
        log_redis_failure(exc)
        raise Unavailable('Authentication is temporarily unavailable. Try again later.') from None


def log_redis_failure(exc):
    logger.error('Password authentication Redis command failed | error_type=%s', type(exc).__name__,
                 extra={'request_id': request_id_context.get()})


def run_script(script, key, *args):
    try:
        return redis_client(settings.PASSWORD_AUTH_REDIS_URL).eval(
            script, 1, key, *args)
    except RedisError as exc:
        log_redis_failure(exc)
        raise Unavailable('Authentication is temporarily unavailable. Try again later.') from None


def digest(purpose, value):
    return salted_hmac(f'trivia.{purpose}', value, algorithm='sha256').hexdigest()


def limit(action, subject, maximum, seconds):
    wait = run_script("""
        local count = redis.call('INCR', KEYS[1])
        if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[2]) end
        if count > tonumber(ARGV[1]) then return redis.call('TTL', KEYS[1]) end
        return -1
    """, f'trivia:limit:{action}:{digest("rate", subject)}', maximum, seconds)
    if wait >= 0:
        raise Throttled(wait=max(1, wait))


class DuplicateEmail(APIException):
    status_code = 409
    default_detail = 'This email address is unavailable.'
    default_code = 'duplicate_email'


def register(first_name, last_name, email, password):
    limit('register-contact', email, 5, 3600)
    user = get_user_model()(
        username=f'passenger-{uuid.uuid4().hex}', email=email,
        first_name=first_name, last_name=last_name,
        is_active=True, is_staff=False, is_superuser=False,
    )
    try:
        validate_password(password, user)
    except DjangoValidationError as exc:
        raise ValidationError({'password': exc.messages}, code='invalid_password') from None
    user.set_password(password)
    return create_email_account(user)


@transaction.atomic
def create_email_account(user):
    transaction.guard('profile-email', user.email)
    if get_user_model().objects.filter(email__iexact=user.email).exists():
        raise DuplicateEmail()
    user.save(force_insert=True)
    return EmailIdentity.objects.create(user=user)


def unique_email_user(identifier):
    matches = list(get_user_model().objects.filter(email__iexact=identifier)[:2])
    return matches[0] if len(matches) == 1 else None


def passenger(user):
    return user is not None and user.is_active and not (user.is_staff or user.is_superuser)


def account(channel, identifier):
    identities = PhoneIdentity.objects.filter(
        verified_at__isnull=False).select_related('user')
    if channel == 'phone':
        identity = identities.filter(phone=identifier).first()
    else:
        # Reject ambiguous legacy addresses, including duplicates outside Trivia.
        user = unique_email_user(identifier)
        identity = identities.filter(user=user).first() if user is not None else None
    if identity and passenger(identity.user):
        return identity
    return None


@lru_cache(maxsize=1)
def dummy_password():
    return make_password(secrets.token_urlsafe(32))


def verify_password(user, password):
    usable = user is not None and user.has_usable_password()
    encoded = user.password if usable else dummy_password()
    if not check_password(password, encoded) or not usable:
        raise InvalidCredentials()


def staff_login(channel, identifier, password):
    limit('staff-login-contact', f'{channel}:{identifier.casefold()}', 8, 900)
    users = get_user_model().objects
    if channel == 'phone':
        identity = PhoneIdentity.objects.select_related('user').filter(
            phone=identifier, verified_at__isnull=False,
        ).first()
        user = identity.user if identity else None
    elif channel == 'email':
        user = unique_email_user(identifier)
    else:
        user = users.filter(username=identifier).first()
    if user is not None and not (user.is_active and user.is_staff):
        user = None
    verify_password(user, password)
    return user


def login(channel, identifier, password):
    limit('login-contact', f'{channel}:{identifier}', 8, 900)
    if channel == 'email':
        user = unique_email_user(identifier)
        identity = None
        if passenger(user):
            identity = PhoneIdentity.objects.filter(user=user, verified_at__isnull=False).first()
            if identity is None:
                identity = EmailIdentity.objects.filter(user=user).first()
    else:
        identity = account(channel, identifier)
        user = identity.user if identity else None
    verify_password(user if identity else None, password)
    refresh = RefreshToken.for_user(user)
    claim = 'email_session_version' if isinstance(identity, EmailIdentity) else 'session_version'
    refresh[claim] = identity.session_version
    return user, {'access': str(refresh.access_token), 'refresh': str(refresh)}


class LocalRecoverySMS:
    """Process-local test mailbox for allowlisted development accounts only."""
    messages = {}

    def send(self, phone, code):
        if not local_recovery() or phone not in settings.TRIVIA_TEST_OTP_PHONES:
            raise RuntimeError('Local password recovery is disabled for this account.')
        self.messages[phone] = code


def local_recovery():
    if not settings.TRIVIA_LOCAL_PASSWORD_RECOVERY:
        return False
    validate_test_otp_settings(SimpleNamespace(
        SETTINGS_MODULE=settings.SETTINGS_MODULE,
        DEBUG=settings.DEBUG,
        DATABASES=settings.DATABASES,
        ALLOWED_HOSTS=settings.ALLOWED_HOSTS,
        TRIVIA_TEST_OTP_ENABLED=True,
        TRIVIA_TEST_OTP_PHONES=settings.TRIVIA_TEST_OTP_PHONES,
    ))
    return True


def check_delivery(channel):
    if channel == 'phone':
        if local_recovery():
            return
        if not settings.SMS_PROVIDER or settings.SMS_PROVIDER == 'accounts.services.authentication.LocalSMS':
            raise Unavailable('SMS password recovery is currently unavailable.')
    elif not settings.TRIVIA_RECOVERY_EMAIL_ENABLED:
        raise Unavailable('Email password recovery is currently unavailable.')


def recovery_account(channel, identifier):
    identity = account(channel, identifier)
    if identity and channel == 'email':
        if EmailIdentity.objects.filter(user_id=identity.user_id, verified_at__isnull=True).exists():
            return None
        # The editable legacy email field alone does not establish ownership.
        if settings.TRIVIA_VERIFIED_RECOVERY_EMAILS.get(str(identity.user_id), '').lower() != identifier:
            return None
    if identity and channel == 'phone' and local_recovery():
        if identifier not in settings.TRIVIA_TEST_OTP_PHONES:
            return None
    return identity


def recovery_key(channel, identifier):
    return f'trivia:reset:{digest("recipient", f"{channel}:{identifier}")}'


def password_state(identity):
    return digest('state', f'{identity.user.password}:{identity.session_version}')


@shared_task(ignore_result=True)
def deliver_recovery(channel, identifier):
    try:
        check_delivery(channel)
        identity = recovery_account(channel, identifier)
        if identity is None:
            return
        code = f'{secrets.randbelow(1000000):06d}' if channel == 'phone' else secrets.token_urlsafe(24)
        proof = signing.dumps(
            [channel, identifier, str(identity.user_id), password_state(identity)],
            salt=RESET_SALT,
        )
        key = recovery_key(channel, identifier)
        challenge_digest = digest(key, code)
        run_script("""
            redis.call('HSET', KEYS[1], 'code', ARGV[1], 'proof', ARGV[2], 'attempts', 0)
            redis.call('EXPIRE', KEYS[1], ARGV[3])
            return 1
        """, key, challenge_digest, proof, settings.OTP_TTL_SECONDS)
        try:
            if channel == 'phone':
                if local_recovery():
                    LocalRecoverySMS().send(identifier, code)
                else:
                    sms_provider().send(identifier, code)
            elif send_mail(
                'Trivia password recovery',
                f'Enter this verification code in Trivia: {code}\n\n'
                'It expires in five minutes. Ignore this email if you did not request it.',
                settings.DEFAULT_FROM_EMAIL, [identifier],
            ) != 1:
                raise Unavailable()
        except Exception:
            run_script("""
                if redis.call('HGET', KEYS[1], 'code') == ARGV[1] then
                    return redis.call('DEL', KEYS[1])
                end
                return 0
            """, key, challenge_digest)
            raise
    except Exception:
        # Provider exceptions can contain message bodies or recipient addresses.
        logger.error('Password recovery delivery failed for channel %s.', channel)


def request_recovery(channel, identifier):
    check_delivery(channel)
    subject = f'{channel}:{identifier}'
    limit('reset-resend', subject, 1, settings.OTP_RESEND_SECONDS)
    limit('reset-contact', subject, 5, 3600)
    try:
        deliver_recovery.apply_async(
            args=(channel, identifier), argsrepr='(contact redacted)', expires=60, retry=False)
    except Exception:
        raise Unavailable() from None


def verify_recovery(channel, identifier, code):
    limit('reset-verify-contact', f'{channel}:{identifier}', 15, 3600)
    key = recovery_key(channel, identifier)
    proof = run_script("""
        if redis.call('HEXISTS', KEYS[1], 'code') == 0 then return false end
        local attempts = redis.call('HINCRBY', KEYS[1], 'attempts', 1)
        if redis.call('HGET', KEYS[1], 'code') == ARGV[1] then
            local proof = redis.call('HGET', KEYS[1], 'proof')
            redis.call('DEL', KEYS[1])
            return proof
        end
        if attempts >= tonumber(ARGV[2]) then redis.call('DEL', KEYS[1]) end
        return false
    """, key, digest(key, code), settings.OTP_MAX_ATTEMPTS)
    if not proof:
        raise ValidationError({'code': INVALID_PROOF})
    return proof.decode()


@transaction.atomic
def reset_password(proof, password):
    try:
        channel, identifier, user_id, state = signing.loads(
            proof, salt=RESET_SALT, max_age=settings.OTP_TTL_SECONDS)
    except signing.BadSignature:
        raise ValidationError({'token': INVALID_PROOF}) from None

    transaction.guard(get_user_model(), user_id)
    if channel == 'email':
        transaction.guard('profile-email', identifier)
    identity = recovery_account(channel, identifier)
    if not identity or str(identity.user_id) != user_id or not secrets.compare_digest(password_state(identity), state):
        raise ValidationError({'token': INVALID_PROOF})

    user = identity.user
    try:
        validate_password(password, user)
    except DjangoValidationError as exc:
        raise ValidationError({'password': exc.messages}) from None
    user.set_password(password)
    user.save(update_fields=['password'])
    PhoneIdentity.objects.filter(pk=identity.pk).update(session_version=F('session_version') + 1)
    EmailIdentity.objects.filter(user=user).update(session_version=F('session_version') + 1)
