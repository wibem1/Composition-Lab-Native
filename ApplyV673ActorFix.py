from pathlib import Path

p = Path('Sources/AppDelegate.swift')
s = p.read_text(encoding='utf-8')
old = '    @objc private func menuSaveDiagnosticFromApp() {\n'
new = '    @MainActor @objc private func menuSaveDiagnosticFromApp() {\n'
if old not in s:
    raise SystemExit('V6.7.3: diagnostic menu actor anchor not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('Applied V6.7.3 MainActor fix for diagnostic menu action.')
