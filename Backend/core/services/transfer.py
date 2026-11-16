"""Non-destructive legacy snapshot conversion and verified MongoDB rehearsal import."""
import copy
import hashlib
import json
import uuid
from datetime import datetime, timezone
from bson import ObjectId, json_util
from django.apps import apps
from django.core.management.base import CommandError
from django.db import connections
from core.identifiers import StorageJSONEncoder

EXCLUDED = {'sessions', 'token_blacklist', 'core'}
SEED_MODELS = {'contenttypes.contenttype', 'auth.permission', 'payments.paymentmethod'}


def models_for_transfer():
    return {m._meta.label_lower: m for m in apps.get_models(include_auto_created=True)
            if not m._meta.proxy and m._meta.app_label not in EXCLUDED}


def identifier(label, value):
    return ObjectId(hashlib.sha256(f'{label}:{value}'.encode()).digest()[:12])


def export_sql(connection):
    """Raw read-only SELECTs: current ObjectId models must never query old SQL IDs."""
    result = {'format': 1, 'exported_at': datetime.now(timezone.utc).isoformat(), 'models': {}}
    tables = set(connection.introspection.table_names())
    for label, model in models_for_transfer().items():
        table = model._meta.db_table
        if table not in tables:
            continue
        with connection.cursor() as cursor:
            columns = {column.name for column in connection.introspection.get_table_description(cursor, table)}
            fields = [(field, 'id' if field.primary_key and field.column == '_id' else field.column)
                      for field in model._meta.local_fields]
            selected = [(field, column) for field, column in fields if column in columns]
            quoted = connection.ops.quote_name
            cursor.execute('SELECT ' + ', '.join(quoted(column) for _, column in selected) + ' FROM ' + quoted(table))
            rows = []
            for values in cursor.fetchall():
                record = {}
                for (field, _), value in zip(selected, values):
                    if field.get_internal_type() == 'JSONField' and isinstance(value, str):
                        value = json.loads(value)
                    if isinstance(value, datetime) and value.tzinfo is None:
                        value = value.replace(tzinfo=timezone.utc)
                    record[field.attname] = value
                rows.append(record)
            result['models'][label] = rows
    return json.loads(json.dumps(result, cls=StorageJSONEncoder))


