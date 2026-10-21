"""Revalidate immutable renderer outputs after correcting .mid/.midi discovery."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
rows = json.loads((root / 'comparison.json').read_text(encoding='utf-8-sig'))
expected = {(phase, variant, run) for phase in ('clean', 'many-applications')
            for variant in ('original', 'rebuilt-control', 'lazy-appinfo') for run in range(3)}
assert {(r['phase'], r['variant'], r['run']) for r in rows} == expected
assert len(rows) == len(expected)
midi_hashes = set()
for row in rows:
    folder = root / f"{row['phase']}-{row['variant']}-{row['run']}-Noten Übung"
    midi = [p for p in folder.glob('score*.mid*') if p.suffix in ('.mid', '.midi')]
    pages = list(folder.glob('score*.svg'))
    assert not row['timedOut'] and row['exitCode'] == 0, row
    assert len(midi) == 1 and pages, folder
    data = midi[0].read_bytes()
    assert len(data) > 14 and data[:4] == b'MThd', midi[0]
    assert all('textedit:' in p.read_text(encoding='utf-8') for p in pages), folder
    midi_hashes.add(hashlib.sha256(data).hexdigest())
    row['passed'] = True
assert len(midi_hashes) == 1, 'Runtime variant changed the generated MIDI'
(root / 'validated-comparison.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
print(f'{len(rows)}/{len(expected)} complete SVG/MIDI results; identical MIDI; no timeouts.')
print('The user-specific startup failure was NOT reproduced; no runtime integration or release authorized by this result.')
