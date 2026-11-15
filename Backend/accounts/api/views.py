from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView


class ProfileSerializer(serializers.Serializer):
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    email = serializers.EmailField(required=False, allow_blank=True)


class MeView(APIView):
    def get(self, request):
        user = request.user
        return Response(
            {
                "first_name": user.first_name,
                "last_name": user.last_name,
                "email": user.email,
                "phone": user.username,
                "driver_status": "draft",
            }
        )

    def post(self, request):
        serializer = ProfileSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        for key, value in serializer.validated_data.items():
            setattr(request.user, key, value)
        request.user.save(update_fields=list(serializer.validated_data))
        return self.get(request)
