"""Expanded REST resources. Compatibility handlers remain in the original apps."""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from accounts.api.views import OTPRequestView, LogoutView
from accounts.api.resources import PreferencesView, AvatarView, SavedPlaceViewSet, ContactViewSet
from drivers.api.views import ApplicationView, DocumentView, RequirementsView
from drivers.api.resources import DriverProfileView, DocumentDeleteView, ReviewHistoryView, StatisticsView, FleetViewSet, VehicleDocumentsView, VehicleDocumentDetailView, AvailabilityDetailView
from rides.api.resources import CurrentDriverTripView, RequestDetailView, ReverseGeocodeView, RouteEstimateView, AreaDetailView, CategoriesView, RideReadView, OfferDetailView, OwnTripsView, EarningsSummaryView, EarningsHistoryView, RatingsView, TicketsView, TicketDetailView, ReportView
from rides.api.views import PlacesView, EventsView, RideStatusView
from notifications.api.views import UnreadCountView, MarkAllReadView, DeviceRegisterView, DeviceDeleteView
router = DefaultRouter()
router.register('users/me/saved-places', SavedPlaceViewSet)
router.register('users/me/emergency-contacts', ContactViewSet)
router.register('drivers/me/vehicles', FleetViewSet)
urlpatterns = [
    path('', include(router.urls)),
    path('auth/otp/resend/', OTPRequestView.as_view()), path('auth/logout-all/', LogoutView.as_view()),
    path('users/me/preferences/', PreferencesView.as_view()), path('users/me/avatar/', AvatarView.as_view()),
    path('drivers/document-requirements/', RequirementsView.as_view()),
    path('drivers/me/', ApplicationView.as_view(http_method_names=['get', 'options'])), path('drivers/me/status/', ApplicationView.as_view(http_method_names=['get', 'options'])),
    path('drivers/applications/', ApplicationView.as_view(http_method_names=['post', 'options'])),
    path('drivers/applications/me/documents/<int:pk>/', DocumentDeleteView.as_view()),
    path('drivers/applications/me/review-history/', ReviewHistoryView.as_view()),
    path('drivers/me/profile/', DriverProfileView.as_view()), path('drivers/me/statistics/', StatisticsView.as_view()),
    path('drivers/me/ratings/', RatingsView.as_view()), path('drivers/<int:pk>/ratings/', RatingsView.as_view()),
    path('drivers/me/availability/', AvailabilityDetailView.as_view()), path('drivers/me/current-trip/', CurrentDriverTripView.as_view()),
    path('drivers/me/requests/<uuid:pk>/', RequestDetailView.as_view()),
    path('drivers/me/vehicles/<int:vehicle_id>/documents/', VehicleDocumentsView.as_view()),
    path('drivers/me/vehicles/<int:vehicle_id>/documents/<int:pk>/', VehicleDocumentDetailView.as_view()),
    path('locations/search/', PlacesView.as_view()), path('locations/reverse-geocode/', ReverseGeocodeView.as_view()),
    path('routes/estimate/', RouteEstimateView.as_view()), path('service-areas/<int:pk>/', AreaDetailView.as_view()),
    path('ride-categories/', CategoriesView.as_view()), path('ride-categories/<str:pk>/', CategoriesView.as_view()),
    path('rides/<uuid:pk>/timeline/', EventsView.as_view()),
    path('rides/<uuid:pk>/tracking/', RideReadView.as_view(mode='tracking')),
    path('rides/<uuid:pk>/receipt/', RideReadView.as_view(mode='receipt')),
    path('rides/<uuid:pk>/driver-en-route/', RideStatusView.as_view(http_method_names=['post', 'options']), {'action': 'arriving'}),
    path('offers/<int:pk>/', OfferDetailView.as_view()), path('users/me/trips/', OwnTripsView.as_view()),
    path('drivers/me/earnings/summary/', EarningsSummaryView.as_view()), path('drivers/me/earnings/history/', EarningsHistoryView.as_view()),
    path('users/me/ratings/', RatingsView.as_view()), path('notifications/unread-count/', UnreadCountView.as_view()),
    path('notifications/mark-all-read/', MarkAllReadView.as_view()), path('devices/register/', DeviceRegisterView.as_view()),
    path('devices/<int:pk>/', DeviceDeleteView.as_view()),
    path('support/tickets/', TicketsView.as_view()), path('support/tickets/<int:pk>/', TicketDetailView.as_view()),
    path('rides/<uuid:pk>/report/', ReportView.as_view()),
]
