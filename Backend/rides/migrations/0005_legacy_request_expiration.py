from datetime import timedelta
from django.db import migrations


def expire_legacy(apps, schema_editor):
    Ride = apps.get_model('rides', 'Ride')
    # Old requests predate TTL support. Preserve history, give them their original
    # five-minute request window, and let normal maintenance expire stale searches.
    for ride in Ride.objects.filter(expires_at__isnull=True).iterator():
        Ride.objects.filter(pk=ride.pk).update(expires_at=ride.created_at + timedelta(minutes=5))


class Migration(migrations.Migration):
    dependencies = [('rides', '0004_emergencycontact_tripshare')]
    operations = [migrations.RunPython(expire_legacy, migrations.RunPython.noop)]
