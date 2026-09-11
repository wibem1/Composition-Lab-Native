from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# 1) Main piece deck: taller, not wider; tight surrounding panel.
start = s.find('    private func buildV64Deck() -> NSView {\n')
end = s.find('    private func buildV64BottomBar() -> NSView {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.5.1: deck boundaries not found')

new_deck = r'''    private func buildV64Deck() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 7, height: 5)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        panel.contentView = stack

        let title = NSTextField(labelWithString: "Stücke (1–10)")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(title)

        let scroll = FastScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.heightAnchor.constraint(equalToConstant: 148).isActive = true

        let cards = NSStackView()
        cards.orientation = .horizontal
        cards.alignment = .centerY
        cards.spacing = 8
        cards.edgeInsets = NSEdgeInsets(top: 1, left: 1, bottom: 2, right: 1)
        cards.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = cards

        var buttons: [PieceSlotDropButton] = []
        for i in 0..<10 {
            let b = PieceSlotDropButton(title: "\(i + 1)", target: self, action: #selector(pieceSlotPressed(_:)))
            b.tag = i
            b.bezelStyle = .rounded
            b.setButtonType(.toggle)
            b.font = .systemFont(ofSize: 12, weight: .medium)
            b.cell?.wraps = true
            b.alignment = .center
            b.widthAnchor.constraint(equalToConstant: 138).isActive = true
            b.heightAnchor.constraint(equalToConstant: 130).isActive = true
            b.onDropFile = { [weak self, weak b] url in
                guard let self, let b else { return }
                self.importFile(url, intoPieceSlot: b.tag)
            }

            let menu = NSMenu()
            let midi = NSMenuItem(title: "MIDI-Datei laden …", action: #selector(v651LoadMIDIIntoSlot(_:)), keyEquivalent: "")
            midi.target = self
            midi.tag = i
            menu.addItem(midi)
            let clab = NSMenuItem(title: "CLAB-Datei laden …", action: #selector(v651LoadCLABIntoSlot(_:)), keyEquivalent: "")
            clab.target = self
            clab.tag = i
            menu.addItem(clab)
            b.menu = menu

            buttons.append(b)
            cards.addArrangedSubview(b)
        }

        cards.widthAnchor.constraint(greaterThanOrEqualToConstant: 1455).isActive = true
        mainPieceSlotButtons = buttons
        updatePieceSlotButtons()
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return panel
    }

'''
s = s[:start] + new_deck + s[end:]

# 2) Make bottom controls horizontally scrollable instead of forcing a fixed window width.
start = s.find('    private func buildV64BottomBar() -> NSView {\n')
end = s.find('    private func importFile(_ url: URL, intoPieceSlot index: Int) {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.5.1: bottom bar boundaries not found')

new_bottom = r'''    private func buildV64BottomBar() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 8, height: 5)

        let scroll = FastScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.heightAnchor.constraint(equalToConstant: 38).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        row.edgeInsets = NSEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = row

        row.addArrangedSubview(NSButton(title: "▶", target: self, action: #selector(playCurrentMIDI)))
        row.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        playerLoopButton.setButtonType(.toggle)
        playerLoopButton.target = self
        playerLoopButton.action = #selector(playerLoopChanged)
        row.addArrangedSubview(playerLoopButton)
        row.addArrangedSubview(playerTimeLabel)

        playerProgress.target = self
        playerProgress.action = #selector(playerSeekChanged)
        playerProgress.isContinuous = true
        playerProgress.widthAnchor.constraint(equalToConstant: 180).isActive = true
        row.addArrangedSubview(playerProgress)

        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        row.addArrangedSubview(playerTempoField)
        playerVolume.widthAnchor.constraint(equalToConstant: 90).isActive = true
        row.addArrangedSubview(playerVolume)

        let midiSave = NSButton(title: "MIDI sichern", target: self, action: #selector(saveMIDIPressed))
        let jsonSave = NSButton(title: "JSON sichern", target: self, action: #selector(saveJSONPressed))
        row.addArrangedSubview(midiSave)
        row.addArrangedSubview(jsonSave)

        v65ProjectLabel.stringValue = "Projekt: \(projectName)"
        v65ProjectLabel.font = .systemFont(ofSize: 11)
        v65ProjectLabel.textColor = .secondaryLabelColor
        row.addArrangedSubview(v65ProjectLabel)

        let project = NSPopUpButton()
        project.addItems(withTitles: ["Projekt …", "Benennen …", "Projekt sichern …", "Projekt laden …", "Backup sichern …", "Backup laden …"])
        project.target = self
        project.action = #selector(v65ProjectAction(_:))
        project.selectItem(at: 0)
        row.addArrangedSubview(project)

        row.addArrangedSubview(NSButton(title: "Import …", target: self, action: #selector(importIntoActivePieceSlotPressed)))
        row.addArrangedSubview(NSButton(title: "Motiv …", target: self, action: #selector(generateMotifPressed)))
        let compose = NSButton(title: "Mit gewählter KI komponieren", target: self, action: #selector(composePressed))
        compose.bezelStyle = .rounded
        compose.keyEquivalent = "\r"
        row.addArrangedSubview(compose)

        row.widthAnchor.constraint(greaterThanOrEqualToConstant: 1180).isActive = true
        panel.contentView = scroll
        return panel
    }

'''
s = s[:start] + new_bottom + s[end:]

# 3) Right-click actions for assigning a file to the clicked slot.
action_marker = '    @objc private func v65ProjectAction(_ sender: NSPopUpButton) {\n'
if '@objc private func v651LoadMIDIIntoSlot' not in s:
    actions = r'''    @objc private func v651LoadMIDIIntoSlot(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mid", "midi"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "MIDI-Datei in Stück-Slot \(sender.tag + 1) laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url, intoPieceSlot: sender.tag)
    }

    @objc private func v651LoadCLABIntoSlot(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["clab"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "CLAB-Datei in Stück-Slot \(sender.tag + 1) laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url, intoPieceSlot: sender.tag)
    }

'''
    if action_marker not in s:
        raise SystemExit('V6.5.1: action insertion marker not found')
    s = s.replace(action_marker, actions + action_marker, 1)

# 4) Explicitly keep the main window freely resizable in width. The bottom bar no longer imposes its intrinsic width.
view_appear = '''        view.window?.minSize = NSSize(width:1000,height:680)\n'''
replacement = '''        view.window?.minSize = NSSize(width:900,height:680)\n        view.window?.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)\n'''
if view_appear in s:
    s = s.replace(view_appear, replacement, 1)
elif 'CGFloat.greatestFiniteMagnitude' not in s:
    raise SystemExit('V6.5.1: viewDidAppear window size marker not found')

p.write_text(s, encoding='utf-8')
print('Applied V6.5.1: taller cards, right-click slot loading, freely resizable window.')
