from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# --- Bottom area: exactly two rows. Player first, functions second. ---
start = s.find('    private func buildV64BottomBar() -> NSView {\n')
end = s.find('    private func importFile(_ url: URL, intoPieceSlot index: Int) {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.6.2: bottom bar boundaries not found')

new_bottom = r'''    private func buildV64BottomBar() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 8, height: 5)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        panel.contentView = stack

        // Zeile 1: reiner MIDI-Player.
        let playerRow = NSStackView()
        playerRow.orientation = .horizontal
        playerRow.alignment = .centerY
        playerRow.spacing = 7

        playerRow.addArrangedSubview(NSButton(title: "▶", target: self, action: #selector(playCurrentMIDI)))
        playerRow.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        playerLoopButton.setButtonType(.toggle)
        playerLoopButton.target = self
        playerLoopButton.action = #selector(playerLoopChanged)
        playerRow.addArrangedSubview(playerLoopButton)
        playerRow.addArrangedSubview(playerTimeLabel)

        playerProgress.target = self
        playerProgress.action = #selector(playerSeekChanged)
        playerProgress.isContinuous = true
        playerProgress.widthAnchor.constraint(equalToConstant: 260).isActive = true
        playerRow.addArrangedSubview(playerProgress)

        playerRow.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        playerTempoField.target = self
        playerTempoField.action = #selector(playerTempoChanged)
        playerRow.addArrangedSubview(playerTempoField)

        playerRow.addArrangedSubview(NSTextField(labelWithString: "Lautstärke"))
        playerVolume.widthAnchor.constraint(equalToConstant: 130).isActive = true
        playerVolume.target = self
        playerVolume.action = #selector(playerVolumeChanged)
        playerRow.addArrangedSubview(playerVolume)

        stack.addArrangedSubview(playerRow)

        // Zeile 2: Funktionen. Alles linksbündig, keine nach rechts gedrückte Aktionsgruppe.
        let functionRow = NSStackView()
        functionRow.orientation = .horizontal
        functionRow.alignment = .centerY
        functionRow.spacing = 8

        functionRow.addArrangedSubview(NSButton(title: "MIDI sichern", target: self, action: #selector(saveMIDIPressed)))
        functionRow.addArrangedSubview(NSButton(title: "JSON sichern", target: self, action: #selector(saveJSONPressed)))

        let gap = NSView()
        gap.widthAnchor.constraint(equalToConstant: 22).isActive = true
        functionRow.addArrangedSubview(gap)

        functionRow.addArrangedSubview(NSButton(title: "Import …", target: self, action: #selector(importIntoActivePieceSlotPressed)))
        functionRow.addArrangedSubview(NSButton(title: "Motiv …", target: self, action: #selector(generateMotifPressed)))

        let compose = NSButton(title: "Mit gewählter KI komponieren", target: self, action: #selector(composePressed))
        compose.bezelStyle = .rounded
        compose.keyEquivalent = "\r"
        functionRow.addArrangedSubview(compose)

        stack.addArrangedSubview(functionRow)
        return panel
    }

'''
s = s[:start] + new_bottom + s[end:]

# --- Add delete command to every piece-card context menu. ---
old_menu = r'''            let clab = NSMenuItem(title: "CLAB-Datei laden …", action: #selector(v651LoadCLABIntoSlot(_:)), keyEquivalent: "")
            clab.target = self
            clab.tag = i
            menu.addItem(clab)
            b.menu = menu
'''
new_menu = r'''            let clab = NSMenuItem(title: "CLAB-Datei laden …", action: #selector(v651LoadCLABIntoSlot(_:)), keyEquivalent: "")
            clab.target = self
            clab.tag = i
            menu.addItem(clab)
            menu.addItem(NSMenuItem.separator())
            let clear = NSMenuItem(title: "Stück löschen", action: #selector(v662DeletePieceSlot(_:)), keyEquivalent: "")
            clear.target = self
            clear.tag = i
            menu.addItem(clear)
            b.menu = menu
'''
if old_menu not in s:
    raise SystemExit('V6.6.2: piece-card menu marker not found')
s = s.replace(old_menu, new_menu, 1)

# --- Slot deletion action. ---
action_marker = '    @objc private func v651LoadMIDIIntoSlot(_ sender: NSMenuItem) {\n'
if '@objc private func v662DeletePieceSlot' not in s:
    action = r'''    @objc private func v662DeletePieceSlot(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < pieceSlots.count else { return }
        guard pieceSlots[index] != nil else {
            status("Stück-Slot \(index + 1) ist bereits leer.", good: true)
            return
        }
        pieceSlots[index] = nil
        updatePieceSlotButtons()
        status("Stück-Slot \(index + 1) gelöscht.", good: true)
    }

'''
    if action_marker not in s:
        raise SystemExit('V6.6.2: action insertion marker not found')
    s = s.replace(action_marker, action + action_marker, 1)

# --- File-menu project commands must use the V6 multi-slot project document. ---
old_save = '''    @objc func menuSaveProject() {\n        saveCLABDocument()\n    }\n\n    @objc func menuLoadProject() {\n        openCLABPressed()\n    }\n'''
new_save = '''    @objc func menuSaveProject() {\n        v65SaveProject()\n    }\n\n    @objc func menuLoadProject() {\n        v65LoadProject()\n    }\n'''
if old_save in s:
    s = s.replace(old_save, new_save, 1)
elif 'v65SaveProject()' not in s or 'v65LoadProject()' not in s:
    raise SystemExit('V6.6.2: project menu wrappers not found')

p.write_text(s, encoding='utf-8')
print('Applied V6.6.2: two-row bottom bar, left-aligned actions, slot delete, V6 projects in Datei menu.')
