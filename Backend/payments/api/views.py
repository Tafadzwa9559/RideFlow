from rest_framework.response import Response
from rest_framework.views import APIView
from payments.models import CURRENCIES, PaymentMethod, Payment
from payments.services.exchange import verified_rate


class MethodsView(APIView):
    def get(self, request):
        return Response(
            {
                "items": [
                    {
                        "id": m.code,
                        "name": m.name,
                        "kind": m.kind,
                        "currencies": m.supported_currencies,
                        "enabled": m.operational,
                        "description": (
                            "Pay the driver directly after your trip. Cash is not marked paid automatically."
                            if m.kind == "cash"
                            else "Payment integration unavailable"
                        ),
                    }
                    for m in PaymentMethod.objects.all().order_by("kind", "code")
                ]
            }
        )


class CurrenciesView(APIView):
    def get(self, request):
        return Response(
            {
                "items": [
                    {
                        "code": code,
                        "name": name,
                        "symbol": "US$" if code == "USD" else "ZiG",
                    }
                    for code, name in CURRENCIES
                ],
                "default": "USD",
            }
        )


class ExchangeView(APIView):
    def get(self, request):
        rate, value = verified_rate()
        return Response(
            {
                "base": "USD",
                "quote": "ZWG",
                "rate": str(value),
                "observed_at": rate.observed_at,
                "verified_at": rate.verified_at,
                "valid_until": rate.valid_until,
                "source": rate.source_url,
            }
        )


class PaymentHistoryView(APIView):
    def get(self, request):
        return Response(
            {
                "items": [
                    {
                        "id": str(p.pk),
                        "ride_id": str(p.ride_id),
                        "name": p.method.name,
                        "method": p.method_id,
                        "currency": p.currency,
                        "amount": f"{p.amount:.2f}",
                        "status": p.status,
                        "description": f"{p.currency} {p.amount:.2f} · {p.get_status_display()}",
                    }
                    for p in Payment.objects.select_related("method")
                    .filter(ride__passenger=request.user)
                    .order_by("-created_at")[:100]
                ]
            }
        )
