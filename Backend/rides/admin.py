from django.contrib import admin
from .models import PricingZone, PricingConfiguration, TimeAdjustment, FareQuote, Ride

class AuditedConfigurationAdmin(admin.ModelAdmin):
    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        from accounts.models import AuditEvent
        AuditEvent.objects.create(actor=request.user, action='configuration.updated', target=f'{obj._meta.label}:{obj.pk}', summary={'fields': form.changed_data}, request_id=getattr(request, 'request_id', ''))

    def has_delete_permission(self, request, obj=None):
        return False

admin.site.register(PricingZone, AuditedConfigurationAdmin)
admin.site.register(PricingConfiguration, AuditedConfigurationAdmin)
admin.site.register(TimeAdjustment, AuditedConfigurationAdmin)


@admin.register(FareQuote, Ride)
class BookingAuditAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
