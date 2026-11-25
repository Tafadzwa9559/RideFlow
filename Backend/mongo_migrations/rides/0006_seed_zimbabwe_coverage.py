from decimal import Decimal

from django.db import migrations


def seed_zimbabwe(apps, schema_editor):
    PricingZone = apps.get_model("rides", "PricingZone")
    PricingConfiguration = apps.get_model("rides", "PricingConfiguration")

    zone, created = PricingZone.objects.get_or_create(
        name="Zimbabwe",
        defaults={
            "enabled": True,
            "south": Decimal("-22.421000"),
            "north": Decimal("-15.609000"),
            "west": Decimal("25.237000"),
            "east": Decimal("33.068000"),
        },
    )
    if not created and not zone.enabled:
        zone.enabled = True
        zone.save(update_fields=["enabled"])

    policies = {
        "Standard": ("1.50", "0.75", "0.08", "3.00", "100.00"),
        "Comfort": ("2.00", "0.95", "0.10", "4.00", "120.00"),
        "XL": ("3.00", "1.20", "0.12", "6.00", "160.00"),
        "Intercity": ("5.00", "0.55", "0.06", "10.00", "300.00"),
        "Courier": ("2.00", "0.80", "0.06", "4.00", "120.00"),
    }

    for category, values in policies.items():
        base, per_km, per_minute, minimum, maximum = values
        policy, created = PricingConfiguration.objects.get_or_create(
            zone=zone,
            category=category,
            defaults={
                "enabled": True,
                "base_fare_usd": Decimal(base),
                "per_km_usd": Decimal(per_km),
                "per_minute_usd": Decimal(per_minute),
                "booking_fee_usd": Decimal("0"),
                "minimum_offer_usd": Decimal(minimum),
                "maximum_offer_usd": Decimal(maximum),
                "rounding_usd": Decimal("0.01"),
                "rounding_zwg": Decimal("0.01"),
                "priority": 10,
            },
        )
        if not created and not policy.enabled:
            policy.enabled = True
            policy.save(update_fields=["enabled"])


def remove_seed(apps, schema_editor):
    PricingZone = apps.get_model("rides", "PricingZone")
    PricingZone.objects.filter(name="Zimbabwe").delete()


class Migration(migrations.Migration):
    dependencies = [("rides", "0005_farequote_stops_ride_parcel_ride_parcel_photo_and_more")]

    operations = [migrations.RunPython(seed_zimbabwe, remove_seed)]
