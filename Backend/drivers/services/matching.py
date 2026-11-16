from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from drivers.models import DriverApplication


def nearby_drivers(ride):
    """Official raw_aggregate with a 2dsphere index; [longitude, latitude]."""
    point = ride.quote.pickup
    return DriverApplication.objects.raw_aggregate([{'$geoNear': {
        'key': 'location',
        'near': {'type': 'Point', 'coordinates': [float(point['longitude']), float(point['latitude'])]},
        'distanceField': 'matching_distance_metres',
        'maxDistance': settings.DRIVER_MATCH_RADIUS_KM * 1000,
        'spherical': True,
        'query': {'status': 'approved', 'availability': 'online',
                  'last_seen': {'$gte': timezone.now()-timedelta(seconds=settings.DRIVER_LOCATION_TTL)}}}}])
