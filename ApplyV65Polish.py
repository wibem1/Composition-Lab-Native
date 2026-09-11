from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Extra V6.5 state: full project document, project label and mirrored notation-player controls.
prop_marker = '    private var lastStudioProBridgeDate: Date?\n'
if 'private struct V65ProjectDocument' not in s:
    props = r'''    private var lastStudioProBridgeDate: Date?
    private let v65ProjectLabel = NSTextField(labelWithString: "Projekt: Unbenannt")
    private let notationPlayerVolume = NSSlider(value: 0.80, minValue: 0.10, maxValue: 1.0, target: nil, action: nil)
    private let notationPlayerTempoField = NSTextField(string: "120")
    private let notationPlayerLoopButton = NSButton(title: "↻ Loop", target: nil, action: nil)

    private struct V65ProjectDocument: Codable {
        var format: String
        var name: String
        var activeSlot: Int
        var slots: [HistoryItem?]
        var settings: AppSettings
        var history: [HistoryItem]
    }
'''
    if prop_marker not in s:
        raise SystemExit('V6.5: property marker not found')
    s = s.replace(prop_marker, props, 1)

# Less intrusive bridge watcher: retain automatic DAW hand-off, but reduce periodic main-thread file polling.
old_timer = '''        reaperBridgeTimer = Timer.scheduledTimer(timeInterval: 0.75,\n                                                 target: self,\n                                                 selector: #selector(reaperBridgeTimerFired(_:)),\n                                                 userInfo: nil,\n                                                 repeats: true)\n'''
new_timer = '''        let timer = Timer(timeInterval: 1.50,\n                          target: self,\n                          selector: #selector(reaperBridgeTimerFired(_:)),\n                          userInfo: nil,\n                          repeats: true)\n        timer.tolerance = 0.50\n        RunLoop.main.add(timer, forMode: .default)\n        reaperBridgeTimer = timer\n'''
if old_timer in s:
    s = s.replace(old_timer, new_timer, 1)
elif 'timeInterval: 1.50' not in s:
    raise SystemExit('V6.5: bridge timer block not found')

# Replace deck: larger/wider cards, much tighter framing and substantially longer visible titles.
start = s.find('    private func buildV64Deck() -> NSView {\n')
end = s.find('    private func buildV64BottomBar() -> NSView {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.5: deck boundaries not found')
new_deck = r'''    private func buildV64Deck() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 8, height: 6)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
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
        scroll.heightAnchor.constraint(equalToConstant: 112).isActive = true

        let cards = NSStackView()
        cards.orientation = .horizontal
        cards.alignment = .centerY
        cards.spacing = 8
        cards.edgeInsets = NSEdgeInsets(top: 0, left: 1, bottom: 2, right: 1)
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
            b.widthAnchor.constraint(equalToConstant: 158).isActive = true
            b.heightAnchor.constraint(equalToConstant: 94).isActive = true
            b.onDropFile = { [weak self, weak b] url in
                guard let self, let b else { return }
                self.importFile(url, intoPieceSlot: b.tag)
            }
            buttons.append(b)
            cards.addArrangedSubview(b)
        }
        cards.widthAnchor.constraint(greaterThanOrEqualToConstant: 1655).isActive = true
        mainPieceSlotButtons = buttons
        updatePieceSlotButtons()
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return panel
    }

'''
s = s[:start] + new_deck + s[end:]

# Main transport/action bar: compact, with explicit MIDI/JSON save and project workflow.
start = s.find('    private func buildV64BottomBar() -> NSView {\n')
end = s.find('    private func importFile(_ url: URL, intoPieceSlot index: Int) {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.5: bottom-bar boundaries not found')
new_bottom = r'''    private func buildV64BottomBar() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 10, height: 6)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        panel.contentView = row

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
        row.addArrangedSubview(playerProgress)
        playerProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        row.addArrangedSubview(playerTempoField)
        playerVolume.widthAnchor.constraint(equalToConstant: 90).isActive = true
        row.addArrangedSubview(playerVolume)

        row.addArrangedSubview(NSView())
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
        return panel
    }

'''
s = s[:start] + new_bottom + s[end:]

# Make main-card labels long enough to preserve useful composition titles.
old = 'let short = title.count > 24 ? String(title.prefix(23)) + "…" : title'
new = 'let short = title.count > 54 ? String(title.prefix(53)) + "…" : title'
if old in s:
    s = s.replace(old, new, 1)

# Notation transport: same visual/control vocabulary as Main.
start = s.find('    private func buildNotationTransport() -> NSView {\n')
end = s.find('    @objc private func notationPlayerSeekChanged()', start)
if start < 0 or end < 0:
    raise SystemExit('V6.5: notation transport boundaries not found')
