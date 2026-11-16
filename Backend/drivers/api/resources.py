from rest_framework.parsers import MultiPartParser, FormParser
from django.conf import settings
from django.db import transaction, IntegrityError
from django.db.models import Avg, Count, Sum
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.models import AuditEvent
from core.uploads import validate_image
from drivers.models import DriverApplication, DriverDocument, Vehicle, VehicleDocument, DocumentRequirement
from drivers.api.serializers import ApplicationSerializer, VehicleSerializer
from drivers.services.eligibility import driver_for, eligible
from rides.models import Ride, Rating


def editable(app):
    if app.status not in ['draft', 'rejected', 'approved'] or hasattr(app, 'active_assignment'):
        raise ValidationError('Application is under review or has an active trip.', code='INVALID_RIDE_STATUS')


class DocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = DriverDocument
        fields = ['id', 'requirement', 'content_type', 'expires_on', 'approved', 'created_at']
        read_only_fields = fields


class DocumentListView(generics.ListAPIView):
    queryset = DriverDocument.objects.none()
    serializer_class = DocumentSerializer

    def get_queryset(self):
        return DriverDocument.objects.filter(application=driver_for(self.request.user)).order_by('pk')


class DocumentDeleteView(generics.DestroyAPIView):
    def get(self, request, pk):
        doc = get_object_or_404(DriverDocument, pk=pk, application__user=request.user)
        response = FileResponse(doc.file.open('rb'), content_type=doc.content_type, as_attachment=True, filename='document')
        response['Cache-Control'] = 'private, no-store'
        return response

    serializer_class = DocumentSerializer

    @transaction.atomic
    def delete(self, request, pk):
        app = driver_for(request.user, lock=True)
        if app.status != 'draft':
            raise ValidationError('Only draft documents can be removed.')
        doc = get_object_or_404(DriverDocument, pk=pk, application=app)
        doc.delete()
        return Response(status=204)


class ReviewHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditEvent
        fields = ['id', 'action', 'summary', 'created_at']


class ReviewHistoryView(generics.ListAPIView):
    queryset = AuditEvent.objects.none()
    serializer_class = ReviewHistorySerializer

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return self.queryset
        app = driver_for(self.request.user)
        return AuditEvent.objects.filter(target=str(app.pk), action__startswith='driver.').order_by('-created_at')


class DriverProfileView(APIView):
    serializer_class = ApplicationSerializer

    def get(self, request):
        return Response(ApplicationSerializer(driver_for(request.user)).data)

    def patch(self, request):
        from drivers.services.onboarding import save_draft
        data = ApplicationSerializer(data=request.data, partial=True)
        data.is_valid(raise_exception=True)
        return Response(ApplicationSerializer(save_draft(request.user, data.validated_data, allow_revision=True)).data)


class StatisticsView(APIView):
    def get(self, request):
        app = driver_for(request.user)
        completed = app.trips.filter(status='completed')
        return Response({'completed_trips': completed.count(), 'cancelled_trips': app.trips.filter(status='cancelled').count(),
                         'rating': Rating.objects.filter(subject=request.user).aggregate(value=Avg('score'))['value']})


class FleetVehicleSerializer(VehicleSerializer):
    class Meta(VehicleSerializer.Meta):
        fields = ['id', *VehicleSerializer.Meta.fields, 'approved', 'archived']
        read_only_fields = ['id', 'approved', 'archived']


