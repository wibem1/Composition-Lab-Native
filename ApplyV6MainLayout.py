from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

start = s.find('    private func buildCompositionWorkspace(_ parent: NSView) {\n')
end = s.find('    @objc private func workspaceChanged() {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6 Main rebuild: composition workspace boundaries not found')

new = r'''    private func buildCompositionWorkspace(_ parent: NSView) {
        // V6 Main is deliberately rebuilt from scratch. The old V5 left/right
        // layout remains in source only as a functional reference and is not used.
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            root.topAnchor.constraint(equalTo: parent.topAnchor),
            root.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        root.addArrangedSubview(buildV6MainParameterBar())

        let dialogue = NSSplitView()
        dialogue.isVertical = true
        dialogue.dividerStyle = .thin
        dialogue.translatesAutoresizingMaskIntoConstraints = false
        dialogue.heightAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
        root.addArrangedSubview(dialogue)
        dialogue.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let conceptPane = NSView()
        let chatPane = NSView()
        dialogue.addArrangedSubview(conceptPane)
        dialogue.addArrangedSubview(chatPane)

        let conceptStack = NSStackView()
        conceptStack.orientation = .vertical
        conceptStack.alignment = .leading
        conceptStack.spacing = 6
        conceptStack.translatesAutoresizingMaskIntoConstraints = false
        conceptPane.addSubview(conceptStack)
        NSLayoutConstraint.activate([
            conceptStack.leadingAnchor.constraint(equalTo: conceptPane.leadingAnchor),
            conceptStack.trailingAnchor.constraint(equalTo: conceptPane.trailingAnchor, constant: -8),
            conceptStack.topAnchor.constraint(equalTo: conceptPane.topAnchor),
            conceptStack.bottomAnchor.constraint(equalTo: conceptPane.bottomAnchor)
        ])
        conceptStack.addArrangedSubview(title("Musikalischer Impuls"))
        conceptView.isEditable = false
        conceptView.isSelectable = true
        let impulseScroll = textScroll(conceptView, minHeight: 210)
        conceptStack.addArrangedSubview(impulseScroll)
        impulseScroll.widthAnchor.constraint(equalTo: conceptStack.widthAnchor).isActive = true

        let chatStack = NSStackView()
        chatStack.orientation = .vertical
        chatStack.alignment = .leading
        chatStack.spacing = 6
        chatStack.translatesAutoresizingMaskIntoConstraints = false
        chatPane.addSubview(chatStack)
        NSLayoutConstraint.activate([
            chatStack.leadingAnchor.constraint(equalTo: chatPane.leadingAnchor, constant: 8),
            chatStack.trailingAnchor.constraint(equalTo: chatPane.trailingAnchor),
            chatStack.topAnchor.constraint(equalTo: chatPane.topAnchor),
            chatStack.bottomAnchor.constraint(equalTo: chatPane.bottomAnchor)
        ])
        chatStack.addArrangedSubview(title("Musik-Chat"))
        chatView.isEditable = false
        chatView.isSelectable = true
        let chatLog = textScroll(chatView, minHeight: 160)
        chatStack.addArrangedSubview(chatLog)
        chatLog.widthAnchor.constraint(equalTo: chatStack.widthAnchor).isActive = true

        chatInput.isEditable = true
        chatInput.isSelectable = true
        chatInput.isBezeled = true
        chatInput.bezelStyle = .roundedBezel
        chatInput.font = .systemFont(ofSize: 13)
        chatInput.placeholderString = "Mit der KI über das aktive Stück sprechen oder Änderungen verlangen …"
        chatInput.heightAnchor.constraint(equalToConstant: 38).isActive = true
        chatStack.addArrangedSubview(chatInput)
        chatInput.widthAnchor.constraint(equalTo: chatStack.widthAnchor).isActive = true
        let send = NSButton(title: "An die KI senden", target: self, action: #selector(chatPressed))
        send.bezelStyle = .rounded
        chatStack.addArrangedSubview(send)

        let slots = buildV6CentralPieceDeck()
        root.addArrangedSubview(slots)
        slots.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let player = buildV6MainPlayerBar()
        root.addArrangedSubview(player)
        player.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let commandRow = NSStackView()
        commandRow.orientation = .horizontal
        commandRow.alignment = .centerY
        commandRow.spacing = 8
        let importButton = NSButton(title: "Import in aktiven Slot …", target: self, action: #selector(importIntoActivePieceSlotPressed))
        importButton.bezelStyle = .rounded
        let motifButton = NSButton(title: "Motiv 2 / 4 / 8 Takte …", target: self, action: #selector(generateMotifPressed))
        motifButton.bezelStyle = .rounded
        let composeButton = NSButton(title: "Mit gewählter KI komponieren", target: self, action: #selector(composePressed))
        composeButton.bezelStyle = .rounded
        composeButton.keyEquivalent = "\r"
        commandRow.addArrangedSubview(importButton)
        commandRow.addArrangedSubview(motifButton)
        commandRow.addArrangedSubview(NSView())
        commandRow.addArrangedSubview(composeButton)
        root.addArrangedSubview(commandRow)
        commandRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func buildV6MainParameterBar() -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 9
        box.borderWidth = 1
        box.contentViewMargins = NSSize(width: 12, height: 10)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        box.contentView = stack

        let first = NSStackView()
        first.orientation = .horizontal
        first.alignment = .centerY
        first.spacing = 8

        if providerPop.numberOfItems == 0 {
            providerPop.addItems(withTitles: Provider.allCases.map(\.displayName))
            providerPop.target = self
            providerPop.action = #selector(providerChanged)
        }
        if effortPop.numberOfItems == 0 {
            effortPop.addItems(withTitles: Effort.allCases.map(\.displayName))
        }
        first.addArrangedSubview(label("KI"))
        first.addArrangedSubview(providerPop)
        first.addArrangedSubview(modelPop)
        first.addArrangedSubview(effortPop)
        first.addArrangedSubview(NSView())
        first.addArrangedSubview(resultLabel)
        stack.addArrangedSubview(first)
        first.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let second = NSStackView()
        second.orientation = .horizontal
        second.alignment = .centerY
        second.spacing = 8
        measuresField.placeholderString = "Takte"
        meterField.placeholderString = "Taktart"
        tempoField.placeholderString = "Tempo"
        musicalKeyField.placeholderString = "Tonart"
        ensembleField.placeholderString = "Besetzung"
        for f in [measuresField, meterField, tempoField, musicalKeyField] {
            f.widthAnchor.constraint(equalToConstant: 86).isActive = true
            second.addArrangedSubview(f)
        }
        ensembleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        second.addArrangedSubview(ensembleField)
        stack.addArrangedSubview(second)
        second.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        promptView.isRichText = false
        promptView.font = .systemFont(ofSize: 13)
        promptView.textContainerInset = NSSize(width: 8, height: 7)
        let promptScroll = textScroll(promptView, minHeight: 58)
        stack.addArrangedSubview(promptScroll)
        promptScroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        promptScroll.heightAnchor.constraint(equalToConstant: 72).isActive = true
        return box
    }

    private func buildV6CentralPieceDeck() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7

        let head = NSStackView()
        head.orientation = .horizontal
        head.alignment = .centerY
        let h = title("Stücke / Varianten")
        head.addArrangedSubview(h)
        head.addArrangedSubview(NSView())
        let hint = NSTextField(labelWithString: "Klicken zum Auswählen · MIDI/MusicXML/CLAB direkt auf einen Slot ziehen")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        head.addArrangedSubview(hint)
        stack.addArrangedSubview(head)
        head.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        var buttons: [PieceSlotDropButton] = []
        for rowIndex in 0..<2 {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.distribution = .fillEqually
            row.spacing = 9
            for col in 0..<5 {
                let index = rowIndex * 5 + col
                let b = PieceSlotDropButton(title: "\(index + 1)\nDatei ablegen", target: self, action: #selector(pieceSlotPressed(_:)))
                b.tag = index
                b.bezelStyle = .rounded
                b.setButtonType(.toggle)
                b.font = .systemFont(ofSize: 14, weight: .semibold)
                b.cell?.wraps = true
                b.heightAnchor.constraint(equalToConstant: 66).isActive = true
                b.onDropFile = { [weak self, weak b] url in
                    guard let self, let b else { return }
                    self.importFile(url, intoPieceSlot: b.tag)
                }
                buttons.append(b)
                row.addArrangedSubview(b)
            }
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        mainPieceSlotButtons = buttons
        updatePieceSlotButtons()
        return stack
    }

    private func buildV6MainPlayerBar() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.addArrangedSubview(NSButton(title: "▶", target: self, action: #selector(playCurrentMIDI)))
        row.addArrangedSubview(NSButton(title: "Ⅱ", target: self, action: #selector(pauseCurrentMIDI)))
        row.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        playerLoopButton.setButtonType(.toggle)
        playerLoopButton.target = self
        playerLoopButton.action = #selector(playerLoopChanged)
        row.addArrangedSubview(playerLoopButton)
        playerProgress.target = self
        playerProgress.action = #selector(playerSeekChanged)
        playerProgress.isContinuous = true
        row.addArrangedSubview(playerProgress)
        playerProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true
        row.addArrangedSubview(playerTimeLabel)
        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 54).isActive = true
        playerTempoField.target = self
        playerTempoField.action = #selector(playerTempoChanged)
        row.addArrangedSubview(playerTempoField)
        playerVolume.target = self
        playerVolume.action = #selector(playerVolumeChanged)
        playerVolume.isContinuous = true
        playerVolume.widthAnchor.constraint(equalToConstant: 150).isActive = true
        row.addArrangedSubview(NSTextField(labelWithString: "🔊"))
        row.addArrangedSubview(playerVolume)
        return row
    }

    private func importFile(_ url: URL, intoPieceSlot index: Int) {
        guard index >= 0, index < pieceSlots.count else { return }
        if index != activePieceSlot { captureCurrentInActiveSlot() }
        activePieceSlot = index
        updatePieceSlotButtons()
        loadCompositionReference(url: url)
        if lastScore != nil { captureCurrentInActiveSlot() }
        status("Datei in Stück-Slot \(index + 1) übernommen.", good: true)
    }

    @objc private func importIntoActivePieceSlotPressed() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mid", "midi", "musicxml", "xml", "clab", "clabproject"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Datei in Stück-Slot \(activePieceSlot + 1) laden"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url, intoPieceSlot: activePieceSlot)
    }

    private func buildTechnicalWorkspace(_ parent: NSView) {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            root.topAnchor.constraint(equalTo: parent.topAnchor),
            root.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        root.addArrangedSubview(title("Technik"))
        let intro = NSTextField(wrappingLabelWithString: "API-Schlüssel, MIDI-Ausgabe, technische Prüfung, JSON, Diagnose sowie Projekt- und Dateifunktionen. Diese Werkzeuge sind bewusst von der musikalischen Hauptseite getrennt.")
        intro.textColor = .secondaryLabelColor
        root.addArrangedSubview(intro)
        intro.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.addArrangedSubview(NSButton(title: "API-Schlüssel …", target: self, action: #selector(menuAPIKeys)))
        actions.addArrangedSubview(NSButton(title: "MIDI-Ausgabe …", target: self, action: #selector(menuMIDIOutput)))
        actions.addArrangedSubview(NSButton(title: "CLAB öffnen …", target: self, action: #selector(openCLABPressed)))
        actions.addArrangedSubview(NSButton(title: "CLAB sichern …", target: self, action: #selector(saveCLABPressed)))
        actions.addArrangedSubview(NSButton(title: "JSON sichern …", target: self, action: #selector(saveJSONPressed)))
        root.addArrangedSubview(actions)

        let technicalTabs = NSTabView()
        technicalTabs.translatesAutoresizingMaskIntoConstraints = false
        let validationTab = NSTabViewItem(identifier: "validation")
        validationTab.label = "Technische Prüfung"
        validationView.isEditable = false
        validationTab.view = textScroll(validationView, minHeight: 360)
        technicalTabs.addTabViewItem(validationTab)

        let jsonTab = NSTabViewItem(identifier: "json")
        jsonTab.label = "JSON"
        jsonView.isEditable = false
        jsonTab.view = textScroll(jsonView, minHeight: 360)
        technicalTabs.addTabViewItem(jsonTab)

        let historyTab = NSTabViewItem(identifier: "history")
        historyTab.label = "Verlauf"
        historyTab.view = buildHistoryTab()
        technicalTabs.addTabViewItem(historyTab)

        root.addArrangedSubview(technicalTabs)
        technicalTabs.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        technicalTabs.heightAnchor.constraint(greaterThanOrEqualToConstant: 430).isActive = true
    }

'''

s = s[:start] + new + s[end:]

# V6 has no fold-out work area on Main. Old methods may remain compiled but are
# unreachable from Main; Technik provides the visible technical UI instead.
required = [
    'private func buildV6CentralPieceDeck()',
    'private func buildTechnicalWorkspace(_ parent: NSView)',
    'private func importFile(_ url: URL, intoPieceSlot index: Int)',
    'private func buildV6MainPlayerBar()'
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('V6 Main rebuild incomplete: ' + ', '.join(missing))

p.write_text(s, encoding='utf-8')
print('Applied V6 Main rebuild: no V5 sidebar, no fold-out bar; fixed Main + Noten + Technik architecture.')
