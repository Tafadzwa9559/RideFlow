import json
from pathlib import Path
from django.core.management.base import BaseCommand, CommandError
from django.db import connection
from core.services.transfer import import_snapshot


class Command(BaseCommand):
    help = 'Validate a legacy snapshot; writes require --apply and an exact --target-database acknowledgement.'

    def add_arguments(self, parser):
        parser.add_argument('--input', required=True)
        parser.add_argument('--apply', action='store_true')
        parser.add_argument('--target-database')

    def handle(self, *args, **options):
        if options['apply'] and options['target_database'] != connection.settings_dict['NAME']:
            raise CommandError('Supply --target-database matching the configured isolated target.')
        snapshot = json.loads(Path(options['input']).read_text())
        result = import_snapshot(snapshot, apply=options['apply'])
        self.stdout.write(json.dumps(result, sort_keys=True))
