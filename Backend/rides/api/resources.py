from datetime import timedelta, datetime, time
from zoneinfo import ZoneInfo
from django.db.models import Avg, Count, Q, Sum
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, serializers
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from drivers.models import DriverApplication
from drivers.services.eligibility import driver_for, eligible
from rides.models import Ride, RideOffer, Rating, SupportTicket, PricingZone, PricingConfiguration
from rides.api.serializers import PlaceSerializer, QuoteRequestSerializer, RideSerializer
from rides.api.views import visible_rides, passenger_rides, paginate, offer_json
from rides.services.lifecycle import nearby


class OwnTicketSerializer(serializers.ModelSerializer):
    ride_id = serializers.PrimaryKeyRelatedField(queryset=Ride.objects.all(), source='ride', required=False, allow_null=True)

    class Meta:
        model = SupportTicket
        fields = ['id', 'ride_id', 'category', 'message', 'status', 'created_at']
        read_only_fields = ['id', 'status', 'created_at']

    def validate_ride_id(self, value):
        if not visible_rides(self.context['request'].user).filter(pk=value.pk).exists():
            from rest_framework.exceptions import NotFound
            raise NotFound()
        return value


class TicketsView(generics.ListCreateAPIView):
    queryset = SupportTicket.objects.none()
    serializer_class = OwnTicketSerializer
    filterset_fields = ['status', 'category']
    ordering_fields = ['created_at']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return self.queryset
        return SupportTicket.objects.filter(user=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class TicketDetailView(generics.RetrieveAPIView):
    queryset = SupportTicket.objects.none()
    serializer_class = OwnTicketSerializer

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return self.queryset
        return SupportTicket.objects.filter(user=self.request.user)


class ReportView(APIView):
    def post(self, request, pk):
        ride = get_object_or_404(visible_rides(request.user), pk=pk)
        message = serializers.CharField(max_length=2000).run_validation(request.data.get('message'))
        ticket = SupportTicket.objects.create(user=request.user, ride=ride, category='safety', message=message)
        return Response(OwnTicketSerializer(ticket).data, status=201)


class OwnTripsView(generics.ListAPIView):
    queryset = Ride.objects.none()
    serializer_class = RideSerializer
    filterset_fields = ['status', 'quote__category', 'quote__pricing__zone']
    ordering_fields = ['created_at', 'completed_at']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return self.queryset
        return passenger_rides(self.request.user)


class CurrentDriverTripView(APIView):
    def get(self, request):
        app = driver_for(request.user)
        ride = visible_rides(request.user).filter(assigned_driver=app).exclude(status__in=['completed', 'cancelled', 'expired']).first()
        return Response({'ride': RideSerializer(ride).data if ride else None})


class RideReadView(APIView):
    mode = 'status'

    def get(self, request, pk):
        ride = get_object_or_404(visible_rides(request.user), pk=pk)
        if self.mode == 'status':
            return Response({'id': ride.pk, 'status': ride.status, 'sequence': ride.sequence, 'updated_at': ride.updated_at})
        if self.mode == 'tracking':
            active = ride.status not in ['completed', 'cancelled', 'expired']
            location = ride.locations.order_by('-created_at').values('latitude', 'longitude', 'created_at').first() if active else None
            return Response({'ride_id': ride.pk, 'status': ride.status, 'location': location})
        if self.mode == 'receipt':
            if ride.status != 'completed':
                raise ValidationError('A completed trip is required.', code='INVALID_RIDE_STATUS')
            return Response({'ride_id': ride.pk, 'currency': ride.currency, 'agreed_fare': format(ride.agreed_fare, '.2f'),
                'payment_preference': ride.payment_preference, 'payment_receipt_verified': False, 'platform_processed_payment': False,
                'notice': 'Trip summary only. Pay the driver directly; receipt of funds is unverified.',
                'started_at': ride.started_at, 'completed_at': ride.completed_at,
                'trip_duration_seconds': int((ride.completed_at-ride.started_at).total_seconds()) if ride.started_at and ride.completed_at else None})


class OfferDetailView(APIView):
    def get(self, request, pk):
        offer = get_object_or_404(RideOffer.objects.select_related('driver__user', 'vehicle', 'ride'), pk=pk, driver__isnull=False)
        if offer.ride.passenger_id != request.user.pk and offer.driver.user_id != request.user.pk:
            from rest_framework.exceptions import NotFound
            raise NotFound()
        return Response(offer_json(offer))


class RequestDetailView(APIView):
    def get(self, request, pk):
        app = driver_for(request.user)
        eligible(app, online=True)
        ride = get_object_or_404(Ride.objects.select_related('quote__pricing__zone', 'payment__method'), pk=pk, status='searching', currency='USD', expires_at__gt=timezone.now())
        if not nearby(app, ride) or hasattr(app, 'active_assignment'):
            raise PermissionDenied('Request is outside current eligibility.', code='DRIVER_UNAVAILABLE')
        return Response(RideSerializer(ride).data)


class RatingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Rating
        fields = ['id', 'score', 'comment', 'created_at']
        read_only_fields = fields


class RatingsView(generics.ListAPIView):
    queryset = Rating.objects.none()
    serializer_class = RatingSerializer
    ordering_fields = ['created_at', 'score']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return self.queryset
        driver_id = self.kwargs.get('pk')
        if driver_id:
            app = get_object_or_404(DriverApplication, pk=driver_id, status='approved')
            # Driver reviews are visible to their trip counterparties/offer owners only.
            user = self.request.user
            if user.pk != app.user_id and not Ride.objects.filter(Q(assigned_driver=app) | Q(counteroffers__driver=app), passenger=user).exists():
                raise PermissionDenied('A trip or offer relationship is required.')
            return Rating.objects.filter(subject=app.user).order_by('-created_at')
        return Rating.objects.filter(subject=self.request.user).order_by('-created_at')


class EarningsSummaryView(APIView):
    def get(self, request):
        app = driver_for(request.user)
        eligible(app)
        today = timezone.localdate()
        qs = app.trips.filter(status='completed', currency='USD')
        totals = {}
        for period, start in [('day', today), ('week', today-timedelta(days=today.weekday())), ('month', today.replace(day=1))]:
            totals[period] = format(qs.filter(completed_at__gte=datetime.combine(start, time.min, tzinfo=ZoneInfo('Africa/Harare'))).aggregate(total=Sum('agreed_fare'))['total'] or 0, '.2f')
        return Response({'currency': 'USD', 'totals': totals, 'completed_trips': qs.count(), 'payment_receipt_verified': False, 'commission': None})


class EarningsHistoryView(generics.ListAPIView):
    queryset = Ride.objects.none()
    serializer_class = RideSerializer
    ordering_fields = ['completed_at', 'agreed_fare']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return self.queryset
        app = driver_for(self.request.user)
        eligible(app)
        return visible_rides(self.request.user).filter(assigned_driver=app, status='completed')


class ServiceAreaSerializer(serializers.ModelSerializer):
    class Meta:
        model = PricingZone
        fields = ['id', 'name', 'south', 'north', 'west', 'east']


class AreaDetailView(generics.RetrieveAPIView):
    queryset = PricingZone.objects.filter(enabled=True)
    serializer_class = ServiceAreaSerializer


class CategorySerializer(serializers.Serializer):
    id = serializers.CharField()
    name = serializers.CharField()


class CategoriesView(APIView):
    def get(self, request, pk=None):
        categories = sorted(set(PricingConfiguration.objects.filter(enabled=True, zone__enabled=True).values_list('category', flat=True)))
        if pk:
            if pk not in categories:
                from rest_framework.exceptions import NotFound
                raise NotFound()
            return Response({'id': pk, 'name': 'Trivia ' + pk})
        return Response({'results': [{'id': c, 'name': 'Trivia ' + c} for c in categories]})


class ReverseGeocodeView(APIView):
    throttle_scope = 'places'

    def get(self, request):
        from rides.services.routing import reverse_geocode
        point = PlaceSerializer(data={'name': 'coordinate', **request.query_params.dict()})
        point.is_valid(raise_exception=True)
        return Response(reverse_geocode(point.validated_data))


class RouteEstimateView(APIView):
    throttle_scope = 'quotes'

    def post(self, request):
        from rides.services.routing import driving_route
        data = QuoteRequestSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        pickup, destination = data.validated_data['pickup'], data.validated_data['destination']
        if pickup['latitude'] == destination['latitude'] and pickup['longitude'] == destination['longitude']:
            raise ValidationError('Pickup and destination must differ.')
        zones = list(PricingZone.objects.filter(enabled=True))
        route = driving_route(pickup, destination)
        if not any(z.contains(pickup) and z.contains(destination) and all(z.contains({'latitude': p[1], 'longitude': p[0]}) for p in route['geometry']) for z in zones):
            raise ValidationError('Route is outside enabled coverage.', code='OUTSIDE_SERVICE_AREA')
        return Response(route)

TicketSerializer = OwnTicketSerializer
