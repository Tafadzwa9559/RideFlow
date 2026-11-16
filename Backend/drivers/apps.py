from django.apps import AppConfig


class DriversConfig(AppConfig):
    default_auto_field = 'django_mongodb_backend.fields.ObjectIdAutoField'
    name = 'drivers'
