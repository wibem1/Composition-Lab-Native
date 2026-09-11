from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

segment = '    private let workspaceSegment = NSSegmentedControl(labels: ["Main", "Noten"], trackingMode: .selectOne, target: nil, action: nil)\n'
props = '''    private let workspaceSegment = NSSegmentedControl(labels: ["Main", "Noten"], trackingMode: .selectOne, target: nil, action: nil)\n    // V6: zehn gleichberechtigte Werk-/Varianten-Slots. Sie ersetzen das alte Vergleichslabor.\n    private var pieceSlots: [HistoryItem?] = [HistoryItem?](repeating: nil, count: 10)\n    private var activePieceSlot: Int = 0\n    private var pendingCompositionSlot: Int?\n    private var slotSelectionLoad = false\n    private var mainPieceSlotButtons: [NSButton] = []\n    private var notationPieceSlotButtons: [NSButton] = []\n    private let notationPlayerTimeLabel = NSTextField(labelWithString: "0:00 / 0:00")\n    private let notationPlayerProgress = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)\n'''
if segment in s and 'private var pieceSlots:' not in s:
    s = s.replace(segment, props, 1)

marker = '''        let topSplit = NSSplitView()\n        topSplit.isVertical = true\n'''
replacement = '''        let slotBar = buildPieceSlotBar(includeMotifButton: true)\n        outer.addArrangedSubview(slotBar)\n        slotBar.widthAnchor.constraint(equalTo: outer.widthAnchor).isActive = true\n\n        let topSplit = NSSplitView()\n        topSplit.isVertical = true\n'''
if marker in s and 'let slotBar = buildPieceSlotBar(includeMotifButton: true)' not in s:
    s = s.replace(marker, replacement, 1)

marker = '''        let topRow = NSStackView()\n        topRow.orientation = .horizontal\n'''
replacement = '''        let notationSlotBar = buildPieceSlotBar(includeMotifButton: false)\n        rightStack.addArrangedSubview(notationSlotBar)\n        notationSlotBar.widthAnchor.constraint(equalTo: rightStack.widthAnchor).isActive = true\n\n        let notationTransport = buildNotationTransport()\n        rightStack.addArrangedSubview(notationTransport)\n        notationTransport.widthAnchor.constraint(equalTo: rightStack.widthAnchor).isActive = true\n\n        let topRow = NSStackView()\n        topRow.orientation = .horizontal\n'''
if marker in s and 'let notationSlotBar = buildPieceSlotBar(includeMotifButton: false)' not in s:
    s = s.replace(marker, replacement, 1)

