from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

segment = '    private let workspaceSegment = NSSegmentedControl(labels: ["Main", "Noten", "Technik"], trackingMode: .selectOne, target: nil, action: nil)\n'
props = '''    private let workspaceSegment = NSSegmentedControl(labels: ["Main", "Noten", "Technik"], trackingMode: .selectOne, target: nil, action: nil)\n    // V6: zehn gleichberechtigte Stück-/Varianten-Slots.\n    private var pieceSlots: [HistoryItem?] = [HistoryItem?](repeating: nil, count: 10)\n    private var activePieceSlot: Int = 0\n    private var pendingCompositionSlot: Int?\n    private var slotSelectionLoad = false\n    private var mainPieceSlotButtons: [NSButton] = []\n    private var notationPieceSlotButtons: [NSButton] = []\n    private let notationPlayerTimeLabel = NSTextField(labelWithString: "0:00 / 0:00")\n    private let notationPlayerProgress = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)\n'''
if 'private var pieceSlots:' not in s:
    if segment not in s:
        raise SystemExit('V6 slots: three-workspace segment not found')
    s = s.replace(segment, props, 1)

# Noten: große Stückauswahl + eigener Transport oberhalb des Notenbilds.
marker = '''        let topRow = NSStackView()\n        topRow.orientation = .horizontal\n'''
replacement = '''        let notationSlotBar = buildNotationPieceSlotBar()\n        rightStack.addArrangedSubview(notationSlotBar)\n        notationSlotBar.widthAnchor.constraint(equalTo: rightStack.widthAnchor).isActive = true\n\n        let notationTransport = buildNotationTransport()\n        rightStack.addArrangedSubview(notationTransport)\n        notationTransport.widthAnchor.constraint(equalTo: rightStack.widthAnchor).isActive = true\n\n        let topRow = NSStackView()\n        topRow.orientation = .horizontal\n'''
if 'let notationSlotBar = buildNotationPieceSlotBar()' not in s:
    if marker not in s:
        raise SystemExit('V6 slots: notation topRow marker not found')
    s = s.replace(marker, replacement, 1)

helper_marker = '    private func separatorBox() -> NSBox {\n'
helpers = r'''    private func buildNotationPieceSlotBar() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.addArrangedSubview(title("Stücke / Varianten"))
        titleRow.addArrangedSubview(NSView())
        let hint = NSTextField(labelWithString: "Stück auswählen und direkt im Notenbild ansehen")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        titleRow.addArrangedSubview(hint)
        stack.addArrangedSubview(titleRow)
        titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 7
        var buttons: [NSButton] = []
        for i in 0..<10 {
            let b = NSButton(title: "\(i + 1)", target: self, action: #selector(pieceSlotPressed(_:)))
            b.tag = i
            b.bezelStyle = .rounded
            b.setButtonType(.toggle)
            b.heightAnchor.constraint(equalToConstant: 38).isActive = true
            buttons.append(b)
            row.addArrangedSubview(b)
        }
        notationPieceSlotButtons = buttons
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        updatePieceSlotButtons()
        return stack
    }

    private func updatePieceSlotButtons() {
        func apply(_ buttons: [NSButton], large: Bool) {
            for (i, b) in buttons.enumerated() where i < pieceSlots.count {
                let item = pieceSlots[i]
                if large {
                    b.title = item.map { "\(i + 1)\n\($0.title)" } ?? "\(i + 1)\nDatei ablegen"
                } else {
                    b.title = item == nil ? "\(i + 1)" : "● \(i + 1)"
                }
                b.state = i == activePieceSlot ? .on : .off
                b.toolTip = item.map { "Stück \(i + 1): \($0.title)" } ?? "Stück \(i + 1): leer"
            }
        }
        apply(mainPieceSlotButtons, large: true)
        apply(notationPieceSlotButtons, large: false)
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
        if newIndex != activePieceSlot { captureCurrentInActiveSlot() }
        activePieceSlot = newIndex
        guard let item = pieceSlots[newIndex] else {
            updatePieceSlotButtons()
            status("Stück-Slot \(newIndex + 1) ist leer. Die nächste Komposition oder importierte Datei landet hier.", good: true)
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
        scheduleMusicXMLPreviewRefresh()
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
if 'private func buildNotationPieceSlotBar()' not in s:
    if helper_marker not in s:
        raise SystemExit('V6 slots: helper insertion marker not found')
    s = s.replace(helper_marker, helpers + helper_marker, 1)

# Bind an asynchronous composition request to the slot active at request start.
marker = '''        saveSettingsFromUI()\n        // Kein Zugriff auf den macOS-Schlüsselbund: Schlüssel gelten nur für diese Sitzung.\n'''
replacement = '''        saveSettingsFromUI()\n        pendingCompositionSlot = activePieceSlot\n        // Kein Zugriff auf den macOS-Schlüsselbund: Schlüssel gelten nur für diese Sitzung.\n'''
if 'pendingCompositionSlot = activePieceSlot' not in s:
    if marker not in s:
        raise SystemExit('V6 slots: compose request marker not found')
    s = s.replace(marker, replacement, 1)

