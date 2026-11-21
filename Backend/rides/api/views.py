from core.identifiers import ObjectIdSerializerField
from core.contracts import SelectionSerializer
from core import transactions as transaction
from django.db.models import Q, Sum, Avg, Count
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView
from drivers.services.eligibility import driver_for, eligible
from rides.services.intercity import CATEGORY
from rides.services.courier import CATEGORY as COURIER
from rides.models import Ride, RideOffer, Rating, SupportTicket, SavedPlace, PricingZone
from rides.services.booking import book, quote_route
from rides.services.lifecycle import make_offer, select_offer, transition, withdraw, nearby, emit, update_offer
from rides.services.routing import search_places
from .serializers import BookingRequestSerializer, QuoteRequestSerializer, RideSerializer, quote_json, PlaceSerializer


def normalize_offer_decision(value):
    if value is None:
        return 'counteroffer'
    normalized = str(value).strip().lower()
    aliases = {
        'accept_passenger_fare': 'accept',
        'accept-passenger-fare': 'accept',
        'counteroffer': 'counteroffer',
        'accept': 'accept',
        'decline': 'decline',
        'decline_request': 'decline',
    }
    return aliases.get(normalized, normalized)


def offer_json(offer):
    app = offer.driver
    vehicle = offer.vehicle
    return {'id': str(offer.pk), 'driver_name': app.user.get_full_name(),
        'vehicle': f'{vehicle.make} {vehicle.model}', 'colour': vehicle.colour, 'registration': vehicle.registration,
        'fare_cents': int(offer.amount * 100), 'currency': 'USD', 'status': offer.status,
        'rating': Rating.objects.filter(subject=app.user).aggregate(v=Avg('score'))['v'],
        'completed_trips': app.trips.filter(status='completed').count(), 'pickup_minutes': offer.pickup_minutes,
        'verified': app.status == 'approved', 'expires_at': offer.expires_at, 'note': offer.note}


class OfferSerializer(serializers.Serializer):
    fare_cents = serializers.IntegerField(min_value=1, max_value=999999999999, required=False)
    note = serializers.CharField(max_length=250, required=False, default='', allow_blank=True)
    decision = serializers.CharField(required=False, allow_blank=True, default='counteroffer')
    pickup_minutes = serializers.IntegerField(min_value=1, max_value=180, required=False, allow_null=True)

    def validate(self, data):
        data['decision'] = normalize_offer_decision(data.get('decision', 'counteroffer'))
        if data['decision'] not in {'accept', 'decline', 'counteroffer'}:
            raise serializers.ValidationError({'decision': 'Choose accept, decline or counteroffer.'})
        if data['decision'] == 'counteroffer' and 'fare_cents' not in data:
            raise serializers.ValidationError({'fare_cents': 'Required for a counteroffer.'})
        if data['decision'] == 'accept' and 'fare_cents' in data:
            data['fare_cents'] = int(data['fare_cents'])
        return data


class DriverRequestDeclineView(APIView):
    def post(self, request, pk):
        app = driver_for(request.user)
        eligible(app, online=True)
        ride = get_object_or_404(Ride.objects.select_related('quote__pricing__zone'), pk=pk, status='searching', currency='USD', expires_at__gt=timezone.now())
        if not nearby(app, ride) or hasattr(app, 'active_assignment'):
            raise PermissionDenied('Request is outside current eligibility.', code='DRIVER_UNAVAILABLE')
        if RideOffer.objects.filter(ride=ride, driver=app, status='declined').exists():
            return Response({'id': str(ride.pk), 'status': 'declined', 'message': 'This request was already declined by this driver.'})
        offer = make_offer(request.user, str(ride.pk), None, decision='decline', note='Driver declined this request.')
        return Response({'id': str(ride.pk), 'offer_id': str(offer.pk), 'status': offer.status})


