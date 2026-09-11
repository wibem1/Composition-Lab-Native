from pathlib import Path

# V6.7.5: the V6.7.4 sheet still did not become visible on the user's Mac.
# Present the save panel modally only after the menu tracking loop has ended.
# Also make the right-hand prepared-composition state internally consistent:
# do not show metadata from the previously loaded score beneath a new brief.

m = Path('Sources/MainViewController.swift')
s = m.read_text(encoding='utf-8')

start = s.find('    @objc private func saveDiagnosticPressed() {\n')
end = s.find('    private func safeFilename(_ s:String)->String {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.7.5: saveDiagnosticPressed block not found')

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

        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        let base = lastScore?.ti.trimmingCharacters(in: .whitespacesAndNewlines)
        panel.nameFieldStringValue = safeFilename((base?.isEmpty == false ? base! : "Composition-Lab") + "-Diagnose-Engine14") + ".json"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        status("Speicherort für Diagnosedatei wählen …", good: true)
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            status("Diagnosedatei-Speichern abgebrochen.", good: true)
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            status("Diagnosedatei gespeichert: \(url.lastPathComponent)", good: true)
        } catch {
            status("Diagnosedatei konnte nicht gespeichert werden: \(error.localizedDescription)", good: false)
            NSSound.beep()
        }
    }

'''
s = s[:start] + new_save + s[end:]

old_brief = '''                            self.conceptView.string = "Vorbereiteter Kompositionsauftrag:\\n\\n" + brief + "\\n\\nDie Partitur entsteht erst mit ‚Mit gewählter KI komponieren‘."\n                            self.saveSettingsFromUI()\n'''
new_brief = '''                            self.conceptView.string = "Vorbereiteter Kompositionsauftrag:\\n\\n" + brief + "\\n\\nDie Partitur entsteht erst mit ‚Mit gewählter KI komponieren‘."\n                            self.resultLabel.stringValue = "Für diesen vorbereiteten Auftrag existiert noch keine Partitur."\n                            self.saveSettingsFromUI()\n'''
if old_brief not in s:
    raise SystemExit('V6.7.5: prepared-state UI anchor not found')
s = s.replace(old_brief, new_brief, 1)

s = s.replace('"interfaceVersion": "6.7.4",\n            "entryPoint": "musicchat-dialogue",',
              '"interfaceVersion": "6.7.5",\n            "entryPoint": "musicchat-dialogue",', 1)
s = s.replace('"interfaceVersion": "6.7.4",\n                "entryPoint": "fallback-current-state",',
              '"interfaceVersion": "6.7.5",\n                "entryPoint": "fallback-current-state",', 1)

m.write_text(s, encoding='utf-8')

# Defer long enough to be safely outside NSMenu tracking, then run the modal save panel.
a = Path('Sources/AppDelegate.swift')
t = a.read_text(encoding='utf-8')
old = '''    @MainActor @objc private func menuSaveDiagnosticFromApp() {\n        guard let mainVC else { NSSound.beep(); return }\n        DispatchQueue.main.async {\n            mainVC.menuSaveDiagnostic()\n        }\n    }\n'''
new = '''    @MainActor @objc private func menuSaveDiagnosticFromApp() {\n        guard let mainVC else { NSSound.beep(); return }\n        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {\n            mainVC.menuSaveDiagnostic()\n        }\n    }\n'''
if old not in t:
    raise SystemExit('V6.7.5: AppDelegate diagnostic callback anchor not found')
t = t.replace(old, new, 1)
a.write_text(t, encoding='utf-8')

print('Applied V6.7.5 modal diagnostic save and coherent prepared-composition UI.')
