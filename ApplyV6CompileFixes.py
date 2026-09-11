from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Main piece deck stores subclass instances in the controller's [NSButton] array.
s = s.replace('        var buttons: [PieceSlotDropButton] = []\n',
              '        var buttons: [NSButton] = []\n', 1)

required = [
    'var buttons: [NSButton] = []',
    'PieceSlotDropButton(title:',
    'buildTechnicalWorkspace(experimentWorkspaceHost)'
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('V6 compile fixes incomplete: ' + ', '.join(missing))

p.write_text(s, encoding='utf-8')
print('Applied V6 compile fixes.')
