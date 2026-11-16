from django.contrib import admin
from drivers.models import DriverApplication, DocumentRequirement, Vehicle


@admin.register(DriverApplication, Vehicle)
class DriverReadOnlyAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(DocumentRequirement)
class RequirementAdmin(admin.ModelAdmin):
    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        from accounts.models import AuditEvent
        AuditEvent.objects.create(actor=request.user, action='document_requirement.updated', target=obj.pk, summary={'fields': form.changed_data}, request_id=getattr(request, 'request_id', ''))
