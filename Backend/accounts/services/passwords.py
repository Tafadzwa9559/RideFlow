"""Passenger registration, password authentication and recovery."""
import json
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
from django.db.models import F
from django.utils import timezone
from django.utils.crypto import salted_hmac
from redis import Redis, RedisError
from redis.backoff import NoBackoff
from redis.retry import Retry
from core.middleware import request_id_context
from rest_framework.exceptions import APIException, Throttled, ValidationError
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import EmailIdentity, PhoneIdentity
from accounts.services import email_codes
from accounts.services.authentication import sms_provider
from accounts.test_otp import validate_test_otp_settings
from core import transactions as transaction

logger = logging.getLogger(__name__)
RESET_SALT = 'trivia.password-reset.v2'
RESET_AUTHORIZATION_TTL = 300
INVALID_PROOF = 'Invalid or expired verification. Request a new code.'
ACCEPTED = 'If eligible and delivery is available, check for a code. This response does not confirm delivery.'


class Unavailable(APIException):
    status_code = 503
    default_detail = 'Password recovery is temporarily unavailable. Try again later.'


class InvalidCredentials(APIException):
    status_code = 401
    default_detail = 'The account details or password are incorrect.'
    default_code = 'invalid_credentials'


class EmailVerificationRequired(APIException):
    status_code = 403
    default_detail = 'Verify your email address before logging in.'
    default_code = 'email_verification_required'


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
    validate_new_password(password, user)
    user.set_password(password)
    try:
        identity = create_email_account(user)
    except DuplicateEmail:
        identity = signup_identity(email)
        if identity is None or not identity.verification_pending or not identity.user.check_password(password):
            raise
        try:
            send_signup_code(identity)
        except Throttled:
            if not signup_code_delivered(identity):
                raise
        return identity
    if identity.verification_pending:
        send_signup_code(identity)
    return identity


@transaction.atomic
def create_email_account(user):
    transaction.guard('profile-email', user.email)
    if get_user_model().objects.filter(email__iexact=user.email).exists():
        raise DuplicateEmail()
    user.save(force_insert=True)
    return EmailIdentity.objects.create(
        user=user, verification_required=settings.TRIVIA_EMAIL_SIGNUP_VERIFICATION_ENABLED)


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
    if isinstance(identity, EmailIdentity) and identity.verification_pending:
        raise EmailVerificationRequired()
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
    if channel == 'email':
        user = unique_email_user(identifier)
        if not passenger(user):
            return None
        # The emailed code establishes ownership of the email sign-in address.
        identity = EmailIdentity.objects.filter(user=user).select_related('user').first()
        if identity:
            return identity
        # A mutable legacy profile email must still have a trusted ownership binding.
        if settings.TRIVIA_VERIFIED_RECOVERY_EMAILS.get(str(user.pk), '').lower() != identifier:
            return None
    identity = account(channel, identifier)
    if identity and channel == 'phone' and local_recovery():
        if identifier not in settings.TRIVIA_TEST_OTP_PHONES:
            return None
    return identity


def recovery_key(channel, identifier):
    return f'trivia:reset:{digest("recipient", f"{channel}:{identifier}")}'


def password_state(identity):
    return digest('state', f'{identity.user.password}:{identity.session_version}')


def issue_code(key, binding, deliver):
    challenge = json.dumps([*binding, secrets.token_urlsafe(16)])
    ttl = settings.OTP_TTL_SECONDS
    for _ in range(3):
        code = f'{secrets.randbelow(1000000):06d}'
        if run_script("""
            if redis.call('HGET', KEYS[1], 'code') == ARGV[1] then return 0 end
            redis.call('HSET', KEYS[1], 'code', ARGV[1], 'challenge', ARGV[2], 'attempts', 0, 'delivery', 'pending')
            return redis.call('EXPIRE', KEYS[1], ARGV[3])
        """, key, digest(key, code), challenge, ttl):
            break
    else:
        raise Unavailable()
    try:
        deliver(code)
        if not run_script("""
            if redis.call('HGET', KEYS[1], 'challenge') ~= ARGV[1] then return 0 end
            redis.call('HDEL', KEYS[1], 'delivery')
            return redis.call('EXPIRE', KEYS[1], ARGV[2])
        """, key, challenge, ttl):
            raise Unavailable()
    except Exception:
        run_script("""
            if redis.call('HGET', KEYS[1], 'challenge') == ARGV[1] then
                return redis.call('DEL', KEYS[1])
            end
            return 0
        """, key, challenge)
        raise


def consume_code(key, code):
    proof = run_script("""
        if redis.call('HEXISTS', KEYS[1], 'challenge') == 0
            or redis.call('HGET', KEYS[1], 'delivery') == 'pending' then return false end
        if redis.call('HGET', KEYS[1], 'code') == ARGV[1] then
            local proof = redis.call('HGET', KEYS[1], 'challenge')
            redis.call('DEL', KEYS[1])
            return proof
        end
        local attempts = redis.call('HINCRBY', KEYS[1], 'attempts', 1)
        if attempts >= tonumber(ARGV[2]) then redis.call('DEL', KEYS[1]) end
        return false
    """, key, digest(key, code), settings.OTP_MAX_ATTEMPTS)
    if not proof:
        raise ValidationError({'code': INVALID_PROOF})
    return json.loads(proof)


