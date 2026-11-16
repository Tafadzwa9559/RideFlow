import json
import os
from pathlib import Path
from django.core.management.base import BaseCommand
from django.db import connections
from rideflow.legacy_mysql import source_database
from core.services.transfer import export_sql


class Command(BaseCommand):
    help = 'Read-only legacy MySQL export. Quiesce writers and use a restored source for rehearsal.'

    def add_arguments(self, parser):
        parser.add_argument('--output', required=True)

    def handle(self, *args, **options):
        database = {**connections['default'].settings_dict, **source_database()}
        database['TIME_ZONE'] = None
        connections.databases['legacy_source'] = database
        source = connections['legacy_source']
        try:
            snapshot = export_sql(source)
            target = Path(options['output'])
            target.parent.mkdir(parents=True, exist_ok=True)
            descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, 'w') as stream:
                json.dump(snapshot, stream, sort_keys=True)
            self.stdout.write('Snapshot exported; protect this file as sensitive account data.')
        finally:
            source.close()
