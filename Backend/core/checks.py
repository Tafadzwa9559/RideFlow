from django.conf import settings
from django.core.checks import Error, register, Tags
from django.db import connections


@register(Tags.database)
def mongodb_replica_check(app_configs, databases=None, **kwargs):
    if not databases:
        return []
    errors = []
    for alias in databases:
        connection = connections[alias]
        if connection.settings_dict['ENGINE'] != 'django_mongodb_backend':
            continue
        try:
            hello = connection.database.client.admin.command('hello')
            if not hello.get('setName') and hello.get('msg') != 'isdbgrid':
                errors.append(Error('MongoDB must be a replica set or sharded cluster for Trivia transactions.', id='trivia.E001'))
        except Exception:
            errors.append(Error('MongoDB connectivity check failed; inspect URI/network configuration.', id='trivia.E002'))
    return errors
