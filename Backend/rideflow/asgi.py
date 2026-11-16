import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'rideflow.settings')
from django.core.asgi import get_asgi_application
http_application = get_asgi_application()
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.urls import path
from rides.consumers.ride_consumer import RideConsumer
application = ProtocolTypeRouter({
    'http': http_application,
    'websocket': AllowedHostsOriginValidator(URLRouter([
        path('ws/v1/notifications/', RideConsumer.as_asgi()),
        path('ws/v1/passenger/rides/<uuid:ride_id>/', RideConsumer.as_asgi()),
        path('ws/v1/driver/rides/<uuid:ride_id>/', RideConsumer.as_asgi()),
        path('ws/v1/driver/requests/', RideConsumer.as_asgi()),
    ])),
})
