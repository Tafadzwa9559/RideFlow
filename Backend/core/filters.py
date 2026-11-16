from django_filters import rest_framework as filters
from bson import ObjectId
from rest_framework.exceptions import ValidationError
from rides.models import Ride
from drivers.models import DriverApplication
from notifications.models import Notification


class ObjectIdFilter(filters.CharFilter):
    def filter(self, queryset, value):
        if value and not ObjectId.is_valid(str(value)):
            raise ValidationError({self.field_name: 'Enter a 24-character ObjectId.'})
        return super().filter(queryset, value)


class RideFilter(filters.FilterSet):
    created_after = filters.IsoDateTimeFilter(field_name='created_at', lookup_expr='gte')
    created_before = filters.IsoDateTimeFilter(field_name='created_at', lookup_expr='lte')
    category = filters.CharFilter(field_name='quote__category')
    service_area = ObjectIdFilter(field_name='quote__pricing__zone_id')

    class Meta:
        model = Ride
        fields = ['status', 'passenger', 'assigned_driver']


class DriverFilter(filters.FilterSet):
    category = filters.CharFilter(field_name='active_vehicle__category')
    submitted_after = filters.IsoDateTimeFilter(field_name='submitted_at', lookup_expr='gte')
    submitted_before = filters.IsoDateTimeFilter(field_name='submitted_at', lookup_expr='lte')

    class Meta:
        model = DriverApplication
        fields = ['status', 'availability']


class NotificationFilter(filters.FilterSet):
    unread = filters.BooleanFilter(field_name='read_at', lookup_expr='isnull')
    type = filters.CharFilter(field_name='envelope__type')
    created_after = filters.IsoDateTimeFilter(field_name='created_at', lookup_expr='gte')
    created_before = filters.IsoDateTimeFilter(field_name='created_at', lookup_expr='lte')

    class Meta:
        model = Notification
        fields = []
