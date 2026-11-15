from django.contrib import admin
from django.utils import timezone
from .models import PaymentMethod, ExchangeRate, Payment

admin.site.register(PaymentMethod)


@admin.register(ExchangeRate)
class ExchangeRateAdmin(admin.ModelAdmin):
    exclude = ["verified_at", "verified_by"]
    list_display = [
        "usd_to_zwg",
        "source_url",
        "observed_at",
        "valid_until",
        "verified_at",
        "verified_by",
    ]

    def save_model(self, request, obj, form, change):
        obj.verified_at = timezone.now()
        obj.verified_by = request.user
        super().save_model(request, obj, form, change)

    def has_change_permission(self, request, obj=None):
        return obj is None

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
