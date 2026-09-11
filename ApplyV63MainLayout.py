from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

start = s.find('    private func buildCompositionWorkspace(_ parent: NSView) {\n')
end = s.find('    @objc private func workspaceChanged() {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.3 Main: workspace boundaries not found')

new = r'''    private func buildCompositionWorkspace(_ parent: NSView) {
        // V6.3: Main is a dedicated MusicChat workspace. No V5 sidebar,
        // no fold-out tool area, no split Impuls/Chat screen.
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            root.topAnchor.constraint(equalTo: parent.topAnchor),
            root.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        let controls = buildV63ControlStrip()
        root.addArrangedSubview(controls)
        controls.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let chat = buildV63MusicChat()
        root.addArrangedSubview(chat)
        chat.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        chat.setContentHuggingPriority(.defaultLow, for: .vertical)
        chat.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let deck = buildV63PieceDeck()
        root.addArrangedSubview(deck)
        deck.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let player = buildV63PlayerBar()
        root.addArrangedSubview(player)
        player.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let actions = buildV63ActionBar()
        root.addArrangedSubview(actions)
        actions.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func buildV63ControlStrip() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7

        let top = NSStackView()
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 8

        if providerPop.numberOfItems == 0 {
            providerPop.addItems(withTitles: Provider.allCases.map(\.displayName))
            providerPop.target = self
            providerPop.action = #selector(providerChanged)
        }
        if effortPop.numberOfItems == 0 {
            effortPop.addItems(withTitles: Effort.allCases.map(\.displayName))
        }

        let brand = NSTextField(labelWithString: "Composition Lab")
        brand.font = .systemFont(ofSize: 15, weight: .semibold)
        top.addArrangedSubview(brand)
        top.addArrangedSubview(NSView())
        top.addArrangedSubview(providerPop)
        top.addArrangedSubview(modelPop)
        top.addArrangedSubview(effortPop)
        stack.addArrangedSubview(top)
        top.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let parameters = NSStackView()
        parameters.orientation = .horizontal
        parameters.alignment = .centerY
        parameters.spacing = 7

        func compact(_ field: NSTextField, placeholder: String, width: CGFloat) {
            field.placeholderString = placeholder
            field.widthAnchor.constraint(equalToConstant: width).isActive = true
            parameters.addArrangedSubview(field)
        }
        compact(measuresField, placeholder: "Takte", width: 72)
        compact(meterField, placeholder: "Taktart", width: 72)
        compact(tempoField, placeholder: "Tempo", width: 72)
        compact(musicalKeyField, placeholder: "Tonart", width: 90)
        ensembleField.placeholderString = "Besetzung"
        ensembleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        parameters.addArrangedSubview(ensembleField)
        parameters.addArrangedSubview(NSView())
        stack.addArrangedSubview(parameters)
        parameters.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let promptRow = NSStackView()
        promptRow.orientation = .horizontal
        promptRow.alignment = .centerY
        promptRow.spacing = 8
        let promptLabel = NSTextField(labelWithString: "Kompositionsauftrag")
        promptLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        promptRow.addArrangedSubview(promptLabel)
        let promptScroll = textScroll(promptView, minHeight: 44)
        promptScroll.heightAnchor.constraint(equalToConstant: 54).isActive = true
        promptRow.addArrangedSubview(promptScroll)
        promptScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 500).isActive = true
        stack.addArrangedSubview(promptRow)
        promptRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func buildV63MusicChat() -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 10
        box.borderWidth = 1
        box.contentViewMargins = NSSize(width: 12, height: 10)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        box.contentView = stack

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        let titleLabel = NSTextField(labelWithString: "MusicChat")
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(NSView())
        resultLabel.font = .systemFont(ofSize: 12, weight: .medium)
        resultLabel.textColor = .secondaryLabelColor
        resultLabel.maximumNumberOfLines = 2
        header.addArrangedSubview(resultLabel)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let impulse = NSBox()
        impulse.boxType = .custom
        impulse.cornerRadius = 7
        impulse.borderWidth = 0
        impulse.contentViewMargins = NSSize(width: 9, height: 6)
        let impulseStack = NSStackView()
        impulseStack.orientation = .vertical
        impulseStack.alignment = .leading
        impulseStack.spacing = 3
        impulse.contentView = impulseStack
        let impulseTitle = NSTextField(labelWithString: "Musikalischer Impuls")
        impulseTitle.font = .systemFont(ofSize: 11, weight: .semibold)
        impulseTitle.textColor = .secondaryLabelColor
        impulseStack.addArrangedSubview(impulseTitle)
        conceptView.isEditable = false
        conceptView.isSelectable = true
        conceptView.font = .systemFont(ofSize: 12)
        let impulseScroll = textScroll(conceptView, minHeight: 54)
        impulseScroll.heightAnchor.constraint(equalToConstant: 72).isActive = true
        impulseStack.addArrangedSubview(impulseScroll)
        impulseScroll.widthAnchor.constraint(equalTo: impulseStack.widthAnchor).isActive = true
        stack.addArrangedSubview(impulse)
        impulse.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        chatView.isEditable = false
        chatView.isSelectable = true
        chatView.font = .systemFont(ofSize: 13)
        let chatLog = textScroll(chatView, minHeight: 180)
        stack.addArrangedSubview(chatLog)
        chatLog.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        chatLog.heightAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true
        chatLog.setContentHuggingPriority(.defaultLow, for: .vertical)
        chatLog.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let inputRow = NSStackView()
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8
        chatInput.isEditable = true
        chatInput.isSelectable = true
        chatInput.isBezeled = true
        chatInput.bezelStyle = .roundedBezel
        chatInput.font = .systemFont(ofSize: 13)
        chatInput.placeholderString = "Frage, Änderungswunsch oder neue musikalische Idee …"
        chatInput.heightAnchor.constraint(equalToConstant: 38).isActive = true
        inputRow.addArrangedSubview(chatInput)
        let send = NSButton(title: "Senden", target: self, action: #selector(chatPressed))
        send.bezelStyle = .rounded
        send.widthAnchor.constraint(equalToConstant: 90).isActive = true
        inputRow.addArrangedSubview(send)
        stack.addArrangedSubview(inputRow)
        inputRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return box
    }

    private func buildV63PieceDeck() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        let titleLabel = NSTextField(labelWithString: "Stücke / Varianten")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(NSView())
        let hint = NSTextField(labelWithString: "Auswählen · MIDI / MusicXML / CLAB direkt auf eine Karte ziehen")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        header.addArrangedSubview(hint)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let scroll = NSScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.heightAnchor.constraint(equalToConstant: 92).isActive = true

        let cards = NSStackView()
        cards.orientation = .horizontal
        cards.alignment = .centerY
        cards.spacing = 8
        cards.edgeInsets = NSEdgeInsets(top: 3, left: 2, bottom: 3, right: 2)
        cards.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = cards

        var buttons: [PieceSlotDropButton] = []
        for i in 0..<10 {
            let b = PieceSlotDropButton(title: "Stück \(i + 1)\nleer", target: self, action: #selector(pieceSlotPressed(_:)))
            b.tag = i
            b.bezelStyle = .rounded
            b.setButtonType(.toggle)
            b.font = .systemFont(ofSize: 13, weight: .semibold)
            b.cell?.wraps = true
            b.alignment = .center
            b.widthAnchor.constraint(equalToConstant: 118).isActive = true
            b.heightAnchor.constraint(equalToConstant: 76).isActive = true
            b.onDropFile = { [weak self, weak b] url in
                guard let self, let b else { return }
                self.importFile(url, intoPieceSlot: b.tag)
            }
            buttons.append(b)
            cards.addArrangedSubview(b)
        }
        cards.widthAnchor.constraint(greaterThanOrEqualToConstant: 1250).isActive = true
        mainPieceSlotButtons = buttons
        updatePieceSlotButtons()
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func buildV63PlayerBar() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
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
        playerProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
        row.addArrangedSubview(playerTimeLabel)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(NSTextField(labelWithString: "Tempo"))
        playerTempoField.widthAnchor.constraint(equalToConstant: 54).isActive = true
        playerTempoField.target = self
        playerTempoField.action = #selector(playerTempoChanged)
        row.addArrangedSubview(playerTempoField)
        row.addArrangedSubview(NSTextField(labelWithString: "🔊"))
        playerVolume.target = self
        playerVolume.action = #selector(playerVolumeChanged)
        playerVolume.isContinuous = true
        playerVolume.widthAnchor.constraint(equalToConstant: 130).isActive = true
        row.addArrangedSubview(playerVolume)
        return row
    }

    private func buildV63ActionBar() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        let importButton = NSButton(title: "Import in aktiven Slot …", target: self, action: #selector(importIntoActivePieceSlotPressed))
        importButton.bezelStyle = .rounded
        row.addArrangedSubview(importButton)
        let motif = NSButton(title: "Motiv 2 / 4 / 8 Takte …", target: self, action: #selector(generateMotifPressed))
        motif.bezelStyle = .rounded
        row.addArrangedSubview(motif)
        row.addArrangedSubview(NSView())
        let compose = NSButton(title: "Mit gewählter KI komponieren", target: self, action: #selector(composePressed))
        compose.bezelStyle = .rounded
        compose.keyEquivalent = "\r"
        row.addArrangedSubview(compose)
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

'''

