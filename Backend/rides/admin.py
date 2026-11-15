from django.contrib import admin
from .models import PricingZone, PricingConfiguration, TimeAdjustment, FareQuote, Ride

admin.site.register(PricingZone)
admin.site.register(PricingConfiguration)
admin.site.register(TimeAdjustment)


@admin.register(FareQuote, Ride)
class BookingAuditAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