def signup_identity(email):
    user = unique_email_user(email)
    if passenger(user):
        return EmailIdentity.objects.filter(user=user).select_related('user').first()
    return None


def signup_key(email):
    return f'trivia:signup:{digest("recipient", email)}'


def signup_code_delivered(identity):
    email = identity.user.email.lower()
    proof = run_script("""
        if redis.call('HGET', KEYS[1], 'delivery') == 'pending' then return false end
        return redis.call('HGET', KEYS[1], 'challenge')
    """, signup_key(email))
    return bool(proof and json.loads(proof)[:-1] == [
        email, str(identity.user_id), password_state(identity),
    ])


def signup_account(email, password, action):
    limit(f'signup-{action}-contact', email, 15, 3600)
    identity = signup_identity(email)
    verify_password(identity.user if identity and identity.verification_pending else None, password)
    limit(f'signup-{action}-user', str(identity.user_id), 15, 3600)
    return identity


def send_signup_code(identity):
    email = identity.user.email.lower()
    limit('signup-resend', email, 1, settings.OTP_RESEND_SECONDS)
    limit('signup-delivery-user', str(identity.user_id), 5, 3600)
    try:
        issue_code(
            signup_key(email), [email, str(identity.user_id), password_state(identity)],
            lambda code: email_codes.send_code(email, code, 'signup'),
        )
    except Exception:
        logger.error('Signup verification delivery failed.')
        raise Unavailable('Verification email could not be sent. Try again after one minute.') from None


def resend_signup(email, password):
    send_signup_code(signup_account(email, password, 'resend'))


def verify_signup(email, password, code):
    identity = signup_account(email, password, 'verify')
    binding = consume_code(signup_key(email), code)
    mark_signup_verified(identity.user_id, email, binding)


@transaction.atomic
def mark_signup_verified(user_id, email, binding):
    transaction.guard(get_user_model(), user_id)
    transaction.guard('profile-email', email)
    identity = signup_identity(email)
    if (identity is None or not identity.verification_pending or identity.user_id != user_id
            or binding[:-1] != [email, str(user_id), password_state(identity)]):
        raise ValidationError({'code': INVALID_PROOF})
    identity.verified_at = timezone.now()
    identity.save(update_fields=['verified_at'])


@shared_task(ignore_result=True)
def deliver_recovery(channel, identifier):
    try:
        check_delivery(channel)
        identity = recovery_account(channel, identifier)
        if identity is None:
            return
        limit('reset-delivery-user', str(identity.user_id), 5, 3600)

        def deliver(code):
            if channel == 'email':
                email_codes.send_code(identifier, code, 'password_reset')
            elif local_recovery():
                LocalRecoverySMS().send(identifier, code)
            else:
                sms_provider().send(identifier, code)

        issue_code(
            recovery_key(channel, identifier),
            [channel, identifier, str(identity.user_id), password_state(identity)],
            deliver,
        )
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
    channel, identifier, user_id, state, _ = consume_code(
        recovery_key(channel, identifier), code)
    return signing.dumps([channel, identifier, user_id, state], salt=RESET_SALT)


@transaction.atomic
def reset_password(proof, password):
    try:
        channel, identifier, user_id, state = signing.loads(
            proof, salt=RESET_SALT, max_age=RESET_AUTHORIZATION_TTL)
    except signing.BadSignature:
        raise ValidationError({'token': INVALID_PROOF}) from None

    transaction.guard(get_user_model(), user_id)
    if channel == 'email':
        transaction.guard('profile-email', identifier)
    identity = recovery_account(channel, identifier)
    if not identity or str(identity.user_id) != user_id or not secrets.compare_digest(password_state(identity), state):
        raise ValidationError({'token': INVALID_PROOF})

    if (isinstance(identity, EmailIdentity) and identity.verified_at is None
            and not identity.verification_pending):
        identity.verified_at = timezone.now()
        identity.save(update_fields=['verified_at'])
    save_new_password(identity.user, password)


def validate_new_password(password, user):
    try:
        validate_password(password, user)
    except DjangoValidationError as exc:
        raise ValidationError({'password': exc.messages}, code='invalid_password') from None


def save_new_password(user, password):
    validate_new_password(password, user)
    user.set_password(password)
    user.save(update_fields=['password'])
    PhoneIdentity.objects.filter(user=user).update(session_version=F('session_version') + 1)
    EmailIdentity.objects.filter(user=user).update(session_version=F('session_version') + 1)


@transaction.atomic
def change_password(user_id, current_password, password):
    user_model = get_user_model()
    transaction.guard(user_model, user_id)
    user = user_model.objects.get(pk=user_id)
    if not user.is_active or not user.check_password(current_password):
        raise ValidationError({'current_password': 'Your current password is incorrect.'})
    save_new_password(user, password)
