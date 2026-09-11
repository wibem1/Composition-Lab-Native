from pathlib import Path

# V6.7.4: two concrete fixes from the V6.7.3 test:
# 1) diagnostic save must actually present a save sheet after a menu click;
# 2) MusicChat must not claim a score/draft exists before the Compose button is pressed,
#    and must not ask for settings that are already present in the top controls.

m = Path('Sources/MainViewController.swift')
s = m.read_text(encoding='utf-8')

# --- Diagnostic export: use a sheet instead of synchronous runModal().
start = s.find('    @objc private func saveDiagnosticPressed() {\n')
end = s.find('    private func safeFilename(_ s:String)->String {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.7.4: saveDiagnosticPressed block not found')

new_save = r'''    @objc private func saveDiagnosticPressed() {
        guard let diagnostic = lastDiagnostic else {
            status("Noch keine Diagnosedaten vorhanden.", good: false)
            NSSound.beep()
            return
        }

        let data: Data
        do {
            guard JSONSerialization.isValidJSONObject(diagnostic) else {
                throw NSError(domain: "CompositionLab.Diagnostic", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Die Diagnosedaten enthalten einen nicht speicherbaren Wert."])
            }
            data = try JSONSerialization.data(withJSONObject: diagnostic,
                                              options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        } catch {
            status("Diagnosedaten konnten nicht vorbereitet werden: \(error.localizedDescription)", good: false)
            NSSound.beep()
            return
        }

        guard let window = view.window else {
            status("Das Hauptfenster ist für den Diagnose-Export nicht verfügbar.", good: false)
            NSSound.beep()
            return
        }

        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        let base = lastScore?.ti.trimmingCharacters(in: .whitespacesAndNewlines)
        panel.nameFieldStringValue = safeFilename((base?.isEmpty == false ? base! : "Composition-Lab") + "-Diagnose-Engine14") + ".json"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        status("Speicherort für Diagnosedatei wählen …", good: true)
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            guard response == .OK, let url = panel.url else {
                self.status("Diagnosedatei-Speichern abgebrochen.", good: true)
                return
            }
            do {
                try data.write(to: url, options: .atomic)
                self.status("Diagnosedatei gespeichert: \(url.lastPathComponent)", good: true)
            } catch {
                self.status("Diagnosedatei konnte nicht gespeichert werden: \(error.localizedDescription)", good: false)
                NSSound.beep()
            }
        }
    }

'''
s = s[:start] + new_save + s[end:]

# --- MusicChat semantics: make the dialogue contract unambiguous.
old_rules = '''        - Wenn etwas musikalisch relevant mehrdeutig ist, frage kurz und konkret nach, statt zu raten.\n        - Wenn der Nutzer nur analysieren, vergleichen oder diskutieren möchte, antworte inhaltlich und formuliere keinen neuen Kompositionsauftrag.\n        - Wenn sich aus dem Dialog ein hinreichend klarer Kompositionsauftrag ergibt, formuliere ihn knapp als compositionBrief. Führe ihn noch NICHT aus.\n        - sourceSlots enthält nur Stücke, die der Nutzer nach dem Gesprächskontext tatsächlich als Material für die spätere Komposition verwenden will. Sonst bleibt die Liste leer.\n        - Die oberen Einstellungen sind aktuelle Rahmenbedingungen, sofern der Nutzer sie im Dialog nicht ausdrücklich relativiert.\n'''
new_rules = '''        - Wenn etwas musikalisch relevant mehrdeutig ist, frage kurz und konkret nach, statt zu raten.\n        - Frage NICHT nach Taktzahl, Taktart, Tempo, Tonart oder Besetzung, wenn diese Werte oben bereits eingetragen sind. Diese Werte gelten als vorhanden und ausreichend.\n        - Wenn der Nutzer nur analysieren, vergleichen oder diskutieren möchte, antworte inhaltlich und formuliere keinen neuen Kompositionsauftrag.\n        - Wenn sich aus dem Dialog ein hinreichend klarer Kompositionsauftrag ergibt, formuliere ihn knapp als compositionBrief. Führe ihn noch NICHT aus.\n        - Behaupte in der Dialogantwort niemals, dass bereits ein Entwurf, Stück, MIDI, MusicXML oder eine Partitur erzeugt wurde. Vor dem blauen Komponieren-Button existiert nur ein vorbereiteter Auftrag.\n        - Wenn der Auftrag bereits eindeutig ist, bestätige das knapp und weise höchstens darauf hin, dass die eigentliche Komposition erst mit dem blauen Button startet. Stelle dann keine unnötige Rückfrage.\n        - sourceSlots enthält nur Stücke, die der Nutzer nach dem Gesprächskontext tatsächlich als Material für die spätere Komposition verwenden will. Sonst bleibt die Liste leer.\n        - Die oberen Einstellungen sind aktuelle Rahmenbedingungen, sofern der Nutzer sie im Dialog nicht ausdrücklich relativiert.\n'''
if old_rules not in s:
    raise SystemExit('V6.7.4: MusicChat rules anchor not found')
s = s.replace(old_rules, new_rules, 1)

# The visible right-hand idea panel should not continue showing an unrelated old
# composition concept once a new, clear brief has been prepared in MusicChat.
old_brief = '''                        if let brief, !brief.isEmpty {\n                            self.promptView.string = brief\n                            self.musicChatCompositionContextOverride = self.musicChatSourceMaterial(sourceSlots)\n                            self.saveSettingsFromUI()\n                        }\n'''
new_brief = '''                        if let brief, !brief.isEmpty {\n                            self.promptView.string = brief\n                            self.musicChatCompositionContextOverride = self.musicChatSourceMaterial(sourceSlots)\n                            self.conceptView.string = "Vorbereiteter Kompositionsauftrag:\\n\\n" + brief + "\\n\\nDie Partitur entsteht erst mit ‚Mit gewählter KI komponieren‘."\n                            self.saveSettingsFromUI()\n                        }\n'''
if old_brief not in s:
    raise SystemExit('V6.7.4: prepared brief UI anchor not found')
s = s.replace(old_brief, new_brief, 1)

# Current diagnostic version for dialogue runs and fallback exports.
s = s.replace('"interfaceVersion": "6.7.1",\n            "entryPoint": "musicchat-dialogue",',
              '"interfaceVersion": "6.7.4",\n            "entryPoint": "musicchat-dialogue",', 1)
s = s.replace('"interfaceVersion": "6.7.1",\n                "entryPoint": "fallback-current-state",',
              '"interfaceVersion": "6.7.4",\n                "entryPoint": "fallback-current-state",', 1)

m.write_text(s, encoding='utf-8')

# Menu callback: defer one run-loop turn so the menu has fully closed before
# MainViewController presents the save sheet.
a = Path('Sources/AppDelegate.swift')
t = a.read_text(encoding='utf-8')
old = '''    @MainActor @objc private func menuSaveDiagnosticFromApp() {\n        guard let mainVC else { NSSound.beep(); return }\n        mainVC.menuSaveDiagnostic()\n    }\n'''
new = '''    @MainActor @objc private func menuSaveDiagnosticFromApp() {\n        guard let mainVC else { NSSound.beep(); return }\n        DispatchQueue.main.async {\n            mainVC.menuSaveDiagnostic()\n        }\n    }\n'''
if old not in t:
    raise SystemExit('V6.7.4: diagnostic AppDelegate callback anchor not found')
t = t.replace(old, new, 1)
a.write_text(t, encoding='utf-8')

print('Applied V6.7.4 diagnostic save sheet and corrected MusicChat dialogue semantics.')
