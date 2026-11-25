from decimal import Decimal

from django.db import migrations


def seed_zimbabwe(apps, schema_editor):
    PricingZone = apps.get_model("rides", "PricingZone")
    PricingConfiguration = apps.get_model("rides", "PricingConfiguration")

    zone, _ = PricingZone.objects.get_or_create(
        name="Zimbabwe",
        defaults={
            "enabled": True,
            "south": Decimal("-22.421000"),
            "north": Decimal("-15.609000"),
            "west": Decimal("25.237000"),
            "east": Decimal("33.068000"),
        },
    )
    if not zone.enabled:
        zone.enabled = True
        zone.save(update_fields=["enabled"])

    policies = {
        "Standard": (Decimal("1.50"), Decimal("0.75"), Decimal("0.08"), Decimal("3.00"), Decimal("100.00")),
        "Comfort": (Decimal("2.00"), Decimal("0.95"), Decimal("0.10"), Decimal("4.00"), Decimal("120.00")),
        "XL": (Decimal("3.00"), Decimal("1.20"), Decimal("0.12"), Decimal("6.00"), Decimal("160.00")),
        "Intercity": (Decimal("5.00"), Decimal("0.55"), Decimal("0.06"), Decimal("10.00"), Decimal("300.00")),
        "Courier": (Decimal("2.00"), Decimal("0.80"), Decimal("0.06"), Decimal("4.00"), Decimal("120.00")),
    }

    for category, values in policies.items():
        base, per_km, per_minute, minimum, maximum = values
        defaults = {
            "enabled": True,
            "base_fare_usd": base,
            "per_km_usd": per_km,
            "per_minute_usd": per_minute,
            "minimum_offer_usd": minimum,
            "maximum_offer_usd": maximum,
            "rounding_usd": Decimal("0.01"),
            "rounding_zwg": Decimal("0.01"),
            "priority": 10,
        }
        policy = PricingConfiguration.objects.filter(zone=zone, category=category).first()
        if policy is None:
            PricingConfiguration.objects.create(zone=zone, category=category, **defaults)
        elif not policy.enabled:
            policy.enabled = True
            policy.save(update_fields=["enabled"])


def remove_seed(apps, schema_editor):
    PricingZone = apps.get_model("rides", "PricingZone")
    PricingZone.objects.filter(name="Zimbabwe").delete()


class Migration(migrations.Migration):
    dependencies = [("rides", "0005_farequote_stops_ride_parcel_ride_parcel_photo_and_more")]

    operations = [migrations.RunPython(seed_zimbabwe, remove_seed)]