new_notation = r'''    private func buildNotationTransport() -> NSView {
        let panel = v64Panel()
        panel.contentViewMargins = NSSize(width: 10, height: 6)
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        panel.contentView = row

        row.addArrangedSubview(NSButton(title: "▶", target: self, action: #selector(playCurrentMIDI)))
        row.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        notationPlayerLoopButton.setButtonType(.toggle)
        notationPlayerLoopButton.bezelStyle = .rounded
        notationPlayerLoopButton.target = self
        notationPlayerLoopButton.action = #selector(v65NotationLoopChanged)
        row.addArrangedSubview(notationPlayerLoopButton)
        row.addArrangedSubview(notationPlayerTimeLabel)

        notationPlayerProgress.target = self
        notationPlayerProgress.action = #selector(notationPlayerSeekChanged)
        notationPlayerProgress.isContinuous = true
        notationPlayerProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        row.addArrangedSubview(notationPlayerProgress)

        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        notationPlayerTempoField.stringValue = playerTempoField.stringValue
        notationPlayerTempoField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        notationPlayerTempoField.target = self
        notationPlayerTempoField.action = #selector(v65NotationTempoChanged)
        row.addArrangedSubview(notationPlayerTempoField)

        notationPlayerVolume.doubleValue = playerVolume.doubleValue
        notationPlayerVolume.widthAnchor.constraint(equalToConstant: 90).isActive = true
        notationPlayerVolume.target = self
        notationPlayerVolume.action = #selector(v65NotationVolumeChanged)
        row.addArrangedSubview(notationPlayerVolume)
        return panel
    }

'''
s = s[:start] + new_notation + s[end:]

# Insert project and mirrored-player actions before the existing workspace selector action.
action_marker = '    @objc private func workspaceChanged() {\n'
if '@objc private func v65ProjectAction' not in s:
    actions = r'''    @objc private func v65ProjectAction(_ sender: NSPopUpButton) {
        let choice = sender.indexOfSelectedItem
        sender.selectItem(at: 0)
        switch choice {
        case 1:
            menuNameProject()
            v65ProjectLabel.stringValue = "Projekt: \(projectName)"
        case 2:
            v65SaveProject()
        case 3:
            v65LoadProject()
        case 4:
            menuExportBackup()
        case 5:
            menuImportBackup()
        default:
            break
        }
    }

    @objc private func v65NotationTempoChanged() {
        playerTempoField.stringValue = notationPlayerTempoField.stringValue
        playerTempoChanged()
        notationPlayerTempoField.stringValue = playerTempoField.stringValue
    }

    @objc private func v65NotationVolumeChanged() {
        playerVolume.doubleValue = notationPlayerVolume.doubleValue
        playerVolumeChanged()
    }

    @objc private func v65NotationLoopChanged() {
        playerLoopButton.state = notationPlayerLoopButton.state
        playerLoopChanged()
        notationPlayerLoopButton.title = playerLoopButton.title
        notationPlayerLoopButton.contentTintColor = playerLoopButton.contentTintColor
    }

    private func v65SaveProject() {
        captureCurrentInActiveSlot()
        saveSettingsFromUI()
        let doc = V65ProjectDocument(format: "composition-lab-v6-project",
                                     name: projectName,
                                     activeSlot: activePieceSlot,
                                     slots: pieceSlots,
                                     settings: settings,
                                     history: history)
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["clabproject"]
        panel.nameFieldStringValue = safeFilename(projectName) + ".clabproject"
        if let url = projectURL { panel.directoryURL = url.deletingLastPathComponent() }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder.pretty.encode(doc)
            try data.write(to: url, options: .atomic)
            projectURL = url
            v65ProjectLabel.stringValue = "Projekt: \(projectName)"
            updateWindowTitle()
            status("Projekt „\(projectName)“ mit allen 10 Stück-Slots gespeichert.", good: true)
        } catch {
            status("Projekt konnte nicht gespeichert werden: \(error.localizedDescription)", good: false)
        }
    }

    private func v65LoadProject() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["clabproject"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(V65ProjectDocument.self, from: data)
            guard doc.format == "composition-lab-v6-project" else {
                throw NSError(domain: "CompositionLab.V65", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Unbekanntes V6-Projektformat."])
            }
            projectName = doc.name
            projectURL = url
            settings = doc.settings
            history = doc.history
            pieceSlots = Array(doc.slots.prefix(10))
            if pieceSlots.count < 10 { pieceSlots.append(contentsOf: [HistoryItem?](repeating: nil, count: 10 - pieceSlots.count)) }
            activePieceSlot = max(0, min(doc.activeSlot, 9))
            restoreSettings()
            Storage.shared.saveHistory(history)
            refreshVisibleHistories()
            updatePieceSlotButtons()
            v65ProjectLabel.stringValue = "Projekt: \(projectName)"
            updateWindowTitle()
            if let item = pieceSlots[activePieceSlot] {
                slotSelectionLoad = true
                install(score: item.score, concept: item.concept, provider: item.provider, model: item.model,
                        addHistory: false, costUSD: item.costUSD,
                        inputTokens: item.inputTokens, outputTokens: item.outputTokens)
                slotSelectionLoad = false
            }
            scheduleMusicXMLPreviewRefresh()
            status("Projekt „\(projectName)“ geladen.", good: true)
        } catch {
            status("Projekt konnte nicht geladen werden: \(error.localizedDescription)", good: false)
        }
    }

'''
    if action_marker not in s:
        raise SystemExit('V6.5: action insertion marker not found')
    s = s.replace(action_marker, actions + action_marker, 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.5 polish: compact deck, fuller titles, mirrored notation player, save/project/backup UI, smoother bridge watcher.')
