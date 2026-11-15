from django.urls import path
from .views import MethodsView, CurrenciesView, ExchangeView, PaymentHistoryView

urlpatterns = [
    path("payments/methods/", MethodsView.as_view()),
    path("payments/history/", PaymentHistoryView.as_view()),
    path("currencies/", CurrenciesView.as_view()),
    path("exchange-rates/", ExchangeView.as_view()),
]
