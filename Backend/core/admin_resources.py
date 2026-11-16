from django.contrib.auth import get_user_model
from core import transactions as transaction
from django.db.models import Count, Sum, F
from django.db.models.functions import TruncDate
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import serializers, mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.models import AuditEvent
from core.admin_api import ResourcePermission, DriverViewSet, VehicleViewSet, UserSerializer, UserViewSet, TicketViewSet, AdminRideViewSet
from core.services.administration import account_status, request_changes, vehicle_review, audit
from core.filters import DriverFilter, RideFilter
from drivers.services.onboarding import review
from drivers.api.serializers import ApplicationSerializer
from rides.models import Ride, SupportTicket


class ReasonSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=500)


def reason(request, required=True):
    return serializers.CharField(max_length=500, required=required, default='' if not required else serializers.empty).run_validation(request.data.get('reason', serializers.empty))


class PassengerViewSet(mixins.UpdateModelMixin, UserViewSet):
    http_method_names = ['get', 'patch', 'post', 'head', 'options']
    filterset_fields = ['is_active']
    search_fields = ['first_name', 'last_name']
    ordering_fields = ['id', 'date_joined']

    def get_permissions(self):
        if self.action in ['suspend', 'reactivate']:
            from rest_framework.permissions import IsAdminUser
            return [IsAdminUser()]
        return super().get_permissions()

    @transaction.atomic
    def perform_update(self, serializer):
        # Status changes must use the audited actions; administrative flags are never writable.
        if set(self.request.data) - {'first_name', 'last_name'}:
            raise ValidationError('Only personal names can be edited here.')
        user = serializer.save()
        audit(self.request.user, 'account.profile', user, {'fields': sorted(self.request.data)}, getattr(self.request, 'request_id', ''))

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        user = account_status(request.user, pk, False, getattr(request, 'request_id', ''))
        return Response(self.get_serializer(user).data)

    @action(detail=True, methods=['post'])
    def reactivate(self, request, pk=None):
        user = account_status(request.user, pk, True, getattr(request, 'request_id', ''))
        return Response(self.get_serializer(user).data)


class ManagedDriverViewSet(DriverViewSet):
    filterset_class = DriverFilter
    search_fields = ['legal_name']
    ordering_fields = ['created_at', 'submitted_at', 'status']

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        return Response(ApplicationSerializer(review(request.user, pk, 'suspended', reason(request), getattr(request, 'request_id', ''))).data)

    @action(detail=True, methods=['post'])
    def reactivate(self, request, pk=None):
        return Response(ApplicationSerializer(review(request.user, pk, 'approved', '', getattr(request, 'request_id', ''))).data)

    def get_permissions(self):
        if self.action in ['suspend', 'reactivate', 'approve', 'reject', 'request_changes']:
            return [VerificationPermission()]
        return super().get_permissions()


class VerificationPermission(ResourcePermission):
    def has_permission(self, request, view):
        return bool(request.user.is_authenticated and request.user.is_staff and request.user.has_perm('drivers.review_driver'))


