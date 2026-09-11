from pathlib import Path

# Composition Lab Native 3.0.7
# Restore CLAB as the central single-composition interchange/work format.
# A CLAB file now preserves the score together with the CURRENT editable
# composition assignment and composition idea, plus provider/model/settings.
# CLABPROJECT remains the multi-slot whole-project format.

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# ---------------------------------------------------------------------------
# 1) A versioned 3.x CLAB document. Keep this independent of the old legacy
#    CLAB decoder so older CLAB files can still fall back to the previous path.
# ---------------------------------------------------------------------------
marker = '    @objc private func workspaceChanged() {\n'
if 'private struct V307CLABDocument' not in s:
    block = r'''    private struct V307CLABDocument: Codable {
        var format: String
        var version: Int
        var title: String
        var score: Score
        var compositionAssignment: String
        var compositionIdea: String
        var provider: Provider
        var model: String
        var settings: AppSettings
        var createdAt: Date
    }

'''
    if marker not in s:
        raise SystemExit('V3.0.7: workspace action marker not found')
    s = s.replace(marker, block + marker, 1)

# ---------------------------------------------------------------------------
# 2) Visible Main actions. CLAB is central, so saving and loading must not be
#    hidden in a context menu.
# ---------------------------------------------------------------------------
old = '''        functionRow.addArrangedSubview(NSButton(title: "MIDI sichern", target: self, action: #selector(saveMIDIPressed)))\n        functionRow.addArrangedSubview(NSButton(title: "JSON sichern", target: self, action: #selector(saveJSONPressed)))\n'''
new = '''        functionRow.addArrangedSubview(NSButton(title: "MIDI sichern", target: self, action: #selector(saveMIDIPressed)))\n        functionRow.addArrangedSubview(NSButton(title: "JSON sichern", target: self, action: #selector(saveJSONPressed)))\n        functionRow.addArrangedSubview(NSButton(title: "CLAB sichern", target: self, action: #selector(v307SaveCLABPressed)))\n        functionRow.addArrangedSubview(NSButton(title: "CLAB laden …", target: self, action: #selector(v307LoadCLABPressed)))\n'''
if old not in s:
    raise SystemExit('V3.0.7: bottom action buttons anchor not found')
s = s.replace(old, new, 1)

# ---------------------------------------------------------------------------
# 3) Save/load actions.
# ---------------------------------------------------------------------------
action_marker = '    @objc private func v651LoadMIDIIntoSlot(_ sender: NSMenuItem) {\n'
if '@objc private func v307SaveCLABPressed()' not in s:
    actions = r'''    @objc private func v307SaveCLABPressed() {
        guard let score = lastScore else {
            status("Keine Komposition zum Sichern vorhanden.", good: false)
            NSSound.beep()
            return
        }

        saveSettingsFromUI()
        let currentProvider = lastProvider ?? provider
        let currentModel = lastModel ?? model
        let doc = V307CLABDocument(
            format: "composition-lab-clab",
            version: 3,
            title: score.ti,
            score: score,
            compositionAssignment: promptView.string,
            compositionIdea: conceptView.string,
            provider: currentProvider,
            model: currentModel,
            settings: settings,
            createdAt: Date()
        )

        let panel = NSSavePanel()
        panel.allowedFileTypes = ["clab"]
        panel.nameFieldStringValue = safeFilename(score.ti) + ".clab"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try JSONEncoder.pretty.encode(doc)
            try data.write(to: url, options: .atomic)
            status("CLAB gespeichert: \(url.lastPathComponent) · Auftrag und Kompositionsidee sind enthalten.", good: true)
        } catch {
            status("CLAB konnte nicht gespeichert werden: \(error.localizedDescription)", good: false)
            NSSound.beep()
        }
    }

    @objc private func v307LoadCLABPressed() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["clab"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "CLAB-Datei laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        v307LoadCLAB(url, intoPieceSlot: activePieceSlot)
    }

    private func v307LoadCLAB(_ url: URL, intoPieceSlot index: Int) {
        guard index >= 0, index < pieceSlots.count else { return }
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(V307CLABDocument.self, from: data)
            guard doc.format == "composition-lab-clab", doc.version >= 3 else {
                throw NSError(domain: "CompositionLab.CLAB", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Kein Composition-Lab-3-CLAB-Dokument."])
            }

            // Explicit CLAB loading restores the musical working state as well
            // as the score. This is different from merely browsing another slot.
            settings = doc.settings
            restoreSettings()
            activePieceSlot = index
            promptView.string = doc.compositionAssignment
            conceptView.string = doc.compositionIdea
            lastConcept = doc.compositionIdea

            slotSelectionLoad = true
            install(score: doc.score,
                    concept: doc.compositionIdea,
                    provider: doc.provider,
                    model: doc.model,
                    addHistory: false)
            slotSelectionLoad = false

            // install() may touch legacy state; assert the CLAB working text again.
            promptView.string = doc.compositionAssignment
            conceptView.string = doc.compositionIdea
            lastConcept = doc.compositionIdea

            captureCurrentInActiveSlot()
            updatePieceSlotButtons()
            scheduleMusicXMLPreviewRefresh()
            saveSettingsFromUI()
            status("CLAB geladen: \(doc.title) · Auftrag und Kompositionsidee wiederhergestellt.", good: true)
        } catch {
            // Backward compatibility: let the existing legacy CLAB importer try
            // older files created before the 3.x central CLAB document.
            status("Älteres CLAB-Format erkannt – versuche kompatibles Laden …", good: true)
            importFile(url, intoPieceSlot: index)
        }
    }

'''
    if action_marker not in s:
        raise SystemExit('V3.0.7: CLAB action insertion marker not found')
    s = s.replace(action_marker, actions + action_marker, 1)

# ---------------------------------------------------------------------------
# 4) Existing right-click “CLAB-Datei laden …” should use the same 3.x loader.
# ---------------------------------------------------------------------------
start = s.find('    @objc private func v651LoadCLABIntoSlot(_ sender: NSMenuItem) {\n')
if start < 0:
    raise SystemExit('V3.0.7: legacy slot CLAB load action not found')
end = s.find('    @objc private func v65ProjectAction', start)
if end < 0:
    raise SystemExit('V3.0.7: end of slot CLAB load action not found')
segment = s[start:end]
old_tail = '''        guard panel.runModal() == .OK, let url = panel.url else { return }\n        importFile(url, intoPieceSlot: sender.tag)\n    }\n\n'''
new_tail = '''        guard panel.runModal() == .OK, let url = panel.url else { return }\n        v307LoadCLAB(url, intoPieceSlot: sender.tag)\n    }\n\n'''
if old_tail not in segment:
    raise SystemExit('V3.0.7: right-click CLAB loader body not found')
segment = segment.replace(old_tail, new_tail, 1)
s = s[:start] + segment + s[end:]

# Diagnostic/interface version.
s = s.replace('"interfaceVersion": "3.0.6"', '"interfaceVersion": "3.0.7"')

p.write_text(s, encoding='utf-8')
print('Applied V3.0.7: CLAB central format with score, assignment, editable idea, provider/model and settings; visible save/load actions restored.')
