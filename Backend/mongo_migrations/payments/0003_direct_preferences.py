from django.db import migrations


def seed(apps, schema_editor):
    Method = apps.get_model('payments', 'PaymentMethod')
    for code, name, kind in [('cash-usd', 'Cash', 'cash'), ('ecocash', 'EcoCash', 'mobile_money'), ('onemoney', 'OneMoney', 'mobile_money')]:
        Method.objects.get_or_create(code=code, defaults={'name': name, 'kind': kind, 'supported_currencies': ['USD'], 'enabled': True})


class Migration(migrations.Migration):
    dependencies = [('payments', '0002_initial')]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
