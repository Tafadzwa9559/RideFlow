from django.contrib import admin
from django.urls import path, include
from rest_framework.permissions import IsAdminUser
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView
from accounts.api.views import OTPRequestView, OTPVerifyView, LogoutView, MeView, RefreshView
from notifications.api.views import NotificationsView, ReadView, DeviceView
from core.views import health, ready
api_patterns = [
    path('', include('core.api_urls')),
    path('', include('rides.api.urls')),
    path('', include('payments.api.urls')),
    path('', include('drivers.api.urls')),
    path('auth/otp/request/', OTPRequestView.as_view()),
    path('auth/otp/verify/', OTPVerifyView.as_view()),
    path('auth/token/refresh/', RefreshView.as_view()),
    path('auth/logout/', LogoutView.as_view()),
    path('auth/me/', MeView.as_view(http_method_names=['get', 'options'])),
    path('me/', MeView.as_view()),
    path('users/me/', MeView.as_view(http_method_names=['get', 'patch', 'options'])),
    path('notifications/', NotificationsView.as_view()),
    path('notifications/devices/', DeviceView.as_view()),
    path('notifications/<uuid:pk>/read/', ReadView.as_view()),
]
urlpatterns = [
    path('admin/', admin.site.urls),
    path('mobile/v1/', include(api_patterns)),
    path('api/v1/', include(api_patterns)),
    path('health/', health), path('ready/', ready),
    path('api/schema/', SpectacularAPIView.as_view(permission_classes=[IsAdminUser]), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema', permission_classes=[IsAdminUser])),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema', permission_classes=[IsAdminUser])),
]
from rest_framework.routers import DefaultRouter
from core.admin_api import ZoneViewSet, PriceViewSet, DriverViewSet, AdminRideViewSet, TicketViewSet, OverviewView, AdminCancelView, AccountStatusView, UserViewSet, VehicleReviewView, VehicleViewSet, OfferViewSet, AuditViewSet
from core.admin_resources import ManagedDriverViewSet, ApplicationAdminViewSet, ManagedVehicleViewSet, PassengerViewSet, DisputeViewSet, AnalyticsView, ReportsView, AdminTimelineView
router = DefaultRouter()
router.register('service-areas', ZoneViewSet)
router.register('pricing', PriceViewSet)
router.register('drivers', ManagedDriverViewSet)
router.register('driver-applications', ApplicationAdminViewSet, basename='driver-application')
router.register('passengers', PassengerViewSet, basename='passenger')
router.register('disputes', DisputeViewSet, basename='dispute')
router.register('pricing-rules', PriceViewSet, basename='pricing-rule')
router.register('audit-logs', AuditViewSet, basename='audit-log')
router.register('rides', AdminRideViewSet)
router.register('tickets', TicketViewSet)
router.register('users', UserViewSet)
router.register('vehicles', ManagedVehicleViewSet)
router.register('offers', OfferViewSet)
router.register('audit', AuditViewSet)
urlpatterns += [path('api/v1/admin/', include(router.urls)), path('api/v1/admin/overview/', OverviewView.as_view()),
    path('api/v1/admin/rides/<uuid:pk>/cancel/', AdminCancelView.as_view()),
    path('api/v1/admin/users/<int:pk>/status/', AccountStatusView.as_view()),
    path('api/v1/admin/vehicles/<int:pk>/review/', VehicleReviewView.as_view())]
urlpatterns += [
    path('api/v1/admin/dashboard/overview/', OverviewView.as_view()),
    path('api/v1/admin/dashboard/ride-analytics/', AnalyticsView.as_view()),
    path('api/v1/admin/dashboard/driver-analytics/', AnalyticsView.as_view(kind='driver-analytics')),
    path('api/v1/admin/dashboard/platform-activity/', AnalyticsView.as_view(kind='platform-activity')),
    path('api/v1/admin/reports/rides/', ReportsView.as_view(kind='rides')),
    path('api/v1/admin/reports/drivers/', ReportsView.as_view(kind='drivers')),
    path('api/v1/admin/reports/passengers/', ReportsView.as_view(kind='passengers')),
    path('api/v1/admin/reports/earnings/', ReportsView.as_view(kind='earnings')),
    path('api/v1/admin/rides/<uuid:pk>/timeline/', AdminTimelineView.as_view()),
]
from core.schema import annotate
annotate()
from core.views import WebSocketDocumentationView
urlpatterns += [path('api/websockets/', WebSocketDocumentationView.as_view())]
from core.admin_api import DocumentRequirementViewSet
# Register after existing routes using a separate router to preserve stable names.
configuration_router = DefaultRouter()
configuration_router.register('document-requirements', DocumentRequirementViewSet)
urlpatterns += [path('api/v1/admin/', include(configuration_router.urls))]
