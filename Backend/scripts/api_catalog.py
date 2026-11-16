"""Regenerate a transparent method/path catalog from the validated OpenAPI artifact."""
from collections import Counter
from pathlib import Path
import yaml

base = Path(__file__).resolve().parents[1]
schema = yaml.safe_load((base / 'docs/openapi.yaml').read_text())
operations = []
counts = Counter()
for path, methods in schema['paths'].items():
    for method, operation in methods.items():
        if method not in {'get', 'post', 'patch', 'put', 'delete'}:
            continue
        alias = operation.get('x-alias-of')
        tag = operation['tags'][0]
        operations.append((tag, method.upper(), path, alias))
        if not alias:
            counts[tag] += 1
lines = ['# Trivia API endpoint catalog', '',
         f'**{sum(counts.values())} distinct documented REST operations** (HTTP method + canonical path), plus {sum(bool(r[3]) for r in operations)} explicitly marked semantic aliases. Mobile/legacy compatibility aliases, documentation, health, HEAD and OPTIONS routes are excluded from the distinct total.', '',
         'All entries below are connected to implemented handlers. `x-alias-of` in OpenAPI identifies exact semantic aliases so totals do not count the same behavior twice.', '',
         '| API group | Distinct operations |', '|---|---:|']
lines += [f'| {group} | {count} |' for group, count in sorted(counts.items())]
lines += [f'| **Total** | **{sum(counts.values())}** |', '', '| Group | Method | Path | Alias of |', '|---|---|---|---|']
lines += [f'| {group} | {method} | `{path}` | {alias or "—"} |' for group, method, path, alias in sorted(operations)]
(base / 'docs/endpoint-catalog.md').write_text('\n'.join(lines) + '\n')
print(f'{sum(counts.values())} distinct operations; {len(operations)-sum(counts.values())} marked aliases; {len(operations)} documented method/path entries')
