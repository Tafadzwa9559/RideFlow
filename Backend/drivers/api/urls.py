from django.urls import path
from .views import ApplicationView, SubmitView, DocumentView, DocumentDownloadView, RequirementsView, AvailabilityView, LocationView, ReviewView
from rides.api.views import DriverRequestsView, EarningsView, DriverTripsView
urlpatterns = [
    path('driver/application/', ApplicationView.as_view()),
    path('driver/application/submit/', SubmitView.as_view()),
    path('driver/application/documents/', DocumentView.as_view()),
    path('driver/documents/<objectid:pk>/', DocumentDownloadView.as_view()),
    path('driver/requirements/', RequirementsView.as_view()),
    path('driver/availability/', AvailabilityView.as_view()),
    path('drivers/me/go-online/', AvailabilityView.as_view(), {'action': 'go-online'}),
    path('drivers/me/go-offline/', AvailabilityView.as_view(), {'action': 'go-offline'}),
    path('drivers/me/location/', LocationView.as_view()),
    path('drivers/me/verification-status/', ApplicationView.as_view(http_method_names=['get', 'options'])),
    path('drivers/me/requests/', DriverRequestsView.as_view()),
    path('drivers/me/earnings/', EarningsView.as_view()),
    path('drivers/me/trips/', DriverTripsView.as_view()),
    path('drivers/applications/me/', ApplicationView.as_view()),
    path('drivers/applications/me/submit/', SubmitView.as_view()),
    path('drivers/applications/me/documents/', DocumentView.as_view()),
    path('admin/drivers/<objectid:pk>/review/', ReviewView.as_view()),
]
# Preserve mobile resource names ahead of the availability action route.
urlpatterns[0:0] = [path('driver/requests/', DriverRequestsView.as_view()), path('driver/earnings/', EarningsView.as_view()), path('driver/location/', LocationView.as_view()), path('driver/trips/', DriverTripsView.as_view())]
