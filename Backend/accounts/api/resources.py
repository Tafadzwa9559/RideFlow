from rest_framework.parsers import MultiPartParser, FormParser
from core import transactions as transaction
from django.http import FileResponse
from rest_framework import generics, serializers, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.models import UserPreferences
from core.uploads import validate_image
from rides.models import SavedPlace, EmergencyContact
from rides.api.serializers import PlaceSerializer


class PreferencesSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserPreferences
        fields = ['language', 'push_notifications', 'marketing_notifications', 'allow_trip_sharing']


class PreferencesView(generics.RetrieveUpdateAPIView):
    serializer_class = PreferencesSerializer
    http_method_names = ['get', 'patch', 'head', 'options']

    def get_object(self):
        return UserPreferences.objects.get_or_create(user=self.request.user)[0]


class AvatarUploadSerializer(serializers.Serializer):
    file = serializers.FileField()


class AvatarView(APIView):
    parser_classes = [MultiPartParser, FormParser]
    serializer_class = AvatarUploadSerializer

    def get(self, request):
        from django.shortcuts import get_object_or_404
        preferences = get_object_or_404(UserPreferences, user=request.user)
        if not preferences.avatar:
            from rest_framework.exceptions import NotFound
            raise NotFound()
        response = FileResponse(preferences.avatar.open('rb'), as_attachment=True, filename='avatar')
        response['Cache-Control'] = 'private, no-store'
        return response

    @transaction.atomic
    def post(self, request):
        data = AvatarUploadSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        validate_image(data.validated_data['file'])
        preferences, _ = UserPreferences.objects.get_or_create(user=request.user)
        preferences.avatar = data.validated_data['file']
        preferences.save(update_fields=['avatar'])
        return Response(status=204)

    def delete(self, request):
        UserPreferences.objects.filter(user=request.user).update(avatar='')
        return Response(status=204)


class SavedPlaceSerializer(serializers.ModelSerializer):
    place = PlaceSerializer()

    class Meta:
        model = SavedPlace
        fields = ['id', 'label', 'place']
        read_only_fields = ['id']


class ContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'name', 'phone']
        read_only_fields = ['id']

    def validate_phone(self, value):
        from accounts.services.authentication import normalize_phone
        return normalize_phone(value)


class OwnedResourceViewSet(viewsets.ModelViewSet):
    http_method_names = ['get', 'post', 'patch', 'delete', 'head', 'options']

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user).order_by('pk')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class SavedPlaceViewSet(OwnedResourceViewSet):
    queryset = SavedPlace.objects.all()
    serializer_class = SavedPlaceSerializer
    search_fields = ['label']
    ordering_fields = ['id', 'label']


class ContactViewSet(OwnedResourceViewSet):
    queryset = EmergencyContact.objects.all()
    serializer_class = ContactSerializer
    search_fields = ['name']
    ordering_fields = ['id', 'name']
