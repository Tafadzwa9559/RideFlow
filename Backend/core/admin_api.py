from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError as DjangoValidationError
from core import transactions as transaction
from django.db.models import Count, Sum, Avg
from django.shortcuts import get_object_or_404
from rest_framework import serializers, viewsets
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import BasePermission, IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.models import AuditEvent, PhoneIdentity
from drivers.models import DriverApplication, Vehicle
from drivers.api.serializers import ApplicationSerializer
from rides.models import Ride, PricingZone, PricingConfiguration, SupportTicket
from rides.api.serializers import RideSerializer
from rides.services.lifecycle import transition


class ResourcePermission(BasePermission):
    def has_permission(self, request, view):
        if not request.user.is_authenticated or not request.user.is_staff:
            return False
        model = view.queryset.model
        action = {'GET': 'view', 'POST': 'add', 'PATCH': 'change', 'PUT': 'change', 'DELETE': 'delete'}.get(request.method)
        return bool(action and request.user.has_perm(f'{model._meta.app_label}.{action}_{model._meta.model_name}'))


class AuditedViewSet(viewsets.ModelViewSet):
    permission_classes = [ResourcePermission]
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']

    @transaction.atomic
    def perform_destroy(self, instance):
        if not hasattr(instance, 'enabled'):
            raise ValidationError('Deletion is not available for this resource.')
        instance.enabled = False
        instance.save(update_fields=['enabled'])
        self.audit(instance, 'configuration.disabled')

    def audit(self, instance, action):
        AuditEvent.objects.create(actor=self.request.user, action=action, target=f'{instance._meta.label}:{instance.pk}',
            summary={'fields': sorted(self.request.data.keys())}, request_id=getattr(self.request, 'request_id', ''))

    @transaction.atomic
    def perform_create(self, serializer):
        instance = serializer.save()
        self.audit(instance, 'configuration.created')

    @transaction.atomic
    def perform_update(self, serializer):
        instance = serializer.save()
        instance.full_clean()
        self.audit(instance, 'configuration.updated')


class ZoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = PricingZone
        fields = '__all__'

    def validate(self, data):
        instance = self.instance or PricingZone()
        for k, v in data.items():
            setattr(instance, k, v)
        try:
            instance.clean()
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages)
        return data


class PriceSerializer(serializers.ModelSerializer):
    class Meta:
        model = PricingConfiguration
        exclude = ['rounding_zwg']

    def validate(self, data):
        minimum = data.get('minimum_offer_usd', getattr(self.instance, 'minimum_offer_usd', None))
        maximum = data.get('maximum_offer_usd', getattr(self.instance, 'maximum_offer_usd', None))
        if minimum is not None and maximum is not None and minimum > maximum:
            raise serializers.ValidationError('Minimum must not exceed maximum.')
        return data


class ZoneViewSet(AuditedViewSet):
    queryset = PricingZone.objects.all().order_by('pk')
    serializer_class = ZoneSerializer


class PriceViewSet(AuditedViewSet):
    queryset = PricingConfiguration.objects.select_related('zone').all().order_by('pk')
    serializer_class = PriceSerializer


class DriverViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = DriverApplication.objects.select_related('active_vehicle', 'user').all().order_by('pk')
    serializer_class = ApplicationSerializer
    permission_classes = [ResourcePermission]


class AdminRideViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Ride.objects.select_related('quote', 'payment__method', 'assigned_driver').all().order_by('-created_at')
    serializer_class = RideSerializer
    from core.filters import RideFilter
    filterset_class = RideFilter
    search_fields = ['quote__pickup__name', 'quote__destination__name']
    ordering_fields = ['created_at', 'completed_at', 'agreed_fare']
    permission_classes = [ResourcePermission]

    def get_queryset(self):
        qs = super().get_queryset()
        if self.request.query_params.get('status'):
            qs = qs.filter(status=self.request.query_params['status'])
        return qs


