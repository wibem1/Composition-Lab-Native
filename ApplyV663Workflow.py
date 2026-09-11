from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# 1) MusicChat: remove the redundant upper composition-order text area.
old = '''        let title = NSTextField(labelWithString: "MusicChat"); title.font = .systemFont(ofSize: 20, weight: .bold); cs.addArrangedSubview(title)\n        promptView.font = .systemFont(ofSize: 13); let promptScroll = textScroll(promptView, minHeight: 58); promptScroll.heightAnchor.constraint(equalToConstant: 66).isActive = true; cs.addArrangedSubview(promptScroll); promptScroll.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true\n        chatView.isEditable = false; chatView.isSelectable = true; chatView.font = .systemFont(ofSize: 13); let log = textScroll(chatView, minHeight: 170); cs.addArrangedSubview(log); log.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true; log.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true; log.setContentHuggingPriority(.defaultLow, for: .vertical)\n'''
new = '''        let title = NSTextField(labelWithString: "MusicChat"); title.font = .systemFont(ofSize: 20, weight: .bold); cs.addArrangedSubview(title)\n        chatView.isEditable = false; chatView.isSelectable = true; chatView.font = .systemFont(ofSize: 13); let log = textScroll(chatView, minHeight: 230); cs.addArrangedSubview(log); log.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true; log.heightAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true; log.setContentHuggingPriority(.defaultLow, for: .vertical)\n'''
if old not in s:
    raise SystemExit('V6.6.3: MusicChat upper prompt block not found')
s = s.replace(old, new, 1)

s = s.replace('chatInput.placeholderString = "Frage, Änderungswunsch oder neue musikalische Idee …"',
              'chatInput.placeholderString = "Kompositionsauftrag, Frage oder Änderungswunsch …"', 1)

# 2) The single visible MusicChat input is now also the composition assignment.
old = '''        let taskRaw=promptView.string.trimmingCharacters(in:.whitespacesAndNewlines)\n        let task=taskRaw.isEmpty ? "" : taskRaw\n'''
new = '''        let visibleTask = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)\n        let legacyTask = promptView.string.trimmingCharacters(in: .whitespacesAndNewlines)\n        let task = !visibleTask.isEmpty ? visibleTask : legacyTask\n'''
if old not in s:
    raise SystemExit('V6.6.3: basePrompt task marker not found')
s = s.replace(old, new, 1)

# 3) Every newly generated composition gets a free piece slot instead of overwriting the active piece.
old = '        pendingCompositionSlot = activePieceSlot\n'
new = '''        if pieceSlots[activePieceSlot] == nil {\n            pendingCompositionSlot = activePieceSlot\n        } else if let freeSlot = pieceSlots.firstIndex(where: { $0 == nil }) {\n            pendingCompositionSlot = freeSlot\n        } else {\n            status("Alle 10 Stück-Slots sind belegt. Bitte zuerst einen Slot löschen.", good: false)\n            return\n        }\n'''
if old not in s:
    raise SystemExit('V6.6.3: pending composition slot marker not found')
s = s.replace(old, new, 1)

# 4) Keep the musical idea deliberately short. It remains useful as a compositional seed,
#    but no longer becomes a bar-by-bar essay.
old = '''                              user: ComposerPrompts.conceptPrompt(prompt),\n                              wantJSON: false) { [weak self] firstResult in\n'''
new = '''                              user: ComposerPrompts.conceptPrompt(prompt) + "\\n\\nWICHTIG: Formuliere die Kompositionsidee sehr knapp: höchstens 3 kurze Sätze. Nur Charakter, zentrale musikalische Idee und grobe Entwicklung. Keine Takt-für-Takt-Beschreibung, keine ausführliche Analyse und keine Noten-für-Noten-Anweisungen.",\n                              wantJSON: false) { [weak self] firstResult in\n'''
if old not in s:
    raise SystemExit('V6.6.3: concept call marker not found')
s = s.replace(old, new, 1)

# Diagnostic should show the actual short-concept instruction used.
s = s.replace('"conceptPrompt": ComposerPrompts.conceptPrompt(prompt),',
              '"conceptPrompt": ComposerPrompts.conceptPrompt(prompt) + "\\n\\n[Kurze Kompositionsidee: max. 3 Sätze, keine Takt-für-Takt-Beschreibung.]",', 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.3: next-free-slot composition, concise concept, one MusicChat input.')
