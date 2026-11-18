from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAdminUser
from django.conf import settings
from core import transactions as transaction
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from drivers.models import DriverApplication, DriverDocument, DocumentRequirement
from drivers.services.eligibility import driver_for, eligible
from drivers.services.onboarding import save_draft, submit, review
from .serializers import ApplicationSerializer, LocationSerializer


class ApplicationView(APIView):
    def get(self, request):
        app = DriverApplication.objects.filter(user=request.user).first()
        return Response(ApplicationSerializer(app).data if app else {'status': 'notRegistered'})

    def patch(self, request):
        serializer = ApplicationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(ApplicationSerializer(save_draft(request.user, serializer.validated_data)).data)

    post = patch


class SubmitView(APIView):
    def post(self, request):
        return Response(ApplicationSerializer(submit(request.user)).data)


class DocumentView(APIView):
    parser_classes = [MultiPartParser, FormParser]
    def get(self, request):
        from drivers.api.resources import DocumentSerializer
        from rides.api.views import paginate
        return paginate(request, driver_for(request.user).documents.order_by('pk'), DocumentSerializer)

    @transaction.atomic
    def post(self, request):
        app = driver_for(request.user, lock=True)
        if app.status != 'draft':
            raise ValidationError('Documents can only be changed in draft.')
        req = get_object_or_404(DocumentRequirement, pk=request.data.get('requirement'), enabled=True, scope='driver')
        file = request.FILES.get('file')
        if not file or file.size > settings.DRIVER_DOCUMENT_MAX_BYTES:
            raise ValidationError('A file within the upload size limit is required.')
        # Validate decoded raster content rather than trusting MIME or extension.
        from PIL import Image, UnidentifiedImageError
        try:
            with Image.open(file) as image:
                if image.format not in ['JPEG', 'PNG'] or image.width * image.height > 25000000:
                    raise ValueError()
                content_type = 'image/jpeg' if image.format == 'JPEG' else 'image/png'
                image.verify()
        except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
            raise ValidationError('Upload a valid JPEG or PNG document photograph.')
        file.seek(0)
        expiry = serializers.DateField(required=req.expiry_required, allow_null=not req.expiry_required, **({'default': None} if not req.expiry_required else {}))
        expires_on = expiry.run_validation(request.data.get('expires_on', serializers.empty))
        if expires_on is serializers.empty:
            expires_on = None
        if expires_on and expires_on < timezone.localdate():
            raise ValidationError('Document expired.')
        doc, _ = DriverDocument.objects.update_or_create(application=app, requirement=req, defaults={
            'file': file, 'content_type': content_type, 'expires_on': expires_on, 'approved': False})
        return Response({'id': doc.pk, 'requirement': req.pk}, status=201)


class DocumentDownloadView(APIView):
    def get(self, request, pk):
        doc = get_object_or_404(DriverDocument, pk=pk)
        if doc.application.user_id != request.user.pk and not request.user.has_perm('drivers.review_driver'):
            raise PermissionDenied()
        response = FileResponse(doc.file.open('rb'), content_type=doc.content_type, as_attachment=True, filename='document')
        response['Cache-Control'] = 'private, no-store'
        response['X-Content-Type-Options'] = 'nosniff'
        return response


class RequirementsView(APIView):
    def get(self, request):
        return Response({'results': list(DocumentRequirement.objects.filter(enabled=True).values('code', 'label', 'required', 'expiry_required', 'scope'))})


class AvailabilityView(APIView):
    @transaction.atomic
    def post(self, request, action=None):
        app = driver_for(request.user, lock=True)
        online = action == 'go-online' if action else serializers.BooleanField().run_validation(request.data.get('online'))
        if hasattr(app, 'active_assignment'):
            raise ValidationError('Availability cannot change during an assigned trip.')
        if online:
            eligible(app)
            if not app.last_seen or (timezone.now() - app.last_seen).total_seconds() > settings.DRIVER_LOCATION_TTL:
                raise ValidationError('Publish a fresh location before going online.')
        app.availability = 'online' if online else 'offline'
        app.save(update_fields=['availability', 'updated_at'])
        return Response({'status': app.availability})


class LocationView(APIView):
    @transaction.atomic
    def post(self, request):
        app = driver_for(request.user, lock=True)
        eligible(app)
        data = LocationSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        if app.last_seen and (timezone.now() - app.last_seen).total_seconds() < settings.DRIVER_LOCATION_MIN_INTERVAL:
            from rest_framework.exceptions import Throttled
            raise Throttled(wait=settings.DRIVER_LOCATION_MIN_INTERVAL)
        app.latitude = data.validated_data['latitude']
        app.longitude = data.validated_data['longitude']
        app.last_seen = timezone.now()
        app.save(update_fields=['latitude', 'longitude', 'last_seen', 'updated_at'])
        from rides.services.lifecycle import publish_location
        transaction.on_commit(lambda: publish_location(app), robust=True)
        return Response({'last_seen': app.last_seen})


class ReviewView(APIView):
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        get_object_or_404(DriverApplication, pk=pk)
        class ReviewSerializer(serializers.Serializer):
            decision = serializers.ChoiceField(choices=['underReview', 'approved', 'rejected', 'suspended'])
            reason = serializers.CharField(max_length=500, required=False, default='', allow_blank=True)
        data = ReviewSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        app = review(request.user, pk, request_id=getattr(request, 'request_id', ''), **data.validated_data)
        return Response(ApplicationSerializer(app).data)
