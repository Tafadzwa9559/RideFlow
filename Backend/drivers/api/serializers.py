from rest_framework import serializers
from drivers.models import DriverApplication, Vehicle


class VehicleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicle
        fields = ['make', 'model', 'year', 'colour', 'registration', 'capacity', 'category']
        extra_kwargs = {'registration': {'validators': []}}

    def validate_registration(self, value):
        return value.strip().upper()


class ApplicationSerializer(serializers.ModelSerializer):
    vehicle = VehicleSerializer(required=False)

    class Meta:
        model = DriverApplication
        fields = ['id', 'status', 'legal_name', 'licence_number', 'licence_class', 'licence_expires', 'experience_years', 'vehicle', 'rejection_reason', 'resubmission_allowed', 'availability']
        read_only_fields = ['id', 'status', 'rejection_reason', 'resubmission_allowed', 'availability']


class LocationSerializer(serializers.Serializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, min_value=-90, max_value=90)
    longitude = serializers.DecimalField(max_digits=10, decimal_places=6, min_value=-180, max_value=180)
