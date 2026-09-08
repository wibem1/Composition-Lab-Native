import Cocoa

struct ExperimentRequest {
    var measures: Int
    var tempo: String
    var ensemble: String
    var style: String
    var task: String
}

@MainActor
final class ExperimentLabWindowController: NSWindowController {
    private let measures = NSPopUpButton()
    private let tempo = NSTextField(string: "")
    private let ensemble = NSTextField(string: "Klavier solo")
    private let style = NSTextField(string: "")
    private let task = NSTextView()
    private let status = NSTextField(labelWithString: "Bereit.")
    private let chatView = NSTextView()
    private let chatInput = NSTextField(string: "")
    private let midiPlayer = LabMIDIPlayerView()
    private let historyFooter = HistoryFooterView(buttonTitles: ["Als Vorlage laden"])

    var onGenerate: ((ExperimentRequest) -> Void)?
    var onChat: ((String) -> Void)?
    var onTransferToComposition: (() -> Void)?
    var onLoadHistory: ((HistoryItem) -> Void)?
    var onDeleteHistory: ((HistoryItem) -> Void)?
    var onImportFile: ((URL) -> Void)?

    convenience init() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Composition Lab · Experimentallabor"
        w.minSize = NSSize(width: 650, height: 560)
        self.init(window: w)
        build()
    }

    private func label(_ text: String) -> NSTextField {
        let x = NSTextField(labelWithString: text)
        x.font = .systemFont(ofSize: 12, weight: .semibold)
        return x
    }

    private func field(_ title: String, _ control: NSView) -> NSView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 4
        s.addArrangedSubview(label(title))
        s.addArrangedSubview(control)
        return s
    }

    private func scroll(_ tv: NSTextView, height: CGFloat) -> NSScrollView {
        let s = NSScrollView()
        s.borderType = .bezelBorder
        s.hasVerticalScroller = true
        s.hasHorizontalScroller = false
        s.autohidesScrollers = true

        // NSTextView ausdrücklich für die eingebettete Laboransicht konfigurieren.
        // Ohne diese Größen-/Container-Einstellungen konnte die View nach dem
        // Umhängen aus dem eigenen NSWindow sichtbar sein, aber keine verlässliche
        // Texteingabe annehmen.
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.minSize = NSSize(width: 0, height: height)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.containerSize = NSSize(width: 730, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        s.documentView = tv

        s.heightAnchor.constraint(equalToConstant: height).isActive = true
        return s
    }

    private func makeCard() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        v.layer?.cornerRadius = 12
        v.layer?.borderWidth = 1
        v.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        return v
    }

    private func build() {
        // WICHTIG: Die äußere Fenster-/Scroll-Architektur bleibt exakt dieselbe
        // wie in der stabilen V4.22. Geändert wird nur die innere Gestaltung.
        guard let content = window?.contentView else { return }

        let sc = NSScrollView()
        sc.hasVerticalScroller = true
        sc.drawsBackground = false
        sc.translatesAutoresizingMaskIntoConstraints = false
        let doc = NSView()
        doc.wantsLayer = true
        doc.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        doc.translatesAutoresizingMaskIntoConstraints = false
        sc.documentView = doc
        content.addSubview(sc)
        NSLayoutConstraint.activate([
            sc.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sc.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            sc.topAnchor.constraint(equalTo: content.topAnchor),
            sc.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            doc.widthAnchor.constraint(equalTo: sc.contentView.widthAnchor)
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        let maxWidth = stack.widthAnchor.constraint(lessThanOrEqualToConstant: 1040)
        maxWidth.priority = .required
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: doc.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: doc.leadingAnchor, constant: 72),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: doc.trailingAnchor, constant: -72),
            maxWidth,
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -48)
        ])

        let h = NSTextField(labelWithString: "Experimentallabor")
        h.font = .systemFont(ofSize: 20, weight: .bold)
        stack.addArrangedSubview(h)

        let hint = NSTextField(wrappingLabelWithString: "Erzeuge kurze musikalische Vorlagen, besprich sie direkt mit der KI und übernimm interessante Ergebnisse als Ausgangsmaterial.")
        hint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hint)
        hint.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Einstellungen / Auftrag – als ruhige Karte wie im Vergleichslabor.
        let setupCard = makeCard()
        let setup = NSStackView()
        setup.orientation = .vertical
        setup.alignment = .leading
        setup.spacing = 14
        setup.translatesAutoresizingMaskIntoConstraints = false
        setupCard.addSubview(setup)
        NSLayoutConstraint.activate([
            setup.leadingAnchor.constraint(equalTo: setupCard.leadingAnchor, constant: 28),
            setup.trailingAnchor.constraint(equalTo: setupCard.trailingAnchor, constant: -28),
            setup.topAnchor.constraint(equalTo: setupCard.topAnchor, constant: 22),
            setup.bottomAnchor.constraint(equalTo: setupCard.bottomAnchor, constant: -22)
        ])

        let setupHeading = NSTextField(labelWithString: "Vorlage erzeugen")
        setupHeading.font = .systemFont(ofSize: 16, weight: .bold)
        setup.addArrangedSubview(setupHeading)

        measures.addItems(withTitles: ["2 Takte", "4 Takte", "8 Takte"])
        measures.selectItem(at: 1)

        let row = NSStackView(views: [field("Länge", measures), field("Tempo (leer = frei)", tempo)])
        row.orientation = .horizontal
        row.spacing = 24
        row.distribution = .fillEqually
        setup.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: setup.widthAnchor).isActive = true

        setup.addArrangedSubview(field("Besetzung / Instrumente", ensemble))
        ensemble.widthAnchor.constraint(equalTo: setup.widthAnchor).isActive = true
        setup.addArrangedSubview(field("Stil / Charakter", style))
        style.widthAnchor.constraint(equalTo: setup.widthAnchor).isActive = true

        task.isRichText = false
        task.isEditable = true
        task.isSelectable = true
        task.allowsUndo = true
        task.drawsBackground = true
        task.backgroundColor = .textBackgroundColor
        task.font = .systemFont(ofSize: 13)
        task.string = "Erfinde eine eigenständige, interessante musikalische Keimzelle."
        task.textContainerInset = NSSize(width: 8, height: 8)
        let taskScroll = scroll(task, height: 110)
        let taskField = field("Auftrag für die Vorlage", taskScroll)
        setup.addArrangedSubview(taskField)
        taskField.widthAnchor.constraint(equalTo: setup.widthAnchor).isActive = true
        taskScroll.widthAnchor.constraint(equalTo: setup.widthAnchor).isActive = true

        let b = NSButton(title: "Vorlage mit gewählter KI erzeugen", target: self, action: #selector(generate))
        b.bezelStyle = .rounded
        setup.addArrangedSubview(b)

        status.textColor = .systemGreen
        setup.addArrangedSubview(status)

        stack.addArrangedSubview(setupCard)
        setupCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Aktuelle Vorlage.
        let resultCard = makeCard()
        let result = NSStackView()
        result.orientation = .vertical
        result.alignment = .leading
        result.spacing = 12
        result.translatesAutoresizingMaskIntoConstraints = false
        resultCard.addSubview(result)
        NSLayoutConstraint.activate([
            result.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 28),
            result.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor, constant: -28),
            result.topAnchor.constraint(equalTo: resultCard.topAnchor, constant: 20),
            result.bottomAnchor.constraint(equalTo: resultCard.bottomAnchor, constant: -20)
        ])

        let ph = NSTextField(labelWithString: "Aktuelle Vorlage")
        ph.font = .systemFont(ofSize: 16, weight: .bold)
        result.addArrangedSubview(ph)

        // Der vorhandene Vorlagen-/Playerbereich ist zugleich Drag-and-Drop-Ziel.
        // Dadurch kommt kein zusätzliches sichtbares Feld hinzu.
        let playerBox = CompositionFileDropHostView()
        playerBox.onDropFile = { [weak self] url in self?.onImportFile?(url) }
        playerBox.toolTip = "MIDI- oder MusicXML-Datei hierher ziehen"
        midiPlayer.translatesAutoresizingMaskIntoConstraints = false
        playerBox.addSubview(midiPlayer)
        NSLayoutConstraint.activate([
            midiPlayer.leadingAnchor.constraint(equalTo: playerBox.leadingAnchor, constant: 4),
            midiPlayer.trailingAnchor.constraint(lessThanOrEqualTo: playerBox.trailingAnchor, constant: -4),
            midiPlayer.topAnchor.constraint(equalTo: playerBox.topAnchor, constant: 4),
            midiPlayer.bottomAnchor.constraint(equalTo: playerBox.bottomAnchor, constant: -4)
        ])
        result.addArrangedSubview(playerBox)
        playerBox.widthAnchor.constraint(equalTo: result.widthAnchor).isActive = true

        let transfer = NSButton(title: "An Komposition übernehmen", target: self, action: #selector(transferToComposition))
        transfer.bezelStyle = .rounded
        result.addArrangedSubview(transfer)

        stack.addArrangedSubview(resultCard)
        resultCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // KI-Dialog – gleicher Aufbau wie im Vergleichslabor.
        let dialogCard = makeCard()
        let dialog = NSStackView()
        dialog.orientation = .vertical
        dialog.alignment = .leading
        dialog.spacing = 14
        dialog.translatesAutoresizingMaskIntoConstraints = false
        dialogCard.addSubview(dialog)
        NSLayoutConstraint.activate([
            dialog.leadingAnchor.constraint(equalTo: dialogCard.leadingAnchor, constant: 28),
            dialog.trailingAnchor.constraint(equalTo: dialogCard.trailingAnchor, constant: -28),
            dialog.topAnchor.constraint(equalTo: dialogCard.topAnchor, constant: 22),
            dialog.bottomAnchor.constraint(equalTo: dialogCard.bottomAnchor, constant: -22)
        ])

        let ch = NSTextField(labelWithString: "KI-Dialog im Experimentallabor")
        ch.font = .systemFont(ofSize: 16, weight: .bold)
        dialog.addArrangedSubview(ch)

        chatView.isEditable = false
        chatView.isRichText = false
        chatView.font = .systemFont(ofSize: 13)
        chatView.string = "Hier kannst du die erzeugte Vorlage und ihren musikalischen Impuls mit der KI besprechen."
        chatView.textContainerInset = NSSize(width: 8, height: 8)
        let chatScroll = scroll(chatView, height: 120)
        dialog.addArrangedSubview(chatScroll)
        chatScroll.widthAnchor.constraint(equalTo: dialog.widthAnchor).isActive = true

        chatInput.placeholderString = "Frage oder Änderungswunsch zur Vorlage …"
        chatInput.heightAnchor.constraint(equalToConstant: 34).isActive = true
        chatInput.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let send = NSButton(title: "Senden", target: self, action: #selector(sendChat))
        send.setContentHuggingPriority(.required, for: .horizontal)
        let chatRow = NSStackView()
        chatRow.orientation = .horizontal
        chatRow.alignment = .centerY
        chatRow.spacing = 12
        chatRow.addArrangedSubview(chatInput)
        chatRow.addArrangedSubview(send)
        dialog.addArrangedSubview(chatRow)
        chatRow.widthAnchor.constraint(equalTo: dialog.widthAnchor).isActive = true

        stack.addArrangedSubview(dialogCard)
        dialogCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let historySep = NSBox()
        historySep.boxType = .separator
        stack.addArrangedSubview(historySep)
        historySep.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        historyFooter.onAction = { [weak self] _, item in self?.onLoadHistory?(item) }
        historyFooter.onDelete = { [weak self] item in self?.onDeleteHistory?(item) }
        stack.addArrangedSubview(historyFooter)
        historyFooter.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    func setHistory(_ items: [HistoryItem]) { historyFooter.setItems(items) }

    @objc private func generate() {
        let lengths = [2, 4, 8]
        let index = max(0, min(2, measures.indexOfSelectedItem))
        let r = ExperimentRequest(
            measures: lengths[index],
            tempo: tempo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            ensemble: ensemble.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            style: style.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            task: task.string.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        setStatus("KI erzeugt Vorlage …", good: true)
        onGenerate?(r)
    }

    @objc private func transferToComposition() {
        onTransferToComposition?()
    }

    @objc private func sendChat() {
        let q = chatInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        appendChat("Du", q)
        chatInput.stringValue = ""
        onChat?(q)
    }

    func setScore(_ score: Score) { midiPlayer.setScore(score) }

    func appendChat(_ who: String, _ text: String) {
        if !chatView.string.isEmpty { chatView.string += "\n\n" }
        chatView.string += "\(who): \(text)"
        chatView.scrollToEndOfDocument(nil)
    }

    func setStatus(_ text: String, good: Bool) {
        status.stringValue = text
        status.textColor = good ? .systemGreen : .systemRed
    }
}
