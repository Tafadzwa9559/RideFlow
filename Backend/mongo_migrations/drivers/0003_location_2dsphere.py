from django.db import migrations
from pymongo import GEOSPHERE


def geo_index(apps, schema_editor):
    Driver = apps.get_model('drivers', 'DriverApplication')
    schema_editor.connection.get_collection(Driver._meta.db_table).create_index(
        [('location', GEOSPHERE)], name='driver_location_2dsphere')


class Migration(migrations.Migration):
    atomic = False
    dependencies = [('drivers', '0002_driverapplication_location')]
    operations = [migrations.RunPython(geo_index, migrations.RunPython.noop)]