s = s[:start] + new + s[end:]

# Richer labels for the large V6.3 cards. Notation buttons stay compact.
old_update = '''    private func updatePieceSlotButtons() {\n        func apply(_ buttons: [NSButton]) {\n            for (i, b) in buttons.enumerated() where i < pieceSlots.count {\n                let filled = pieceSlots[i] != nil\n                b.title = filled ? "●\\(i + 1)" : "\\(i + 1)"\n                b.state = i == activePieceSlot ? .on : .off\n                b.toolTip = pieceSlots[i].map { "Stück \\(i + 1): \\($0.title)" } ?? "Stück \\(i + 1): leer"\n            }\n        }\n        apply(mainPieceSlotButtons)\n        apply(notationPieceSlotButtons)\n    }\n'''
new_update = '''    private func updatePieceSlotButtons() {\n        for (i, b) in mainPieceSlotButtons.enumerated() where i < pieceSlots.count {\n            if let item = pieceSlots[i] {\n                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)\n                let short = title.count > 20 ? String(title.prefix(19)) + "…" : title\n                b.title = "Stück \\(i + 1)\\n\\(short)"\n                b.toolTip = "Stück \\(i + 1): \\(item.title)"\n            } else {\n                b.title = "Stück \\(i + 1)\\nleer"\n                b.toolTip = "Stück \\(i + 1): leer · Datei hierher ziehen"\n            }\n            b.state = i == activePieceSlot ? .on : .off\n        }\n        for (i, b) in notationPieceSlotButtons.enumerated() where i < pieceSlots.count {\n            let filled = pieceSlots[i] != nil\n            b.title = filled ? "●\\(i + 1)" : "\\(i + 1)"\n            b.state = i == activePieceSlot ? .on : .off\n            b.toolTip = pieceSlots[i].map { "Stück \\(i + 1): \\($0.title)" } ?? "Stück \\(i + 1): leer"\n        }\n    }\n'''
if old_update in s:
    s = s.replace(old_update, new_update, 1)
elif 'b.title = "Stück \\(i + 1)\\n\\(short)"' not in s:
    raise SystemExit('V6.3 Main: slot label updater not found')

required = [
    'private func buildV63MusicChat()',
    'private func buildV63PieceDeck()',
    'private func buildV63PlayerBar()',
    'private func buildV63ActionBar()',
    'cards.widthAnchor.constraint(greaterThanOrEqualToConstant: 1250)',
    'b.title = "Stück \\(i + 1)\\n\\(short)"'
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('V6.3 Main incomplete: ' + ', '.join(missing))

p.write_text(s, encoding='utf-8')
print('Applied V6.3 Main: full-width MusicChat, horizontal 10-card deck, player and minimal actions.')
