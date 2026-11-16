from django.db import migrations


def preserve_vehicles(apps, schema_editor):
    Driver = apps.get_model('drivers', 'DriverApplication')
    Vehicle = apps.get_model('drivers', 'Vehicle')
    for vehicle in Vehicle.objects.filter(archived=False).order_by('pk').iterator():
        Driver.objects.filter(pk=vehicle.application_id, active_vehicle__isnull=True).update(active_vehicle_id=vehicle.pk)


class Migration(migrations.Migration):
    dependencies = [('drivers', '0002_documentrequirement_scope_and_more')]
    operations = [migrations.RunPython(preserve_vehicles, migrations.RunPython.noop)]
