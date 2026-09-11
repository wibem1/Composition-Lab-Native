from pathlib import Path

# V6.7.2: make diagnostic export deterministic. The menu action is routed
# explicitly through AppDelegate to the current MainViewController instead of
# relying on the responder chain, and the save routine reports serialization
# errors instead of failing silently.

m = Path('Sources/MainViewController.swift')
s = m.read_text(encoding='utf-8')

start = s.find('    @objc private func saveDiagnosticPressed() {\n')
end = s.find('    private func safeFilename(_ s:String)->String {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.7.2: saveDiagnosticPressed block not found')

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

        guard panel.runModal() == .OK, let url = panel.url else {
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
m.write_text(s, encoding='utf-8')

# Route every diagnostic menu item explicitly through AppDelegate. AppDelegate
# owns mainVC, so this works regardless of the current first responder.
a = Path('Sources/AppDelegate.swift')
t = a.read_text(encoding='utf-8')

method_anchor = '    @objc private func menuShowMainWindow() { showMainWindow() }\n'
method_new = '''    @objc private func menuShowMainWindow() { showMainWindow() }\n\n    @objc private func menuSaveDiagnosticFromApp() {\n        guard let mainVC else { NSSound.beep(); return }\n        mainVC.menuSaveDiagnostic()\n    }\n'''
if 'menuSaveDiagnosticFromApp' not in t:
    if method_anchor not in t:
        raise SystemExit('V6.7.2: AppDelegate menu method anchor not found')
    t = t.replace(method_anchor, method_new, 1)

old_action = 'action: #selector(MainViewController.menuSaveDiagnostic), keyEquivalent:'
new_action = 'action: #selector(menuSaveDiagnosticFromApp), keyEquivalent:'
if old_action not in t:
    raise SystemExit('V6.7.2: no diagnostic menu action found')
t = t.replace(old_action, new_action)

# NSMenuItems created with addItem(withTitle:...) have no explicit target; assign
# AppDelegate as target for the Technisches entry. The top-level Diagnose entry
# created by ApplyV669 is handled by the generic post-pass below.
technical_line = '        technical.addItem(withTitle: "Diagnosedatei sichern …", action: #selector(menuSaveDiagnosticFromApp), keyEquivalent: "d")\n'
if technical_line in t:
    t = t.replace(technical_line,
                  '        let technicalDiagnostic = technical.addItem(withTitle: "Diagnosedatei sichern …", action: #selector(menuSaveDiagnosticFromApp), keyEquivalent: "d")\n        technicalDiagnostic.target = self\n', 1)

# The separate Diagnose menu uses an NSMenuItem variable. Set its target too.
top_line = '        let saveDiagnostic = NSMenuItem(title: "Diagnosedatei sichern …", action: #selector(menuSaveDiagnosticFromApp), keyEquivalent: "d")\n'
if top_line in t:
    t = t.replace(top_line, top_line + '        saveDiagnostic.target = self\n', 1)

a.write_text(t, encoding='utf-8')
print('Applied V6.7.2 diagnostic save routing and robust export.')