class RideSyncView(APIView):
    def get(self, request, pk):
        ride = get_object_or_404(visible_rides(request.user), pk=pk)
        return Response({
            'id': str(ride.pk),
            'status': ride.status,
            'assigned_driver_id': str(ride.assigned_driver_id) if ride.assigned_driver_id else None,
            'assigned_vehicle_id': str(ride.assigned_vehicle_id) if ride.assigned_vehicle_id else None,
            'agreed_fare': str(ride.agreed_fare) if ride.agreed_fare is not None else None,
            'payment_preference': ride.payment_preference,
            'current_trip_stage': ride.status,
            'latest_sequence': ride.sequence,
            'server_timestamp': timezone.now().isoformat(),
            'pending_actions': {'searching': ['await_driver_offer'], 'assigned': ['await_driver_arrival'], 'arriving': ['await_driver_arrival'], 'arrived': ['await_trip_start'], 'inProgress': ['await_trip_completion']}.get(ride.status, []),
            'request_expires_at': ride.expires_at,
            'updated_at': ride.updated_at,
        })


class OfferPatchSerializer(serializers.Serializer):
    fare_cents = serializers.IntegerField(min_value=1, max_value=999999999999, required=False)
    note = serializers.CharField(max_length=250, required=False, allow_blank=True)
    pickup_minutes = serializers.IntegerField(min_value=1, max_value=180, required=False, allow_null=True)

    def validate(self, data):
        if not data:
            raise serializers.ValidationError('Provide fare_cents, note or pickup_minutes.')
        return data


class OfferUpdateView(APIView):
    def patch(self, request, pk):
        get_object_or_404(RideOffer, pk=pk)
        data = OfferPatchSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        offer = update_offer(request.user, pk, data.validated_data)
        return Response({'id': str(offer.pk), 'status': offer.status, 'fare_cents': int(offer.amount * 100)})


def passenger_rides(user):
    return Ride.objects.select_related('quote', 'payment__method', 'assigned_driver').filter(passenger=user).order_by('-created_at')


def visible_rides(user):
    return Ride.objects.select_related('quote', 'payment__method', 'assigned_driver').filter(Q(passenger=user) | Q(assigned_driver__user=user)).order_by('-created_at')


def paginate(request, qs, serializer=RideSerializer):
    paginator = PageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    return paginator.get_paginated_response(serializer(page, many=True).data)


class QuoteView(APIView):
    throttle_scope = 'quotes'

    def post(self, request):
        serializer = QuoteRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(quote_json(quote_route(request.user, **serializer.validated_data)), status=201)


class RideListCreateView(APIView):
    def get(self, request):
        qs = visible_rides(request.user)
        from core.filters import RideFilter
        data = RideFilter(request.query_params, queryset=qs)
        if not data.is_valid():
            raise ValidationError(data.errors)
        return paginate(request, data.qs)

    def post(self, request):
        serializer = BookingRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ride, created = book(request.user, serializer.validated_data)
        return Response(RideSerializer(ride).data, status=201 if created else 200)


class RideDetailView(APIView):
    def get(self, request, pk):
        return Response(RideSerializer(get_object_or_404(visible_rides(request.user), pk=pk)).data)


class RideScheduleView(APIView):
    def patch(self, request, pk):
        from .serializers import ScheduleSerializer
        from rides.services.scheduling import reschedule

        get_object_or_404(passenger_rides(request.user), pk=pk)
        serializer = ScheduleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ride = reschedule(request.user, pk, serializer.validated_data["departure_at"])
        return Response(RideSerializer(ride).data)


class ActiveRideView(APIView):
    def get(self, request):
        ride = visible_rides(request.user).exclude(status__in=['completed', 'cancelled', 'expired']).first()
        if not ride:
            return Response({'ride': None})
        data = RideSerializer(ride).data
        data['viewer_role'] = 'passenger' if ride.passenger_id == request.user.pk else 'driver'
        if ride.assigned_driver_id:
            offer = ride.counteroffers.select_related('driver__user', 'vehicle').filter(
                driver_id=ride.assigned_driver_id, status='accepted', vehicle__isnull=False
            ).first()
            if offer:
                data['driver'] = offer_json(offer)
        return Response({'ride': data})


