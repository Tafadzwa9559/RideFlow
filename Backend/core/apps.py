from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = 'core'
    default_auto_field = 'django_mongodb_backend.fields.ObjectIdAutoField'

    def ready(self):
        from rest_framework.serializers import ModelSerializer
        from django_mongodb_backend.fields import ObjectIdAutoField, ObjectIdField
        from core.identifiers import ObjectIdSerializerField
        ModelSerializer.serializer_field_mapping[ObjectIdAutoField] = ObjectIdSerializerField
        ModelSerializer.serializer_field_mapping[ObjectIdField] = ObjectIdSerializerField
        from . import checks  # noqa: F401
