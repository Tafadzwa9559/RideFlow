from django.db import migrations


def payment_options(apps, schema_editor):
    Method = apps.get_model("payments", "PaymentMethod")
    for code, name, kind, currencies, enabled in [
        ("cash-usd", "Cash — USD", "cash", ["USD"], True),
        ("cash-zwg", "Cash — ZiG", "cash", ["ZWG"], True),
        ("ecocash", "EcoCash", "mobile_money", [], False),
        ("onemoney", "OneMoney", "mobile_money", [], False),
        ("innbucks", "InnBucks", "mobile_money", [], False),
    ]:
        Method.objects.get_or_create(
            code=code,
            defaults={
                "name": name,
                "kind": kind,
                "supported_currencies": currencies,
                "enabled": enabled,
            },
        )


class Migration(migrations.Migration):
    dependencies = [("payments", "0002_initial")]
    operations = [migrations.RunPython(payment_options, migrations.RunPython.noop)]