class OffersView(APIView):
    def get(self, request, pk):
        ride = get_object_or_404(passenger_rides(request.user), pk=pk)
        qs = ride.counteroffers.select_related('driver__user', 'vehicle').filter(driver__isnull=False, status='pending', expires_at__gt=timezone.now())
        return Response({'results': [offer_json(offer) for offer in qs]})

    def post(self, request, pk):
        get_object_or_404(Ride, pk=pk)
        data = OfferSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        values = dict(data.validated_data)
        amount = values.pop('fare_cents', None)
        offer = make_offer(request.user, pk, amount, **values)
        return Response({'id': str(offer.pk), 'status': offer.status}, status=201)


class RideStatusView(APIView):
    def get(self, request, pk):
        ride = get_object_or_404(visible_rides(request.user), pk=pk)
        valid_offer_count = ride.counteroffers.filter(status='pending', expires_at__gt=timezone.now()).count()
        search_states = {
            'scheduled': 'scheduled',
            'searching': 'searching',
            'assigned': 'driver_selected',
            'arriving': 'driver_assigned',
            'arrived': 'driver_arrived',
            'inProgress': 'trip_in_progress',
            'completed': 'trip_completed',
            'cancelled': 'ride_cancelled',
            'expired': 'request_expired',
        }
        suggested_action = {
            'scheduled': 'Matching opens 15 minutes before departure.',
            'searching': 'Waiting for eligible drivers to respond.',
            'assigned': 'Driver selected; finalise trip advance status.',
            'arriving': 'Driver is arriving. Track location.',
            'arrived': 'Driver has arrived. Begin the trip when ready.',
            'inProgress': 'Trip in progress. Monitor updates.',
            'completed': 'Ride completed. Rate the trip if needed.',
            'cancelled': 'Ride cancelled. No further action.',
            'expired': 'Ride request expired. Submit a new fare request.',
        }.get(ride.status, 'Review the ride state.')
        return Response({
            'id': str(ride.pk),
            'status': ride.status,
            'search_state': search_states.get(ride.status, 'searching'),
            'request_expiry': ride.expires_at,
            'valid_offers_count': valid_offer_count,
            'server_timestamp': timezone.now().isoformat(),
            'suggested_next_action': suggested_action,
            'sequence': ride.sequence,
            'updated_at': ride.updated_at,
        })

    def post(self, request, pk, action=None):
        get_object_or_404(visible_rides(request.user), pk=pk)
        class TransitionSerializer(serializers.Serializer):
            status = serializers.ChoiceField(choices=['arriving', 'arrived', 'inProgress', 'completed', 'cancelled'])
            reason = serializers.CharField(max_length=500, allow_blank=True, default='')
        target = {'cancel': 'cancelled', 'arrived': 'arrived', 'start': 'inProgress', 'complete': 'completed', 'arriving': 'arriving'}.get(action)
        data = TransitionSerializer(data={**request.data, **({'status': target} if target else {})})
        data.is_valid(raise_exception=True)
        ride = transition(request.user, pk, data.validated_data['status'], data.validated_data['reason'])
        return Response(RideSerializer(ride).data)


class RideAcceptView(APIView):
    def post(self, request, pk):
        get_object_or_404(passenger_rides(request.user), pk=pk)
        data = SelectionSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        ride = select_offer(
            request.user, pk, data.validated_data['offer_id'],
            expected_fare=data.validated_data.get('fare_cents'),
        )
        return Response(RideSerializer(ride).data)


class WithdrawView(APIView):
    def post(self, request, pk):
        get_object_or_404(RideOffer, pk=pk)
        return Response({'status': withdraw(request.user, pk).status})