class ApplicationAdminViewSet(ManagedDriverViewSet):
    suspend = None
    reactivate = None
    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        return Response(ApplicationSerializer(review(request.user, pk, 'approved', '', getattr(request, 'request_id', ''))).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        return Response(ApplicationSerializer(review(request.user, pk, 'rejected', reason(request), getattr(request, 'request_id', ''))).data)

    @action(detail=True, methods=['post'], url_path='request-changes')
    def request_changes(self, request, pk=None):
        return Response(ApplicationSerializer(request_changes(request.user, pk, reason(request), getattr(request, 'request_id', ''))).data)


class ManagedVehicleViewSet(VehicleViewSet):
    filterset_fields = ['approved', 'archived', 'category', 'application']
    search_fields = ['registration', 'make', 'model']
    ordering_fields = ['id', 'year']

    def get_permissions(self):
        return [VerificationPermission()] if self.action in ['approve', 'reject'] else super().get_permissions()

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        return Response(self.get_serializer(vehicle_review(request.user, pk, True, request_id=getattr(request, 'request_id', ''))).data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        return Response(self.get_serializer(vehicle_review(request.user, pk, False, reason(request), getattr(request, 'request_id', ''))).data)


class DisputeViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = TicketViewSet.queryset
    serializer_class = TicketViewSet.serializer_class
    permission_classes = [ResourcePermission]
    http_method_names = ['get', 'post', 'head', 'options']
    audit = TicketViewSet.audit
    perform_update = TicketViewSet.perform_update
    filterset_fields = ['status', 'category']
    ordering_fields = ['created_at', 'status']

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def resolve(self, request, pk=None):
        if not request.user.has_perm('rides.change_supportticket'):
            raise PermissionDenied()
        item = get_object_or_404(SupportTicket.objects.all(), pk=pk)
        resolution = reason(request)
        item.status = 'resolved'
        item.save(update_fields=['status'])
        audit(request.user, 'ticket.resolved', item, {'resolution': resolution}, getattr(request, 'request_id', ''))
        return Response(self.get_serializer(item).data)

    def get_permissions(self):
        if self.action == 'resolve':
            from rest_framework.permissions import IsAdminUser
            return [IsAdminUser()]
        return super().get_permissions()


class AdminTimelineView(APIView):
    def get(self, request, pk):
        if not request.user.is_staff or not request.user.has_perm('rides.view_ride'):
            raise PermissionDenied()
        ride = get_object_or_404(Ride, pk=pk)
        from rides.api.views import paginate
        from core.contracts import TimelineEventSerializer
        return paginate(request, ride.events.order_by('sequence'), TimelineEventSerializer)


class AnalyticsView(APIView):
    kind = 'ride-analytics'

    def get(self, request):
        if not request.user.is_staff or not request.user.has_perm('drivers.operate_platform'):
            raise PermissionDenied()
        from drivers.models import DriverApplication
        if self.kind == 'driver-analytics':
            return Response({'results': list(DriverApplication.objects.values('status', 'availability').annotate(count=Count('pk')).order_by('status', 'availability'))})
        if self.kind == 'platform-activity':
            from core.admin_api import AuditSerializer
            from rides.api.views import paginate
            return paginate(request, AuditEvent.objects.order_by('-created_at'), AuditSerializer)
        from core.filters import RideFilter
        filtered = RideFilter(request.query_params, queryset=Ride.objects.filter(currency='USD'))
        if not filtered.is_valid():
            raise ValidationError(filtered.errors)
        qs = filtered.qs
        from datetime import timedelta
        from zoneinfo import ZoneInfo
        from core.contracts import RideAnalyticsRowSerializer
        from rides.api.views import paginate
        # Zimbabwe has UTC+02 without DST. Add the market offset before truncating
        # in UTC, avoiding a dependency on optional MySQL timezone tables.
        rows = qs.annotate(date=TruncDate(F('created_at') + timedelta(hours=2), tzinfo=ZoneInfo('UTC'))).values('date', 'status').annotate(count=Count('pk'), agreed_fares=Sum('agreed_fare')).order_by('date', 'status')
        response = paginate(request, rows, RideAnalyticsRowSerializer)
        response.data['payment_receipt_verified'] = False
        return response


class ReportsView(APIView):
    kind = 'rides'

    def get(self, request):
        if not request.user.is_staff or not request.user.has_perm('drivers.operate_platform'):
            raise PermissionDenied()
        from drivers.models import DriverApplication
        from core.admin_api import UserSerializer
        from rides.api.serializers import RideSerializer
        from rides.api.views import paginate
        from core.filters import RideFilter, DriverFilter
        if self.kind == 'drivers':
            filtered = DriverFilter(request.query_params, queryset=DriverApplication.objects.select_related('active_vehicle').order_by('pk'))
            if not filtered.is_valid():
                raise ValidationError(filtered.errors)
            return paginate(request, filtered.qs, ApplicationSerializer)
        if self.kind == 'passengers':
            return paginate(request, get_user_model().objects.filter(is_staff=False).order_by('pk'), UserSerializer)
        filtered = RideFilter(request.query_params, queryset=Ride.objects.select_related('quote', 'payment__method').order_by('-created_at'))
        if not filtered.is_valid():
            raise ValidationError(filtered.errors)
        qs = filtered.qs
        if self.kind == 'earnings':
            qs = qs.filter(status='completed', currency='USD')
        return paginate(request, qs, RideSerializer)
