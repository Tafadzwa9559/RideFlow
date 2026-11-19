import os

from bson import ObjectId
from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework.exceptions import AuthenticationFailed

from accounts.models import PhoneIdentity
from drivers.models import DriverApplication


def configuration():
    if settings.SETTINGS_MODULE != 'rideflow.staging':
        return '', ''
    return os.environ.get('TRIVIA_PASSENGER_TEST_ACTOR', ''), os.environ.get('TRIVIA_PASSENGER_TEST_PROFILE', '')


def passenger_profile(actor_id):
    allowed_actor, profile_id = configuration()
    if actor_id != allowed_actor or actor_id == profile_id or not all(
        ObjectId.is_valid(value) for value in (actor_id, profile_id)
    ):
        raise AuthenticationFailed('Passenger testing session unavailable.')
    actor = get_user_model().objects.filter(pk=ObjectId(actor_id), is_active=True, is_superuser=True, is_staff=True).first()
    identity = PhoneIdentity.objects.select_related('user').filter(
        user_id=ObjectId(profile_id), verified_at__isnull=False,
    ).first()
    if (not actor or not identity or not identity.user.is_active or identity.user.is_staff
            or identity.user.is_superuser or identity.user.has_usable_password()
            or DriverApplication.objects.filter(user=identity.user).exists()):
        raise AuthenticationFailed('Passenger testing session unavailable.')
    return actor, identity