class PlacesView(APIView):
    throttle_scope = 'places'

    def get(self, request):
        query = request.query_params.get('q', '').strip()
        if len(query) > 200:
            raise ValidationError('Search query too long.')
        return Response({'results': search_places(query) if query else []})


class DriverRequestsView(APIView):
    def get(self, request):
        app = driver_for(request.user)
        eligible(app, online=True)
        qs = Ride.objects.select_related('quote__pricing__zone', 'payment__method').filter(status='searching', currency='USD', expires_at__gt=timezone.now()).exclude(passenger=request.user).order_by('-created_at')
        categories = [app.vehicle.category]
        if app.accepts_intercity:
            categories.append(CATEGORY)
        if app.accepts_courier:
            categories.append(COURIER)
        qs = qs.filter(quote__category__in=categories, quote__pricing__zone__enabled=True)
        qs = qs.exclude(counteroffers__driver=app, counteroffers__status='declined')
        paginator = PageNumberPagination()
        page = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response(RideSerializer([r for r in page if nearby(app, r)], many=True).data)


class EarningsView(APIView):
    def get(self, request):
        app = driver_for(request.user)
        eligible(app)
        qs = app.trips.filter(status='completed', currency='USD')
        period = serializers.ChoiceField(choices=['all', 'day', 'week', 'month']).run_validation(request.query_params.get('period', 'all'))
        from datetime import timedelta
        today = timezone.localdate()
        start = {'day': today, 'week': today-timedelta(days=today.weekday()), 'month': today.replace(day=1)}.get(period)
        if start:
            from datetime import datetime, time
            from zoneinfo import ZoneInfo
            qs = qs.filter(completed_at__gte=datetime.combine(start, time.min, tzinfo=ZoneInfo('Africa/Harare')))
        return Response({'currency': 'USD', 'completed_trips': qs.count(), 'agreed_fares': format(qs.aggregate(total=Sum('agreed_fare'))['total'] or 0, '.2f'), 'payment_receipt_verified': False})


class DriverTripsView(APIView):
    def get(self, request):
        app = driver_for(request.user)
        return paginate(request, visible_rides(request.user).filter(assigned_driver=app))


class EventsView(APIView):
    def get(self, request, pk):
        ride = get_object_or_404(visible_rides(request.user), pk=pk)
        after = serializers.IntegerField(min_value=0).run_validation(request.query_params.get('after', 0))
        return Response({'sequence': ride.sequence, 'results': list(ride.events.filter(sequence__gt=after).values('id', 'sequence', 'event_type', 'payload', 'created_at')[:200])})


class RatingView(APIView):
    @transaction.atomic
    def post(self, request, pk):
        transaction.guard(Ride, pk)
        ride = get_object_or_404(visible_rides(request.user), pk=pk)
        if ride.status != 'completed':
            raise ValidationError('Only completed trips can be rated.')
        class Data(serializers.Serializer):
            score = serializers.IntegerField(min_value=1, max_value=5)
            comment = serializers.CharField(max_length=500, default='', allow_blank=True)
        data = Data(data=request.data)
        data.is_valid(raise_exception=True)
        subject_id = ride.assigned_driver.user_id if request.user.pk == ride.passenger_id else ride.passenger_id
        rating, created = Rating.objects.get_or_create(ride=ride, author=request.user, defaults={'subject_id': subject_id, **data.validated_data})
        if not created and (rating.score != data.validated_data['score'] or rating.comment != data.validated_data['comment']):
            raise ValidationError('Trip already rated.')
        return Response({'id': rating.pk, 'score': rating.score}, status=201 if created else 200)