helper_marker = '    private func separatorBox() -> NSBox {\n'
helpers = r'''    private func buildPieceSlotBar(includeMotifButton: Bool) -> NSView {
        let bar = NSStackView()
        bar.orientation = .horizontal
        bar.alignment = .centerY
        bar.spacing = 5
        bar.addArrangedSubview(NSTextField(labelWithString: "Stücke"))

        var buttons: [NSButton] = []
        for i in 0..<10 {
            let b = NSButton(title: "\(i + 1)", target: self, action: #selector(pieceSlotPressed(_:)))
            b.tag = i
            b.bezelStyle = .rounded
            b.setButtonType(.toggle)
            b.widthAnchor.constraint(equalToConstant: 36).isActive = true
            buttons.append(b)
            bar.addArrangedSubview(b)
        }
        if includeMotifButton {
            bar.addArrangedSubview(NSView())
            let motif = NSButton(title: "Motiv 2 / 4 / 8 Takte …", target: self, action: #selector(generateMotifPressed))
            motif.bezelStyle = .rounded
            motif.toolTip = "Kurzes musikalisches Motiv erzeugen und in einen freien Stück-Slot legen"
            bar.addArrangedSubview(motif)
            mainPieceSlotButtons = buttons
        } else {
            notationPieceSlotButtons = buttons
        }
        updatePieceSlotButtons()
        return bar
    }

    private func updatePieceSlotButtons() {
        func apply(_ buttons: [NSButton]) {
            for (i, b) in buttons.enumerated() where i < pieceSlots.count {
                let filled = pieceSlots[i] != nil
                b.title = filled ? "●\(i + 1)" : "\(i + 1)"
                b.state = i == activePieceSlot ? .on : .off
                b.toolTip = pieceSlots[i].map { "Stück \(i + 1): \($0.title)" } ?? "Stück \(i + 1): leer"
            }
        }
        apply(mainPieceSlotButtons)
        apply(notationPieceSlotButtons)
    }

    private func captureCurrentInActiveSlot() {
        guard activePieceSlot >= 0, activePieceSlot < pieceSlots.count,
              let score = lastScore else { return }
        let p = lastProvider ?? provider
        let m = lastModel ?? model
        pieceSlots[activePieceSlot] = HistoryItem(id: UUID(),
                                                  time: Date(),
                                                  title: score.ti,
                                                  provider: p,
                                                  model: m,
                                                  concept: lastConcept,
                                                  score: score,
                                                  costUSD: lastCostUSD,
                                                  inputTokens: lastInputTokens,
                                                  outputTokens: lastOutputTokens,
                                                  area: .composition)
        updatePieceSlotButtons()
    }

    @objc private func pieceSlotPressed(_ sender: NSButton) {
        let newIndex = sender.tag
        guard newIndex >= 0, newIndex < pieceSlots.count else { return }
        if newIndex == activePieceSlot {
            updatePieceSlotButtons()
            return
        }
        captureCurrentInActiveSlot()
        activePieceSlot = newIndex
        guard let item = pieceSlots[newIndex] else {
            updatePieceSlotButtons()
            status("Stück-Slot \(newIndex + 1) ist leer. Die nächste Komposition landet hier.", good: true)
            return
        }
        slotSelectionLoad = true
        install(score: item.score,
                concept: item.concept,
                provider: item.provider,
                model: item.model,
                addHistory: false,
                costUSD: item.costUSD,
                inputTokens: item.inputTokens,
                outputTokens: item.outputTokens)
        slotSelectionLoad = false
        updatePieceSlotButtons()
        status("Stück \(newIndex + 1) geladen: \(item.title)", good: true)
    }

    @objc private func generateMotifPressed() {
        let alert = NSAlert()
        alert.messageText = "Musikalisches Motiv"
        alert.informativeText = "Wie lang soll das neue Motiv sein? Es wird in den nächsten freien Stück-Slot gelegt."
        alert.addButton(withTitle: "2 Takte")
        alert.addButton(withTitle: "4 Takte")
        alert.addButton(withTitle: "8 Takte")
        alert.addButton(withTitle: "Abbrechen")
        let response = alert.runModal()
        let bars: Int
        switch response {
        case .alertFirstButtonReturn: bars = 2
        case .alertSecondButtonReturn: bars = 4
        case .alertThirdButtonReturn: bars = 8
        default: return
        }

        captureCurrentInActiveSlot()
        if let free = pieceSlots.firstIndex(where: { $0 == nil }) { activePieceSlot = free }
        updatePieceSlotButtons()

        let oldMeasures = measuresField.stringValue
        let oldPrompt = promptView.string
        measuresField.stringValue = String(bars)
        promptView.string = "Komponiere ein prägnantes musikalisches Motiv als Ausgangspunkt für eine spätere Komposition."
        composePressed()
        measuresField.stringValue = oldMeasures
        promptView.string = oldPrompt
        saveSettingsFromUI()
    }

    private func buildNotationTransport() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        row.addArrangedSubview(NSButton(title: "▶", target: self, action: #selector(playCurrentMIDI)))
        row.addArrangedSubview(NSButton(title: "Ⅱ", target: self, action: #selector(pauseCurrentMIDI)))
        row.addArrangedSubview(NSButton(title: "■", target: self, action: #selector(stopCurrentMIDI)))
        notationPlayerProgress.target = self
        notationPlayerProgress.action = #selector(notationPlayerSeekChanged)
        notationPlayerProgress.isContinuous = true
        notationPlayerProgress.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        row.addArrangedSubview(notationPlayerProgress)
        row.addArrangedSubview(notationPlayerTimeLabel)
        return row
    }

    @objc private func notationPlayerSeekChanged() {
        midiPlayer.seek(fraction: notationPlayerProgress.doubleValue)
        playerProgress.doubleValue = notationPlayerProgress.doubleValue
        updatePlayerTime()
    }

'''
if helper_marker in s and 'private func buildPieceSlotBar(includeMotifButton:' not in s:
    s = s.replace(helper_marker, helpers + helper_marker, 1)

