from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Apply only after ApplyWorkspaceLayoutFix.py / ApplyCompositionLab2.py.
# Make the notation workspace accept the same composition files as Main.
s = s.replace(
    '    private let notationWorkspaceHost = NSView()\n',
    '    private let notationWorkspaceHost = CompositionFileDropHostView()\n',
    1
)

notation_marker = '''        let notationHost = notationWorkspaceHost\n        notationHost.wantsLayer = true\n        notationHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n        buildMusicXMLWorkspace(notationHost)\n'''
notation_replacement = '''        let notationHost = notationWorkspaceHost\n        notationHost.wantsLayer = true\n        notationHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n        notationHost.onDropFile = { [weak self] url in\n            self?.loadCompositionReference(url: url)\n            self?.scheduleMusicXMLPreviewRefresh()\n        }\n        notationHost.toolTip = "MIDI, MusicXML oder CLAB hierher ziehen"\n        buildMusicXMLWorkspace(notationHost)\n'''
if notation_marker in s:
    s = s.replace(notation_marker, notation_replacement, 1)
elif 'notationHost.onDropFile' not in s:
    raise SystemExit('Full Drag & Drop: notation host marker not found')

# CLAB should behave exactly like MIDI/MusicXML: click = save, drag = export.
old_clab = '''        let saveCLAB = NSButton(title:"CLAB sichern …", target:self, action:#selector(saveCLABPressed))\n        saveCLAB.bezelStyle = .rounded\n'''
new_clab = '''        let saveCLAB = ExportDragButton(title:"CLAB sichern / ziehen …", target:self, action:#selector(saveCLABPressed))\n        saveCLAB.bezelStyle = .rounded\n        saveCLAB.toolTip = "Klicken zum Speichern oder vollständiges Composition-Lab-Projekt herausziehen"\n        saveCLAB.exportFileProvider = { [weak self] in self?.temporaryCLABExportURL() }\n'''
if old_clab in s:
    s = s.replace(old_clab, new_clab, 1)
elif 'temporaryCLABExportURL()' not in s:
    raise SystemExit('Full Drag & Drop: CLAB export button pattern not found')

# Add temporary CLAB generation for native macOS file dragging.
marker = '''    @objc private func saveCLABPressed() {\n        saveCLABDocument()\n    }\n'''
helper = '''    private func temporaryCLABExportURL() -> URL? {\n        guard let doc = currentCLABDocument() else {\n            status("Noch keine Komposition vorhanden.", good:false)\n            return nil\n        }\n        guard let url = temporaryExportURL(extension: "clab") else { return nil }\n        do {\n            let encoder = JSONEncoder()\n            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]\n            try encoder.encode(doc).write(to: url, options: .atomic)\n            status("CLAB zum Ziehen bereit.", good:true)\n            return url\n        } catch {\n            status("CLAB-Drag-Export fehlgeschlagen: \\(error.localizedDescription)", good:false)\n            return nil\n        }\n    }\n\n    @objc private func saveCLABPressed() {\n        saveCLABDocument()\n    }\n'''
if marker in s and 'private func temporaryCLABExportURL()' not in s:
    s = s.replace(marker, helper, 1)
elif 'private func temporaryCLABExportURL()' not in s:
    raise SystemExit('Full Drag & Drop: CLAB helper insertion marker not found')

# Keep all file-picker wording in sync with actual drag support.
s = s.replace('MIDI / MusicXML-Datei', 'MIDI / MusicXML / CLAB-Datei')
s = s.replace('MIDI- oder MusicXML-Datei', 'MIDI-, MusicXML- oder CLAB-Datei')

p.write_text(s, encoding='utf-8')
print('Applied full Drag & Drop: Main + Noten import, MIDI/MusicXML/CLAB export.')
