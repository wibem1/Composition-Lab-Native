from pathlib import Path
p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')
s = s.replace('        mainPieceSlotButtons = buttons\n        updatePieceSlotButtons()\n        return stack\n',
              '        mainPieceSlotButtons = buttons.map { $0 as NSButton }\n        updatePieceSlotButtons()\n        return stack\n', 1)
if 'mainPieceSlotButtons = buttons.map { $0 as NSButton }' not in s:
    raise SystemExit('V6 Main layout fix: slot button assignment not found')
p.write_text(s, encoding='utf-8')
print('Applied V6 central slot button type fix.')