marker = '''        saveSettingsFromUI()\n        // Kein Zugriff auf den macOS-Schlüsselbund: Schlüssel gelten nur für diese Sitzung.\n'''
replacement = '''        saveSettingsFromUI()\n        pendingCompositionSlot = activePieceSlot\n        // Kein Zugriff auf den macOS-Schlüsselbund: Schlüssel gelten nur für diese Sitzung.\n'''
if marker in s and 'pendingCompositionSlot = activePieceSlot' not in s:
    s = s.replace(marker, replacement, 1)

marker = '''        lastScore = score; lastConcept = concept; lastProvider = provider; lastModel = model\n        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: " + score.ti\n'''
replacement = '''        if addHistory, let requestedSlot = pendingCompositionSlot {\n            activePieceSlot = max(0, min(requestedSlot, pieceSlots.count - 1))\n            pendingCompositionSlot = nil\n        }\n        lastScore = score; lastConcept = concept; lastProvider = provider; lastModel = model\n        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: " + score.ti\n'''
if marker in s and 'if addHistory, let requestedSlot = pendingCompositionSlot' not in s:
    s = s.replace(marker, replacement, 1)

marker = '''        if addHistory {\n            let scoreData = try? JSONEncoder().encode(score)\n'''
replacement = '''        if !slotSelectionLoad { captureCurrentInActiveSlot() }\n        updatePieceSlotButtons()\n\n        if addHistory {\n            let scoreData = try? JSONEncoder().encode(score)\n'''
if marker in s and 'if !slotSelectionLoad { captureCurrentInActiveSlot() }' not in s:
    s = s.replace(marker, replacement, 1)

marker = '''                            if changed, let sc = self.lastScore {\n                                self.history.insert(HistoryItem'''
replacement = '''                            if changed, let sc = self.lastScore {\n                                self.captureCurrentInActiveSlot()\n                                self.scheduleMusicXMLPreviewRefresh()\n                                self.history.insert(HistoryItem'''
if marker in s and 'self.captureCurrentInActiveSlot()\n                                self.scheduleMusicXMLPreviewRefresh()' not in s:
    s = s.replace(marker, replacement, 1)

marker = '''        playerTimeLabel.stringValue="\\(t(pos)) / \\(t(dur))"\n        if dur > 0 { playerProgress.doubleValue = max(0, min(1, pos / dur)) } else { playerProgress.doubleValue = 0 }\n'''.replace('\\\\(', '\\(')
replacement = '''        playerTimeLabel.stringValue="\\(t(pos)) / \\(t(dur))"\n        notationPlayerTimeLabel.stringValue = playerTimeLabel.stringValue\n        if dur > 0 {\n            let f = max(0, min(1, pos / dur))\n            playerProgress.doubleValue = f\n            notationPlayerProgress.doubleValue = f\n        } else {\n            playerProgress.doubleValue = 0\n            notationPlayerProgress.doubleValue = 0\n        }\n'''.replace('\\\\(', '\\(')
if marker in s and 'notationPlayerTimeLabel.stringValue = playerTimeLabel.stringValue' not in s:
    s = s.replace(marker, replacement, 1)

required = [
    'private var pieceSlots:',
    'buildPieceSlotBar(includeMotifButton: true)',
    'buildPieceSlotBar(includeMotifButton: false)',
    'private func buildPieceSlotBar(includeMotifButton:',
    'pendingCompositionSlot = activePieceSlot',
    'if addHistory, let requestedSlot = pendingCompositionSlot',
    'if !slotSelectionLoad { captureCurrentInActiveSlot() }',
    'self.captureCurrentInActiveSlot()',
    'private func buildNotationTransport()',
    'notationPlayerTimeLabel.stringValue = playerTimeLabel.stringValue'
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('V6 rebuild patch incomplete; missing: ' + ', '.join(missing))

p.write_text(s, encoding='utf-8')
print('Applied V6 rebuild: ten piece slots, motif generation, shared Main/Noten selection and Noten transport.')