class FleetViewSet(viewsets.ModelViewSet):
    serializer_class = FleetVehicleSerializer
    queryset = Vehicle.objects.all()
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']
    search_fields = ['make', 'model', 'registration']
    ordering_fields = ['id', 'year']

    def get_queryset(self):
        return self.queryset.filter(application__user=self.request.user, archived=False).order_by('pk')

    @transaction.atomic
    def perform_create(self, serializer):
        app = driver_for(self.request.user, lock=True)
        editable(app)
        registration = serializer.validated_data['registration']
        if Vehicle.objects.filter(registration=registration).exists():
            raise ValidationError({'registration': 'Registration already exists.'})
        try:
            with transaction.atomic():
                vehicle = serializer.save(application=app, approved=False)
        except IntegrityError:
            raise ValidationError({'registration': 'Registration already exists.'})
        if not app.active_vehicle_id:
            app.active_vehicle = vehicle
            app.save(update_fields=['active_vehicle'])

    @transaction.atomic
    def perform_update(self, serializer):
        app = driver_for(self.request.user, lock=True)
        editable(app)
        if Vehicle.objects.filter(registration=serializer.validated_data.get('registration', serializer.instance.registration)).exclude(pk=serializer.instance.pk).exists():
            raise ValidationError({'registration': 'Registration already exists.'})
        serializer.instance.refresh_from_db()
        if serializer.instance.archived:
            from rest_framework.exceptions import NotFound
            raise NotFound()
        try:
            with transaction.atomic():
                serializer.save(approved=False)
        except IntegrityError:
            raise ValidationError({'registration': 'Registration already exists.'})
        if app.active_vehicle_id == serializer.instance.pk:
            app.availability = 'offline'
            app.save(update_fields=['availability'])

    @transaction.atomic
    def perform_destroy(self, instance):
        app = driver_for(self.request.user, lock=True)
        editable(app)
        instance.archived = True
        instance.approved = False
        instance.save(update_fields=['archived', 'approved'])
        if app.active_vehicle_id == instance.pk:
            app.active_vehicle = None
            app.availability = 'offline'
            app.save(update_fields=['active_vehicle', 'availability'])

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def activate(self, request, pk=None):
        app = driver_for(request.user, lock=True)
        editable(app)
        vehicle = self.get_object()
        if app.status != 'approved' or not vehicle.approved:
            raise PermissionDenied('Approved driver and vehicle required.', code='VEHICLE_NOT_APPROVED')
        app.active_vehicle = vehicle
        app.availability = 'offline'
        app.save(update_fields=['active_vehicle', 'availability'])
        return Response(self.get_serializer(vehicle).data)


class VehicleDocumentSerializer(DocumentSerializer):
    class Meta(DocumentSerializer.Meta):
        model = VehicleDocument


class VehicleDocumentUploadSerializer(serializers.Serializer):
    requirement = serializers.SlugField()
    file = serializers.FileField()
    expires_on = serializers.DateField(required=False, allow_null=True)


class VehicleDocumentsView(APIView):
    parser_classes = [MultiPartParser, FormParser]
    def get(self, request, vehicle_id):
        vehicle = get_object_or_404(Vehicle, pk=vehicle_id, application__user=request.user, archived=False)
        from rides.api.views import paginate
        return paginate(request, vehicle.documents.order_by('pk'), VehicleDocumentSerializer)

    @transaction.atomic
    def post(self, request, vehicle_id):
        app = driver_for(request.user, lock=True)
        editable(app)
        vehicle = get_object_or_404(Vehicle, pk=vehicle_id, application=app, archived=False)
        data = VehicleDocumentUploadSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        req = get_object_or_404(DocumentRequirement, pk=data.validated_data['requirement'], enabled=True, scope='vehicle')
        expires = data.validated_data.get('expires_on')
        if (req.expiry_required and not expires) or (expires and expires < timezone.localdate()):
            raise ValidationError({'expires_on': 'A current expiry date is required.'})
        file = data.validated_data['file']
        kind = validate_image(file)
        doc, _ = VehicleDocument.objects.update_or_create(vehicle=vehicle, requirement=req, defaults={'file': file, 'content_type': kind, 'expires_on': expires, 'approved': False})
        vehicle.approved = False
        vehicle.save(update_fields=['approved'])
        app.availability = 'offline'
        app.save(update_fields=['availability'])
        return Response(VehicleDocumentSerializer(doc).data, status=201)


class VehicleDocumentDetailView(APIView):
    def get(self, request, vehicle_id, pk):
        doc = get_object_or_404(VehicleDocument, pk=pk, vehicle_id=vehicle_id)
        if doc.vehicle.application.user_id != request.user.pk and not request.user.has_perm('drivers.review_driver'):
            raise PermissionDenied()
        response = FileResponse(doc.file.open('rb'), as_attachment=True, filename='vehicle-document', content_type=doc.content_type)
        response['Cache-Control'] = 'private, no-store'
        return response

    @transaction.atomic
    def delete(self, request, vehicle_id, pk):
        app = driver_for(request.user, lock=True)
        editable(app)
        doc = get_object_or_404(VehicleDocument, pk=pk, vehicle_id=vehicle_id, vehicle__application=app)
        vehicle = doc.vehicle
        doc.delete()
        vehicle.approved = False
        vehicle.save(update_fields=['approved'])
        app.availability = 'offline'
        app.save(update_fields=['availability'])
        return Response(status=204)


class AvailabilityDetailView(APIView):
    def get(self, request):
        app = driver_for(request.user)
        return Response({'status': app.availability, 'last_seen': app.last_seen, 'location_fresh': bool(app.last_seen and (timezone.now()-app.last_seen).total_seconds() < settings.DRIVER_LOCATION_TTL),
                         'active_vehicle_id': app.vehicle.pk if hasattr(app, 'vehicle') else None})
