from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# The concept stage must obey the same hard bar-count contract as the score stage.
old = '''                              user: ComposerPrompts.conceptPrompt(prompt) + "\\n\\nWICHTIG: Formuliere die Kompositionsidee sehr knapp: höchstens 3 kurze Sätze. Nur Charakter, zentrale musikalische Idee und grobe Entwicklung. Keine Takt-für-Takt-Beschreibung, keine ausführliche Analyse und keine Noten-für-Noten-Anweisungen.",
                              wantJSON: false) { [weak self] firstResult in
'''
new = '''                              user: ComposerPrompts.conceptPrompt(prompt) + "\\n\\nWICHTIG: Formuliere die Kompositionsidee sehr knapp: höchstens 3 kurze Sätze. Nur Charakter, zentrale musikalische Idee und grobe Entwicklung. Keine Takt-für-Takt-Beschreibung, keine ausführliche Analyse und keine Noten-für-Noten-Anweisungen. Die im Auftrag angegebene Taktzahl ist VERBINDLICH: Plane ausschließlich ein Stück genau dieser Länge. Beschreibe niemals Formteile, Takte oder eine Coda außerhalb dieser Taktzahl.",
                              wantJSON: false) { [weak self] firstResult in
'''
if old not in s:
    raise SystemExit('V6.6.9: concise concept call not found')
s = s.replace(old, new, 1)

# Make the saved diagnostic faithfully show the contract sent to stage 1.
s = s.replace(
    '"conceptPrompt": ComposerPrompts.conceptPrompt(prompt) + "\\n\\n[Kurze Kompositionsidee: max. 3 Sätze, keine Takt-für-Takt-Beschreibung.]",',
    '"conceptPrompt": ComposerPrompts.conceptPrompt(prompt) + "\\n\\n[Kurze Kompositionsidee: max. 3 Sätze; die angegebene Taktzahl ist verbindlich und darf in der Planung nicht überschritten werden.]",',
    1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.9 concept bar-count contract.')

# The diagnostic action already exists under Technisches. Add a second, explicit
# top-level menu so it cannot be overlooked when reproducing a composition bug.
a = Path('Sources/AppDelegate.swift')
t = a.read_text(encoding='utf-8')
anchor = '''        let displayItem = NSMenuItem(title: "Darstellung", action: nil, keyEquivalent: "")
'''
menu = '''        let diagnoseItem = NSMenuItem(title: "Diagnose", action: nil, keyEquivalent: "")
        let diagnose = NSMenu(title: "Diagnose")
        let saveDiagnostic = NSMenuItem(title: "Diagnosedatei sichern …", action: #selector(MainViewController.menuSaveDiagnostic), keyEquivalent: "d")
        saveDiagnostic.keyEquivalentModifierMask = [.command, .shift]
        diagnose.addItem(saveDiagnostic)
        diagnoseItem.submenu = diagnose
        main.addItem(diagnoseItem)

'''
if anchor not in t:
    raise SystemExit('V6.6.9: AppDelegate display menu anchor not found')
if 'let diagnoseItem = NSMenuItem(title: "Diagnose"' not in t:
    t = t.replace(anchor, menu + anchor, 1)
a.write_text(t, encoding='utf-8')
print('Added visible Diagnose menu with Diagnosedatei sichern.')