class TicketView(APIView):
    def post(self, request):
        class Data(serializers.Serializer):
            ride_id = serializers.UUIDField(required=False)
            category = serializers.ChoiceField(choices=['support', 'safety'])
            message = serializers.CharField(max_length=2000)
        data = Data(data=request.data)
        data.is_valid(raise_exception=True)
        values = dict(data.validated_data)
        ride_id = values.pop('ride_id', None)
        ride = get_object_or_404(visible_rides(request.user), pk=ride_id) if ride_id else None
        ticket = SupportTicket.objects.create(user=request.user, ride=ride, **values)
        return Response({'id': ticket.pk, 'status': ticket.status}, status=201)


class ServiceAreasView(APIView):
    def get(self, request):
        return Response({'results': list(PricingZone.objects.filter(enabled=True).values('id', 'name', 'south', 'north', 'east', 'west'))})


class SavedPlacesView(APIView):
    def get(self, request):
        return Response({'results': list(SavedPlace.objects.filter(user=request.user).values('id', 'label', 'place'))})

    def post(self, request):
        class Data(serializers.Serializer):
            label = serializers.CharField(max_length=80)
            place = PlaceSerializer()
        data = Data(data=request.data)
        data.is_valid(raise_exception=True)
        item = SavedPlace.objects.create(user=request.user, **data.validated_data)
        return Response({'id': item.pk}, status=201)


class EmergencyContactsView(APIView):
    def get(self, request):
        from rides.models import EmergencyContact
        return Response({'results': list(EmergencyContact.objects.filter(user=request.user).values('id', 'name', 'phone'))})

    def post(self, request):
        from rides.models import EmergencyContact
        from accounts.services.authentication import normalize_phone
        class Data(serializers.Serializer):
            name = serializers.CharField(max_length=100)
            phone = serializers.CharField(max_length=40)
        data = Data(data=request.data)
        data.is_valid(raise_exception=True)
        item = EmergencyContact.objects.create(user=request.user, name=data.validated_data['name'], phone=normalize_phone(data.validated_data['phone']))
        return Response({'id': item.pk}, status=201)

    def delete(self, request):
        from rides.models import EmergencyContact
        pk = ObjectIdSerializerField().run_validation(request.data.get('id'))
        item = get_object_or_404(EmergencyContact, pk=pk, user=request.user)
        item.delete()
        return Response(status=204)


class TripShareView(APIView):
    def post(self, request, pk):
        from datetime import timedelta
        from django.contrib.auth import get_user_model
        from rides.models import TripShare
        ride = get_object_or_404(passenger_rides(request.user), pk=pk)
        if ride.status in ['completed', 'cancelled', 'expired']:
            raise ValidationError('Only an active trip may be shared.')
        from accounts.models import UserPreferences
        if UserPreferences.objects.filter(user=request.user, allow_trip_sharing=False).exists():
            raise PermissionDenied('Trip sharing is disabled in your preferences.')
        recipient_id = ObjectIdSerializerField().run_validation(request.data.get('recipient_id'))
        recipient = get_object_or_404(get_user_model(), pk=recipient_id, is_active=True)
        share = TripShare.objects.create(ride=ride, owner=request.user, recipient=recipient, expires_at=timezone.now()+timedelta(hours=6))
        return Response({'id': share.pk, 'expires_at': share.expires_at}, status=201)


class SharedTripView(APIView):
    def get(self, request, pk):
        from rides.models import TripShare
        share = get_object_or_404(TripShare.objects.select_related('ride__quote'), pk=pk, recipient=request.user, revoked=False, expires_at__gt=timezone.now())
        ride = share.ride
        if ride.status in ['completed', 'cancelled', 'expired']:
            raise PermissionDenied('Trip sharing has ended.')
        location = ride.locations.order_by('-created_at').values('latitude', 'longitude', 'created_at').first()
        return Response({'ride_id': ride.pk, 'status': ride.status, 'pickup': ride.quote.pickup, 'destination': ride.quote.destination, 'driver_location': location})

    def delete(self, request, pk):
        from rides.models import TripShare
        share = get_object_or_404(TripShare, pk=pk, owner=request.user)
        share.revoked = True
        share.save(update_fields=['revoked'])
        return Response(status=204)