class TicketSerializer(serializers.ModelSerializer):
    def validate_status(self, value):
        if value == 'resolved':
            raise serializers.ValidationError('Use the resolve action with an investigation reason.')
        return value

    class Meta:
        model = SupportTicket
        fields = '__all__'
        read_only_fields = ['user', 'ride', 'message', 'category', 'created_at']


class TicketViewSet(AuditedViewSet):
    queryset = SupportTicket.objects.all().order_by('-created_at')
    serializer_class = TicketSerializer
    http_method_names = ['get', 'patch', 'head', 'options']


class OverviewView(APIView):
    permission_classes = [IsAdminUser]

    def get(self, request):
        if not request.user.has_perm('drivers.operate_platform'):
            raise PermissionDenied()
        return Response({'rides_by_status': list(Ride.objects.values('status').annotate(count=Count('pk'))),
            'completed_agreed_fares_usd': format(Ride.objects.filter(status='completed', currency='USD').aggregate(total=Sum('agreed_fare'))['total'] or 0, '.2f'),
            'drivers_by_status': list(DriverApplication.objects.values('status').annotate(count=Count('pk'))),
            'open_tickets': SupportTicket.objects.exclude(status='resolved').count(), 'payment_receipt_verified': False})


class AdminCancelView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        get_object_or_404(Ride, pk=pk)
        reason = serializers.CharField(max_length=500).run_validation(request.data.get('reason'))
        return Response(RideSerializer(transition(request.user, pk, 'cancelled', reason, administrative=True)).data)


class AccountStatusView(APIView):
    permission_classes = [IsAdminUser]

    @transaction.atomic
    def post(self, request, pk):
        from core.services.administration import account_status
        active = serializers.BooleanField().run_validation(request.data.get('active'))
        account_status(request.user, pk, active, getattr(request, 'request_id', ''))
        return Response({'active': active})


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = get_user_model()
        fields = ['id', 'first_name', 'last_name', 'is_active', 'date_joined']


class UserViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = get_user_model().objects.filter(is_staff=False).order_by('pk')
    serializer_class = UserSerializer
    permission_classes = [ResourcePermission]


class VehicleReviewView(APIView):
    permission_classes = [IsAdminUser]

    @transaction.atomic
    def post(self, request, pk):
        from core.services.administration import vehicle_review
        approved = serializers.BooleanField().run_validation(request.data.get('approved'))
        vehicle_review(request.user, pk, approved, request_id=getattr(request, 'request_id', ''))
        return Response({'approved': approved})


class VehicleAdminSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicle
        fields = '__all__'


class VehicleViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Vehicle.objects.all().order_by('pk')
    serializer_class = VehicleAdminSerializer
    permission_classes = [ResourcePermission]


class OfferAdminSerializer(serializers.ModelSerializer):
    class Meta:
        from rides.models import RideOffer
        model = RideOffer
        fields = '__all__'


class OfferViewSet(viewsets.ReadOnlyModelViewSet):
    from rides.models import RideOffer
    queryset = RideOffer.objects.all().order_by('-created_at')
    serializer_class = OfferAdminSerializer
    permission_classes = [ResourcePermission]


class AuditSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditEvent
        fields = '__all__'


class AuditViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditEvent.objects.all().order_by('-created_at')
    serializer_class = AuditSerializer
    permission_classes = [ResourcePermission]


class DocumentRequirementSerializer(serializers.ModelSerializer):
    class Meta:
        from drivers.models import DocumentRequirement
        model = DocumentRequirement
        fields = '__all__'


class DocumentRequirementViewSet(AuditedViewSet):
    from drivers.models import DocumentRequirement
    queryset = DocumentRequirement.objects.all().order_by('pk')
    serializer_class = DocumentRequirementSerializer
    filterset_fields = ['scope', 'enabled', 'required']
    search_fields = ['label', 'code']
    ordering_fields = ['code']
