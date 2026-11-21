from uuid import uuid4

from django.core.files.storage import storages
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from rest_framework import serializers
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from core import transactions as transaction
from core.uploads import validate_image
from rides.api.serializers import ParcelSerializer, RideSerializer
from rides.api.views import passenger_rides, visible_rides
from rides.models import Ride
from rides.services.courier import CATEGORY, confirm_delivery, confirmation_code

ACTIVE_DELIVERY = ("assigned", "arriving", "arrived", "inProgress")


class ParcelDetailsSerializer(serializers.Serializer):
    parcel = ParcelSerializer()
    has_photo = serializers.BooleanField()
    confirmation_code = serializers.CharField(required=False)


class ParcelPhotoSerializer(serializers.Serializer):
    file = serializers.FileField()


class DeliveryProofSerializer(serializers.Serializer):
    code = serializers.RegexField(r"\A[0-9]{8}\Z")


def private_delivery(request, pk):
    ride = get_object_or_404(visible_rides(request.user), pk=pk, quote__category=CATEGORY)
    if ride.passenger_id != request.user.pk and ride.status not in ACTIVE_DELIVERY:
        raise NotFound()
    return ride


class ParcelDetailsView(APIView):
    def get(self, request, pk):
        ride = private_delivery(request, pk)
        data = {"parcel": ride.parcel, "has_photo": bool(ride.parcel_photo)}
        if ride.passenger_id == request.user.pk and ride.status == "inProgress":
            data["confirmation_code"] = confirmation_code(ride)
        response = Response(ParcelDetailsSerializer(data).data)
        response["Cache-Control"] = "private, no-store"
        return response


class ParcelPhotoView(APIView):
    parser_classes = [MultiPartParser]

    def get(self, request, pk):
        ride = private_delivery(request, pk)
        if not ride.parcel_photo:
            raise NotFound()
        storage = storages["private"]
        try:
            file = storage.open(ride.parcel_photo, "rb")
        except FileNotFoundError as error:
            raise NotFound() from error
        content_type = "image/png" if ride.parcel_photo.endswith(".png") else "image/jpeg"
        response = FileResponse(file, content_type=content_type)
        response["Cache-Control"] = "private, no-store"
        response["X-Content-Type-Options"] = "nosniff"
        return response

    def post(self, request, pk):
        get_object_or_404(passenger_rides(request.user), pk=pk, quote__category=CATEGORY)
        serializer = ParcelPhotoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        file = serializer.validated_data["file"]
        kind = validate_image(file)
        storage = storages["private"]
        extension = "png" if kind == "image/png" else "jpg"
        path = storage.save(f"parcels/{pk}/{uuid4()}.{extension}", file)
        try:
            with transaction.atomic():
                transaction.guard(Ride, pk)
                ride = Ride.objects.get(pk=pk)
                if ride.status not in ("searching", *ACTIVE_DELIVERY):
                    raise ValidationError("The delivery is closed.")
                previous = ride.parcel_photo
                ride.parcel_photo = path
                ride.save(update_fields=["parcel_photo"])
                if previous:
                    transaction.on_commit(lambda: storage.delete(previous), robust=True)
        except ValidationError:
            storage.delete(path)
            raise
        return Response(status=204)


class DeliveryProofView(APIView):
    def post(self, request, pk):
        get_object_or_404(visible_rides(request.user), pk=pk, quote__category=CATEGORY)
        serializer = DeliveryProofSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ride = confirm_delivery(request.user, pk, serializer.validated_data["code"])
        if ride is None:
            raise ValidationError({"code": "Code could not be verified. After five attempts, wait 15 minutes."})
        return Response(RideSerializer(ride).data)
