import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { createHash } from 'node:crypto';
const root = fileURLToPath(new URL('../', import.meta.url));
const source = readFileSync(path.join(root, 'legal/policies.json'), 'utf8');
const content = JSON.parse(source);
const digest = createHash('sha256').update(source).digest('hex');
const manifest = JSON.stringify({ version: content.version, sha256: digest, status: content.status, attribution: content.attribution }, null, 2) + '\n';
const outputs = new Map([
  ['MobileApp/assets/legal/policies.json', source],
  ['WebApp/src/legal/policies.json', source],
  ['MobileApp/assets/legal/content-digest.json', manifest],
  ['WebApp/src/legal/content-digest.json', manifest],
  ['Backend/accounts/legal_content_manifest.json', manifest],
  ['legal/content-digest.json', manifest],
]);
for (const [id, doc] of Object.entries(content.documents)) {
  const text = `# Trivia — ${doc.title}\n\n${content.reviewNotice}\n\nVersion: ${content.version}\n\nEffective date: ${content.effectiveDate ?? 'To be confirmed'}\n\n${content.attribution}\n\n` + doc.sections.map((s, i) => `## ${i + 1}. ${s.title}\n\n${s.paragraphs.join('\n\n')}\n`).join('\n');
  outputs.set(`legal/${id === 'terms' ? 'TERMS_AND_CONDITIONS' : 'PRIVACY_POLICY'}.md`, text);
}
let stale = false;
for (const [name, data] of outputs) {
  const target = path.join(root, name);
  if (process.argv.includes('--check')) {
    let actual;
    try { actual = readFileSync(target, 'utf8'); } catch { actual = null; }
    if (actual !== data) { console.error(`Legal content out of sync: ${name}`); stale = true; }
  } else {
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, data);
  }
}
if (stale) process.exitCode = 1;
else console.log(process.argv.includes('--check') ? 'Legal content is synchronized.' : 'Legal content synchronized.');