def prepare(snapshot, connection):
    if snapshot.get('format') != 1 or not isinstance(snapshot.get('models'), dict):
        raise CommandError('Unsupported snapshot format.')
    registry = models_for_transfer()
    unknown = set(snapshot['models']) - set(registry)
    if unknown:
        raise CommandError('Snapshot contains models absent from this application.')
    id_map = {}
    for label, rows in snapshot['models'].items():
        model = registry[label]
        for row in rows:
            old = row[model._meta.pk.attname]
            key = (label, str(old))
            if key in id_map:
                raise CommandError(f'Duplicate source primary key for {label}.')
            id_map[key] = identifier(label, old) if model._meta.pk.get_internal_type() == 'ObjectIdAutoField' else model._meta.pk.to_python(old)
    # Contrib natural identities already seeded by migrate must retain target IDs.
    for label in ['contenttypes.contenttype', 'auth.permission']:
        model = registry[label]
        for row in snapshot['models'].get(label, []):
            criteria = {'app_label': row['app_label'], 'model': row['model']} if label == 'contenttypes.contenttype' else {
                'codename': row['codename'], 'content_type_id': id_map[('contenttypes.contenttype', str(row['content_type_id']))]}
            existing = model.objects.using(connection.alias).filter(**criteria).first()
            if existing:
                id_map[(label, str(row[model._meta.pk.attname]))] = existing.pk
    documents = {}
    for label, rows in snapshot['models'].items():
        model = registry[label]
        converted = []
        for row in rows:
            values = {}
            for field in model._meta.local_fields:
                value = row.get(field.attname, field.get_default())
                if field.primary_key:
                    value = id_map[(label, str(row[field.attname]))]
                elif field.is_relation and value is not None:
                    related = field.remote_field.model._meta.label_lower
                    key = (related, str(value))
                    if key not in id_map:
                        raise CommandError(f'Missing source foreign-key record for {label}.{field.name}.')
                    value = id_map[key]
                elif value is not None and field.get_internal_type() not in ['JSONField', 'FileField', 'ImageField']:
                    value = field.to_python(value)
                if value is None and not field.null and not field.primary_key:
                    raise CommandError(f'Missing required value for {label}.{field.name}.')
                if not field.is_relation:
                    field.run_validators(value)
                values[field.attname] = value
            if label == 'drivers.driverapplication':
                values['location'] = None if values['latitude'] is None or values['longitude'] is None else {
                    'type': 'Point', 'coordinates': [float(values['longitude']), float(values['latitude'])]}
                # Cutover requires a fresh heartbeat before accepting dispatch.
                values['availability'] = 'offline'
            if label == 'accounts.phoneidentity':
                values['session_version'] += 1
            converted.append(values)
        documents[label] = converted
    def remap(label, value):
        return str(id_map.get((label, str(value)), value))
    for event in documents.get('accounts.auditevent', []):
        target = event['target']
        label = next((label for prefix, label in [('driver.', 'drivers.driverapplication'), ('vehicle.', 'drivers.vehicle'), ('account.', 'auth.user'), ('ticket.', 'rides.supportticket')] if event['action'].startswith(prefix)), None)
        if label:
            event['target'] = remap(label, target)
        elif ':' in target:
            name, pk = target.rsplit(':', 1)
            event['target'] = name + ':' + remap(name.lower(), pk)
    for event in documents.get('rides.rideevent', []):
        if 'offer_id' in event['payload']:
            event['payload']['offer_id'] = remap('rides.rideoffer', event['payload']['offer_id'])
    for item in documents.get('notifications.notification', []):
        envelope = item['envelope']
        if 'offer_id' in envelope.get('payload', {}):
            envelope['payload']['offer_id'] = remap('rides.rideoffer', envelope['payload']['offer_id'])
        if envelope.get('type') == 'verification.updated':
            envelope['resource_id'] = remap('drivers.driverapplication', envelope['resource_id'])
    vehicles = {str(v['id']): v for v in documents.get('drivers.vehicle', [])}
    for driver in documents.get('drivers.driverapplication', []):
        if driver['active_vehicle_id'] is None:
            owned = [v for v in vehicles.values() if v['application_id'] == driver['id'] and not v['archived']]
            if len(owned) == 1:
                driver['active_vehicle_id'] = owned[0]['id']
        elif vehicles[str(driver['active_vehicle_id'])]['application_id'] != driver['id']:
            raise CommandError('Active vehicle belongs to another driver.')
    # Rewrite quote JSON pricing identity/version with millisecond timestamps.
    policies = {str(v['id']): v for v in documents.get('rides.pricingconfiguration', [])}
    for quote in documents.get('rides.farequote', []):
        policy = policies.get(str(quote['pricing_id']))
        if policy:
            stamp = policy['updated_at'].replace(microsecond=(policy['updated_at'].microsecond // 1000)*1000).isoformat()
            quote['pricing_snapshot'].update(id=str(policy['id']), zone_id=str(policy['zone_id']), updated_at=stamp)
            quote['pricing_version'] = f"{policy['id']}:{stamp}"
    quotes = {str(v['id']): v for v in documents.get('rides.farequote', [])}
    for ride in documents.get('rides.ride', []):
        if str(ride['quote_id']) in quotes:
            ride['pricing_version'] = quotes[str(ride['quote_id'])]['pricing_version']
    prepared = {}
    for label, rows in documents.items():
        model = registry[label]
        prepared[label] = [{field.column: field.get_db_prep_save(row[field.attname], connection)
                            for field in model._meta.local_fields} for row in rows]
    return prepared


def digest(document):
    return hashlib.sha256(json_util.dumps(document, json_options=json_util.CANONICAL_JSON_OPTIONS, sort_keys=True).encode()).hexdigest()


def import_snapshot(snapshot, using='default', apply=False):
    connection = connections[using]
    if connection.settings_dict['ENGINE'] != 'django_mongodb_backend':
        raise CommandError('The target must use the official MongoDB backend.')
    hello = connection.database.client.admin.command('hello')
    if not hello.get('setName') and hello.get('msg') != 'isdbgrid':
        raise CommandError('Replica-set transactions are required.')
    registry = models_for_transfer()
    source_hash = digest(snapshot)
    prepared = prepare(copy.deepcopy(snapshot), connection)
    summary = {label: len(rows) for label, rows in prepared.items()}
    if not apply:
        return {'applied': False, 'counts': summary, 'source_sha256': source_hash}
    manifest = connection.get_collection('trivia_transfer_manifest')
    source_hash = digest(snapshot)
    previous = manifest.find_one({'_id': 'source'})
    if previous and previous['sha256'] != source_hash:
        raise CommandError('Target belongs to a different source snapshot. Use a fresh target.')
    if previous is None:
        for label, model in registry.items():
            if label not in SEED_MODELS and model.objects.using(using).exists():
                raise CommandError('Target contains non-seed application data. Refusing overwrite.')
        manifest.insert_one({'_id': 'source', 'sha256': source_hash, 'state': 'importing'})
    verified = {}
    for label, rows in prepared.items():
        model = registry[label]
        collection = connection.get_collection(model._meta.db_table)
        for document in rows:
            pk = model._meta.pk.column
            if not previous or previous.get('state') != 'verified':
                collection.replace_one({pk: document[pk]}, document, upsert=True)
            actual = collection.find_one({pk: document[pk]})
            actual = {key: actual[key] for key in document}
            if digest(document) != digest(actual):
                raise CommandError(f'Content verification failed for {label}; target is not ready.')
        verified[label] = len(rows)
    for label, model in registry.items():
        if label not in SEED_MODELS and model.objects.using(using).count() != len(prepared.get(label, [])):
            raise CommandError(f'Target row-count reconciliation failed for {label}.')
    manifest.update_one({'_id': 'source'}, {'$set': {'state': 'verified', 'counts': verified}})
    return {'applied': True, 'verified': True, 'counts': verified, 'source_sha256': source_hash}
