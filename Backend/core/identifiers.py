from bson import ObjectId
from django.core.serializers.json import DjangoJSONEncoder
from rest_framework import serializers
from rest_framework.renderers import JSONRenderer
from rest_framework.utils.encoders import JSONEncoder


class ObjectIdSerializerField(serializers.CharField):
    def to_internal_value(self, data):
        value = super().to_internal_value(data)
        if not ObjectId.is_valid(value):
            raise serializers.ValidationError('Enter a 24-character MongoDB ObjectId.')
        return ObjectId(value)

    def to_representation(self, value):
        return str(value)


class ObjectIdConverter:
    regex = '[0-9a-fA-F]{24}'

    def to_python(self, value):
        return ObjectId(value)

    def to_url(self, value):
        return str(value)


class MongoJSONEncoder(JSONEncoder):
    def default(self, value):
        if isinstance(value, ObjectId):
            return str(value)
        return super().default(value)


class MongoJSONRenderer(JSONRenderer):
    encoder_class = MongoJSONEncoder


class StorageJSONEncoder(DjangoJSONEncoder):
    def default(self, value):
        if isinstance(value, ObjectId):
            return str(value)
        return super().default(value)


def json_safe(value):
    import json
    return json.loads(json.dumps(value, cls=StorageJSONEncoder))
