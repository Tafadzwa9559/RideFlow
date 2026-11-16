from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework.views import APIView
from notifications.models import Notification


class NotificationsView(APIView):
    def get(self, request):
        qs = Notification.objects.filter(user=request.user).order_by('-created_at')
        from core.filters import NotificationFilter
        data = NotificationFilter(request.query_params, queryset=qs)
        if not data.is_valid():
            from rest_framework.exceptions import ValidationError
            raise ValidationError(data.errors)
        qs = data.qs
        paginator = PageNumberPagination()
        page = paginator.paginate_queryset(qs, request)
        return paginator.get_paginated_response([{'id': n.pk, **n.envelope, 'read_at': n.read_at} for n in page])


class ReadView(APIView):
    def post(self, request, pk):
        item = get_object_or_404(Notification, pk=pk, user=request.user)
        if item.read_at is None:
            item.read_at = timezone.now()
            item.save(update_fields=['read_at'])
        return Response({'read_at': item.read_at})


class DeviceView(APIView):
    def post(self, request):
        from rest_framework import serializers
        from notifications.models import DeviceToken
        class Data(serializers.Serializer):
            token = serializers.CharField(max_length=512)
            platform = serializers.ChoiceField(choices=['android', 'ios'])
        data = Data(data=request.data)
        data.is_valid(raise_exception=True)
        DeviceToken.objects.update_or_create(token=data.validated_data['token'], defaults={'user': request.user, 'platform': data.validated_data['platform']})
        return Response(status=204)

    def delete(self, request):
        from rest_framework import serializers
        from notifications.models import DeviceToken
        token = serializers.CharField(max_length=512).run_validation(request.data.get('token'))
        DeviceToken.objects.filter(user=request.user, token=token).delete()
        return Response(status=204)


class UnreadCountView(APIView):
    def get(self, request):
        return Response({'count': Notification.objects.filter(user=request.user, read_at__isnull=True).count()})


class MarkAllReadView(APIView):
    def post(self, request):
        count = Notification.objects.filter(user=request.user, read_at__isnull=True).update(read_at=timezone.now())
        return Response({'updated': count})


class DeviceRegisterView(APIView):
    def post(self, request):
        from rest_framework import serializers
        from notifications.models import DeviceToken
        class Data(serializers.Serializer):
            token = serializers.CharField(max_length=512)
            platform = serializers.ChoiceField(choices=['android', 'ios'])
        data = Data(data=request.data)
        data.is_valid(raise_exception=True)
        device, _ = DeviceToken.objects.update_or_create(token=data.validated_data['token'], defaults={'user': request.user, 'platform': data.validated_data['platform']})
        return Response({'id': device.pk, 'platform': device.platform}, status=201)


class DeviceDeleteView(APIView):
    def delete(self, request, pk):
        from notifications.models import DeviceToken
        get_object_or_404(DeviceToken, pk=pk, user=request.user).delete()
        return Response(status=204)
