from django.db import migrations


def direct_preferences(apps, schema_editor):
    Method = apps.get_model('payments', 'PaymentMethod')
    Method.objects.exclude(code__in=['cash-usd', 'ecocash', 'onemoney']).update(enabled=False)
    for code, name, kind in [('cash-usd', 'Cash', 'cash'), ('ecocash', 'EcoCash', 'mobile_money'), ('onemoney', 'OneMoney', 'mobile_money')]:
        Method.objects.update_or_create(code=code, defaults={'name': name, 'kind': kind, 'supported_currencies': ['USD'], 'enabled': True})


class Migration(migrations.Migration):
    dependencies = [('payments', '0003_payment_options')]
    operations = [migrations.RunPython(direct_preferences, migrations.RunPython.noop)]
