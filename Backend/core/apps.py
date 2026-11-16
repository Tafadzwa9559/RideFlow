from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = 'core'
    default_auto_field = 'django_mongodb_backend.fields.ObjectIdAutoField'

    def ready(self):
        # SimpleJWT 5.5 declares explicit BigAutoFields and checks the literal
        # app name to enable blacklisting. Keep its actual app/models and adapt
        # only those two pinned fields before any DB query or migration state.
        from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
        from django_mongodb_backend.fields import ObjectIdAutoField
        for model in [OutstandingToken, BlacklistedToken]:
            field = model._meta.pk
            if type(field) is not ObjectIdAutoField:
                field.__class__ = ObjectIdAutoField
                field.db_column = field.column = '_id'
                field.__dict__.pop('validators', None)
                field.__dict__.pop('cached_col', None)
        from rest_framework.serializers import ModelSerializer
        from django_mongodb_backend.fields import ObjectIdAutoField, ObjectIdField
        from core.identifiers import ObjectIdSerializerField
        ModelSerializer.serializer_field_mapping[ObjectIdAutoField] = ObjectIdSerializerField
        ModelSerializer.serializer_field_mapping[ObjectIdField] = ObjectIdSerializerField
        from . import checks  # noqa: F401
