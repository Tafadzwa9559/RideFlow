from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('accounts', '0003_emailidentity')]

    operations = [
        migrations.AddField(
            model_name='emailidentity',
            name='verification_required',
            field=models.BooleanField(default=False),
        ),
    ]
