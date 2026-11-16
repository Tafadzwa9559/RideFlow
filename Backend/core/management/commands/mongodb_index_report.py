"""Read-only inventory suitable for staging/Atlas operational checks."""
import json
from django.core.management.base import BaseCommand
from django.db import connection


class Command(BaseCommand):
    help = 'Report application index names and an optional history query plan; never returns records or credentials.'

    def add_arguments(self, parser):
        parser.add_argument('--explain', action='store_true')

    def handle(self, *args, **options):
        from django.apps import apps
        report = {}
        for model in apps.get_models():
            table = model._meta.db_table
            report[table] = sorted(connection.get_collection(table).index_information())
        if options['explain']:
            # Representative shape only; no actual passenger identity is read or printed.
            from bson import ObjectId
            plan = connection.get_collection('rides_ride').find({'passenger_id': ObjectId('000000000000000000000000')}).sort('created_at', -1).explain()
            def stages(node):
                found = []
                if isinstance(node, dict):
                    if 'stage' in node:
                        found.append({'stage': node['stage'], **({'index': node['indexName']} if 'indexName' in node else {})})
                    for value in node.values():
                        found.extend(stages(value))
                elif isinstance(node, list):
                    for value in node:
                        found.extend(stages(value))
                return found
            report['history_query_plan'] = stages(plan.get('queryPlanner', {}).get('winningPlan', {}))
        self.stdout.write(json.dumps(report, indent=2))
