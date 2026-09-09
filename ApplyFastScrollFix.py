from pathlib import Path

changed = 0
for p in Path('Sources').glob('*.swift'):
    if p.name == 'FastScrollView.swift':
        continue
    s = p.read_text(encoding='utf-8')
    n = s.replace('NSScrollView()', 'FastScrollView()')
    n = n.replace('NSScrollView(frame:', 'FastScrollView(frame:')
    if n != s:
        p.write_text(n, encoding='utf-8')
        changed += 1

print(f'Fast mouse-wheel scrolling applied to {changed} Swift source file(s).')
