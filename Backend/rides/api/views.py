from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError
from rides.models import Ride
from rides.services.booking import book, quote_route
from rides.services.routing import search_places
from .serializers import (
    BookingRequestSerializer,
    QuoteRequestSerializer,
    RideSerializer,
    quote_json,
)


def passenger_rides(user):
    return (
        Ride.objects.select_related("quote", "payment__method")
        .filter(passenger=user)
        .order_by("-created_at")
    )


class QuoteView(APIView):
    throttle_scope = "quotes"

    def post(self, request):
        serializer = QuoteRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(
            quote_json(quote_route(request.user, **serializer.validated_data)),
            status=201,
        )


class RideListCreateView(APIView):
    def get(self, request):
        return Response(
            {
                "results": RideSerializer(
                    passenger_rides(request.user)[:100], many=True
                ).data
            }
        )

    def post(self, request):
        serializer = BookingRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ride, created = book(request.user, serializer.validated_data)
        return Response(RideSerializer(ride).data, status=201 if created else 200)


class RideDetailView(APIView):
    def get(self, request, pk):
        return Response(
            RideSerializer(get_object_or_404(passenger_rides(request.user), pk=pk)).data
        )


class ActiveRideView(APIView):
    def get(self, request):
        ride = (
            passenger_rides(request.user)
            .exclude(status__in=["completed", "cancelled"])
            .first()
        )
        return Response({"ride": RideSerializer(ride).data if ride else None})


class OffersView(APIView):
    def get(self, request, pk):
        get_object_or_404(passenger_rides(request.user), pk=pk)
        # Dispatch/driver bidding has not been integrated. Never invent offers.
        return Response({"results": []})


class RideStatusView(APIView):
    @transaction.atomic
    def post(self, request, pk):
        ride = get_object_or_404(
            passenger_rides(request.user).select_for_update(), pk=pk
        )
        if request.data.get("status") != "cancelled" or ride.status not in [
            "searching",
            "assigned",
            "arriving",
            "arrived",
        ]:
            raise ValidationError(
                "Passengers may only cancel a ride before it starts. Driver transitions require the dispatch integration."
            )
        ride.status = "cancelled"
        ride.save(update_fields=["status"])
        ride.payment.status = "cancelled"
        ride.payment.save(update_fields=["status"])
        return Response(RideSerializer(ride).data)


class PlacesView(APIView):
    throttle_scope = "places"

    def get(self, request):
        query = request.query_params.get("q", "").strip()
        if not query:
            return Response({"results": []})
        if len(query) > 200:
            raise ValidationError("Search query is too long.")
        return Response({"results": search_places(query)})
