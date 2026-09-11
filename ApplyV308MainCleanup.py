from pathlib import Path

# Composition Lab Native 3.0.8
# Main should expose only musically central file actions. JSON remains available
# internally/for technical workflows, but is no longer a Main-page button.

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

old = '        functionRow.addArrangedSubview(NSButton(title: "JSON sichern", target: self, action: #selector(saveJSONPressed)))\n'
if old not in s:
    raise SystemExit('V3.0.8: Main JSON save button not found')
s = s.replace(old, '', 1)

s = s.replace('"interfaceVersion": "3.0.7"', '"interfaceVersion": "3.0.8"')

p.write_text(s, encoding='utf-8')
print('Applied V3.0.8: JSON save removed from Main; functionality retained internally.')
