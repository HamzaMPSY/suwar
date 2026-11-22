"""Regenerate the iOS widget's exact Warsh subset from the shared catalog."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'assets/quran/remembrance-catalog.json').read_text())
if catalog['source'] != 'kfgqpc-warsh-v10-6214' or catalog['version'] != 1:
    raise ValueError('Unknown source catalog')
rows = json.loads((root / 'assets/quran/warsh-data.json').read_text())
source = {(r['sura_no'], r['aya_no']): r['aya_text'] for r in rows}
entries = catalog['entries']
if len({e['id'] for e in entries}) != len(entries):
    raise ValueError('Duplicate ayah reference')
subset = []
for entry in entries:
    if entry['id'] != f"{entry['surahId']}:{entry['ayahNumber']}":
        raise ValueError('Mismatched ayah reference')
    subset.append({**entry, 'sourceText': source[(entry['surahId'], entry['ayahNumber'])]})
target = root / 'ios/AyahWidget/verses.json'
target.write_text(json.dumps(subset, ensure_ascii=False, indent=2) + '\n')
print(f'Generated {len(subset)} complete source ayahs in {target.relative_to(root)}')
