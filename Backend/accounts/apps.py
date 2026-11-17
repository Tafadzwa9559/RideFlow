from django.apps import AppConfig


class AccountsConfig(AppConfig):
    default_auto_field = 'django_mongodb_backend.fields.ObjectIdAutoField'
    name = 'accounts'

    def ready(self):
        from django.conf import settings
        from accounts.test_otp import validate_test_otp_settings
        validate_test_otp_settings(settings)