marker = '''        lastScore = score; lastConcept = concept; lastProvider = provider; lastModel = model\n        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: " + score.ti\n'''
replacement = '''        if addHistory, let requestedSlot = pendingCompositionSlot {\n            activePieceSlot = max(0, min(requestedSlot, pieceSlots.count - 1))\n            pendingCompositionSlot = nil\n        }\n        lastScore = score; lastConcept = concept; lastProvider = provider; lastModel = model\n        musicXMLCurrentLabel.stringValue = "Aktuelles Stück: " + score.ti\n'''
if 'if addHistory, let requestedSlot = pendingCompositionSlot' not in s:
    if marker not in s:
        raise SystemExit('V6 slots: install marker not found')
    s = s.replace(marker, replacement, 1)

marker = '''        if addHistory {\n            let scoreData = try? JSONEncoder().encode(score)\n'''
replacement = '''        if !slotSelectionLoad { captureCurrentInActiveSlot() }\n        updatePieceSlotButtons()\n\n        if addHistory {\n            let scoreData = try? JSONEncoder().encode(score)\n'''
if 'if !slotSelectionLoad { captureCurrentInActiveSlot() }' not in s:
    if marker not in s:
        raise SystemExit('V6 slots: history marker not found')
    s = s.replace(marker, replacement, 1)

marker = '''                            if changed, let sc = self.lastScore {\n                                self.history.insert(HistoryItem'''
replacement = '''                            if changed, let sc = self.lastScore {\n                                self.captureCurrentInActiveSlot()\n                                self.scheduleMusicXMLPreviewRefresh()\n                                self.history.insert(HistoryItem'''
if 'self.captureCurrentInActiveSlot()\n                                self.scheduleMusicXMLPreviewRefresh()' not in s:
    if marker not in s:
        raise SystemExit('V6 slots: chat update marker not found')
    s = s.replace(marker, replacement, 1)

marker = '        playerTimeLabel.stringValue="\\(t(pos)) / \\(t(dur))"\n        if dur > 0 { playerProgress.doubleValue = max(0, min(1, pos / dur)) } else { playerProgress.doubleValue = 0 }\n'
replacement = '''        playerTimeLabel.stringValue="\\(t(pos)) / \\(t(dur))"\n        notationPlayerTimeLabel.stringValue = playerTimeLabel.stringValue\n        if dur > 0 {\n            let f = max(0, min(1, pos / dur))\n            playerProgress.doubleValue = f\n            notationPlayerProgress.doubleValue = f\n        } else {\n            playerProgress.doubleValue = 0\n            notationPlayerProgress.doubleValue = 0\n        }\n'''
if 'notationPlayerTimeLabel.stringValue = playerTimeLabel.stringValue' not in s:
    if marker not in s:
        raise SystemExit('V6 slots: player time marker not found')
    s = s.replace(marker, replacement, 1)

required = [
    'private var pieceSlots:',
    'private func buildNotationPieceSlotBar()',
    'pendingCompositionSlot = activePieceSlot',
    'if addHistory, let requestedSlot = pendingCompositionSlot',
    'private func buildNotationTransport()',
    'notationPlayerTimeLabel.stringValue = playerTimeLabel.stringValue'
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('V6 slots patch incomplete: ' + ', '.join(missing))

p.write_text(s, encoding='utf-8')
print('Applied V6 slot state for Main + Noten + Technik.')
