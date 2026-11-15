from django.urls import path
from .views import (
    QuoteView,
    RideListCreateView,
    RideDetailView,
    ActiveRideView,
    RideStatusView,
    OffersView,
    PlacesView,
)

urlpatterns = [
    path("routes/quote/", QuoteView.as_view()),
    path("places/", PlacesView.as_view()),
    path("rides/", RideListCreateView.as_view()),
    path("rides/active/", ActiveRideView.as_view()),
    path("rides/<uuid:pk>/", RideDetailView.as_view()),
    path("rides/<uuid:pk>/status/", RideStatusView.as_view()),
    path("rides/<uuid:pk>/offers/", OffersView.as_view()),
]
