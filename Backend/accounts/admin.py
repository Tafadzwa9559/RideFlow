from django.contrib import admin
from accounts.models import AuditEvent, PhoneIdentity


@admin.register(AuditEvent, PhoneIdentity)
class ReadOnlyAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
