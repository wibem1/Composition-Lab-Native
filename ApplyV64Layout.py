from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

start = s.find('    private func buildCompositionWorkspace(_ parent: NSView) {\n')
end = s.find('    @objc private func workspaceChanged() {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.4: workspace boundaries not found')

# V6.4 approved MusicChat-oriented Main workspace.
new = r'''    private func buildCompositionWorkspace(_ parent: NSView) {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 18, left: 24, bottom: 18, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            root.topAnchor.constraint(equalTo: parent.topAnchor),
            root.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        let controls = buildV64Controls(); root.addArrangedSubview(controls); controls.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let work = buildV64WorkArea(); root.addArrangedSubview(work); work.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        work.setContentHuggingPriority(.defaultLow, for: .vertical); work.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        let deck = buildV64Deck(); root.addArrangedSubview(deck); deck.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let bottom = buildV64BottomBar(); root.addArrangedSubview(bottom); bottom.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func v64Panel() -> NSBox {
        let b = NSBox(); b.boxType = .custom; b.cornerRadius = 12; b.borderWidth = 1; b.contentViewMargins = NSSize(width: 14, height: 12); return b
    }

    private func buildV64Controls() -> NSView {
        let box = v64Panel(); let row = NSStackView(); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 10; box.contentView = row
        if providerPop.numberOfItems == 0 { providerPop.addItems(withTitles: Provider.allCases.map(\.displayName)); providerPop.target = self; providerPop.action = #selector(providerChanged) }
        if effortPop.numberOfItems == 0 { effortPop.addItems(withTitles: Effort.allCases.map(\.displayName)) }
        let ai = NSTextField(labelWithString: "KI"); ai.font = .systemFont(ofSize: 12, weight: .semibold); row.addArrangedSubview(ai)
        row.addArrangedSubview(providerPop); row.addArrangedSubview(modelPop); row.addArrangedSubview(effortPop); row.addArrangedSubview(NSView())
        func label(_ text: String) { row.addArrangedSubview(NSTextField(labelWithString: text)) }
        func field(_ f: NSTextField, _ placeholder: String, _ width: CGFloat) { f.placeholderString = placeholder; f.widthAnchor.constraint(equalToConstant: width).isActive = true; row.addArrangedSubview(f) }
        label("Takte"); field(measuresField, "24", 54); field(meterField, "4/4", 54); label("Tempo"); field(tempoField, "96", 58); label("Tonart"); field(musicalKeyField, "C-Dur", 86)
        label("Instrumente"); ensembleField.placeholderString = "Piano"; ensembleField.widthAnchor.constraint(equalToConstant: 150).isActive = true; row.addArrangedSubview(ensembleField)
        return box
    }

    private func buildV64WorkArea() -> NSView {
        let row = NSStackView(); row.orientation = .horizontal; row.alignment = .top; row.spacing = 14
        let chat = v64Panel(); let cs = NSStackView(); cs.orientation = .vertical; cs.alignment = .leading; cs.spacing = 10; chat.contentView = cs
        let title = NSTextField(labelWithString: "MusicChat"); title.font = .systemFont(ofSize: 20, weight: .bold); cs.addArrangedSubview(title)
        promptView.font = .systemFont(ofSize: 13); let promptScroll = textScroll(promptView, minHeight: 58); promptScroll.heightAnchor.constraint(equalToConstant: 66).isActive = true; cs.addArrangedSubview(promptScroll); promptScroll.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true
        chatView.isEditable = false; chatView.isSelectable = true; chatView.font = .systemFont(ofSize: 13); let log = textScroll(chatView, minHeight: 170); cs.addArrangedSubview(log); log.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true; log.heightAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true; log.setContentHuggingPriority(.defaultLow, for: .vertical)
        let input = NSStackView(); input.orientation = .horizontal; input.alignment = .centerY; input.spacing = 8; chatInput.placeholderString = "Frage, Änderungswunsch oder neue musikalische Idee …"; chatInput.isBezeled = true; chatInput.bezelStyle = .roundedBezel; chatInput.heightAnchor.constraint(equalToConstant: 38).isActive = true; input.addArrangedSubview(chatInput)
        let send = NSButton(title: "Senden", target: self, action: #selector(chatPressed)); send.bezelStyle = .rounded; send.widthAnchor.constraint(equalToConstant: 92).isActive = true; input.addArrangedSubview(send); cs.addArrangedSubview(input); input.widthAnchor.constraint(equalTo: cs.widthAnchor).isActive = true

        let idea = v64Panel(); let isv = NSStackView(); isv.orientation = .vertical; isv.alignment = .leading; isv.spacing = 9; idea.contentView = isv
        let it = NSTextField(labelWithString: "Aktuelle Kompositionsidee"); it.font = .systemFont(ofSize: 16, weight: .bold); isv.addArrangedSubview(it)
        conceptView.isEditable = false; conceptView.isSelectable = true; conceptView.font = .systemFont(ofSize: 13); let ideaScroll = textScroll(conceptView, minHeight: 120); ideaScroll.heightAnchor.constraint(equalToConstant: 140).isActive = true; isv.addArrangedSubview(ideaScroll); ideaScroll.widthAnchor.constraint(equalTo: isv.widthAnchor).isActive = true
        let noteLabel = NSTextField(labelWithString: "Notizen / musikalischer Impuls"); noteLabel.textColor = .secondaryLabelColor; isv.addArrangedSubview(noteLabel); resultLabel.maximumNumberOfLines = 5; resultLabel.lineBreakMode = .byWordWrapping; resultLabel.font = .systemFont(ofSize: 12); isv.addArrangedSubview(resultLabel); resultLabel.widthAnchor.constraint(equalTo: isv.widthAnchor).isActive = true
        row.addArrangedSubview(chat); row.addArrangedSubview(idea); chat.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.66, constant: -7).isActive = true; idea.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.34, constant: -7).isActive = true; chat.heightAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true; idea.heightAnchor.constraint(equalTo: chat.heightAnchor).isActive = true
        return row
    }

    private func buildV64Deck() -> NSView {
        let panel = v64Panel(); let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 9; panel.contentView = stack
        let title = NSTextField(labelWithString: "Stücke (1–10)"); title.font = .systemFont(ofSize: 16, weight: .semibold); stack.addArrangedSubview(title)
        let scroll = NSScrollView(); scroll.hasHorizontalScroller = true; scroll.hasVerticalScroller = false; scroll.autohidesScrollers = true; scroll.drawsBackground = false; scroll.borderType = .noBorder; scroll.heightAnchor.constraint(equalToConstant: 146).isActive = true
        let cards = NSStackView(); cards.orientation = .horizontal; cards.alignment = .centerY; cards.spacing = 10; cards.edgeInsets = NSEdgeInsets(top: 2, left: 2, bottom: 5, right: 2); cards.translatesAutoresizingMaskIntoConstraints = false; scroll.documentView = cards
        var buttons: [PieceSlotDropButton] = []
        for i in 0..<10 {
            // Empty cards intentionally contain only their number. Drag & drop remains active over the whole card.
            let b = PieceSlotDropButton(title: "\(i + 1)", target: self, action: #selector(pieceSlotPressed(_:)))
            b.tag = i; b.bezelStyle = .rounded; b.setButtonType(.toggle); b.font = .systemFont(ofSize: 13, weight: .semibold); b.cell?.wraps = true; b.alignment = .center
            b.widthAnchor.constraint(equalToConstant: 132).isActive = true; b.heightAnchor.constraint(equalToConstant: 126).isActive = true
            b.onDropFile = { [weak self, weak b] url in guard let self, let b else { return }; self.importFile(url, intoPieceSlot: b.tag) }
            buttons.append(b); cards.addArrangedSubview(b)
        }
        cards.widthAnchor.constraint(greaterThanOrEqualToConstant: 1410).isActive = true; mainPieceSlotButtons = buttons; updatePieceSlotButtons(); stack.addArrangedSubview(scroll); scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return panel
    }

    private func buildV64BottomBar() -> NSView {
        let panel = v64Panel(); let row = NSStackView(); row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 9; panel.contentView = row
        row.addArrangedSubview(NSButton(title: "▶", target: self, action: #selector(playCurrentMIDI))); row.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        playerLoopButton.setButtonType(.toggle); playerLoopButton.target = self; playerLoopButton.action = #selector(playerLoopChanged); row.addArrangedSubview(playerLoopButton); row.addArrangedSubview(playerTimeLabel)
        playerProgress.target = self; playerProgress.action = #selector(playerSeekChanged); playerProgress.isContinuous = true; row.addArrangedSubview(playerProgress); playerProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
        row.addArrangedSubview(NSTextField(labelWithString: "Tempo")); playerTempoField.widthAnchor.constraint(equalToConstant: 54).isActive = true; row.addArrangedSubview(playerTempoField); playerVolume.target = self; playerVolume.action = #selector(playerVolumeChanged); playerVolume.widthAnchor.constraint(equalToConstant: 110).isActive = true; row.addArrangedSubview(playerVolume); row.addArrangedSubview(NSView())
        row.addArrangedSubview(NSButton(title: "Import …", target: self, action: #selector(importIntoActivePieceSlotPressed))); row.addArrangedSubview(NSButton(title: "Motiv …", target: self, action: #selector(generateMotifPressed)))
        let compose = NSButton(title: "Mit gewählter KI komponieren", target: self, action: #selector(composePressed)); compose.bezelStyle = .rounded; compose.keyEquivalent = "\r"; row.addArrangedSubview(compose); return panel
    }

    private func importFile(_ url: URL, intoPieceSlot index: Int) {
        guard index >= 0, index < pieceSlots.count else { return }; if index != activePieceSlot { captureCurrentInActiveSlot() }; activePieceSlot = index; updatePieceSlotButtons(); loadCompositionReference(url: url); if lastScore != nil { captureCurrentInActiveSlot() }; status("Datei in Stück-Slot \(index + 1) übernommen.", good: true)
    }

    @objc private func importIntoActivePieceSlotPressed() {
        let panel = NSOpenPanel(); panel.allowedFileTypes = ["mid", "midi", "musicxml", "xml", "clab", "clabproject"]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false; panel.message = "Datei in Stück-Slot \(activePieceSlot + 1) laden"; guard panel.runModal() == .OK, let url = panel.url else { return }; importFile(url, intoPieceSlot: activePieceSlot)
    }

'''
s = s[:start] + new + s[end:]
p.write_text(s, encoding='utf-8')
print('Applied V6.4 approved MusicChat layout with clean piece cards.')
