import Cocoa

@MainActor
final class CompareLabWindowController: NSWindowController {
    private let popA = NSPopUpButton()
    private let popB = NSPopUpButton()
    private let infoA = NSTextView()
    private let infoB = NSTextView()
    private let dialogOutput = NSTextView()
    private let dialogInput = NSTextField(string: "")
    private let sendButton = NSButton(frame: .zero)
    private let resultInfo = NSTextView()
    private let playerA = LabMIDIPlayerView()
    private let playerB = LabMIDIPlayerView()
    private let resultPlayer = LabMIDIPlayerView()
    private let dropA = CompositionSlotDropView(slotName: "Quelle A")
    private let dropB = CompositionSlotDropView(slotName: "Quelle B")
    private let transferResultButton = NSButton(frame: .zero)
    private var items: [HistoryItem] = []
    private var currentA: HistoryItem?
    private var currentB: HistoryItem?
    private var generatedResult: HistoryItem?
    private let historyFooter = HistoryFooterView(buttonTitles: ["Als A laden", "Als B laden"])
    private weak var contentRoot: NSView?

    var onCompare: ((HistoryItem, HistoryItem) -> Void)?
    var onSend: ((HistoryItem, HistoryItem, String, Bool) -> Void)?
    var onTransferResult: ((HistoryItem) -> Void)?
    var onGeneratedResult: ((HistoryItem) -> Void)?
    var onDeleteHistory: ((HistoryItem) -> Void)?

    convenience init(items: [HistoryItem]) {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Composition Lab · Vergleichslabor"
        w.minSize = NSSize(width: 900, height: 620)
        self.init(window: w)
        self.items = items
        build()
        refreshHistoryMenus(preserveSelection: false)
    }

    private func scroll(_ tv: NSTextView, _ h: CGFloat) -> NSScrollView {
        let s = NSScrollView()
        s.borderType = .lineBorder
        s.hasVerticalScroller = true
        s.autohidesScrollers = true
        s.translatesAutoresizingMaskIntoConstraints = false
        s.heightAnchor.constraint(equalToConstant: h).isActive = true

        // Die NSTextView muss eine echte, mitwachsende Dokumentansicht sein.
        // Nur documentView = tv reicht bei einer programmgesteuerten AppKit-Ansicht
        // nicht zuverlässig aus.
        tv.frame = NSRect(x: 0, y: 0, width: 700, height: h)
        tv.minSize = NSSize(width: 0, height: h)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                            height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.containerSize = NSSize(width: 700,
                                                 height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        s.documentView = tv
        return s
    }

    private func configureInfo(_ tv: NSTextView) {
        tv.isRichText = false
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = .systemFont(ofSize: 12.5)
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.backgroundColor = .textBackgroundColor
        tv.textColor = .textColor
    }

    private func makeCard() -> CompositionFileDropHostView {
        let v = CompositionFileDropHostView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        v.layer?.cornerRadius = 12
        v.layer?.borderWidth = 1
        v.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        return v
    }

    private func buildSourceCard(title: String,
                                 popup: NSPopUpButton,
                                 asA: Bool,
                                 info: NSTextView,
                                 player: LabMIDIPlayerView,
                                 drop: CompositionSlotDropView,
                                 loadSelector: Selector) -> NSView {
        // Im Vergleichslabor benutzen wir wieder ein explizites Drop-Feld.
        // Die gesamte Karte als Drop-Ziel hat sich in der zentralen Tab-Ansicht
        // als unzuverlässig erwiesen; das eigene Feld besitzt eine eindeutige
        // A/B-Zuordnung und registriert sich selbst bei AppKit.
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        let col = NSStackView()
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 10
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            col.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            col.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            col.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 15, weight: .bold)
        col.addArrangedSubview(heading)

        popup.target = self
        popup.action = #selector(selectionChanged(_:))
        popup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        col.addArrangedSubview(popup)
        popup.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true

        let load = NSButton(title: title == "Quelle A" ? "MIDI / MusicXML A laden …" : "MIDI / MusicXML B laden …", target: self, action: loadSelector)
        load.bezelStyle = .rounded
        col.addArrangedSubview(load)
        load.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true

        // Sichtbares, explizites Ziel wie in der früher zuverlässig funktionierenden Lösung.
        drop.translatesAutoresizingMaskIntoConstraints = false
        col.addArrangedSubview(drop)
        drop.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true
        drop.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let playerBox = NSView()
        player.translatesAutoresizingMaskIntoConstraints = false
        playerBox.addSubview(player)
        NSLayoutConstraint.activate([
            player.leadingAnchor.constraint(equalTo: playerBox.leadingAnchor, constant: 4),
            player.trailingAnchor.constraint(lessThanOrEqualTo: playerBox.trailingAnchor, constant: -4),
            player.topAnchor.constraint(equalTo: playerBox.topAnchor, constant: 4),
            player.bottomAnchor.constraint(equalTo: playerBox.bottomAnchor, constant: -4)
        ])
        col.addArrangedSubview(playerBox)
        playerBox.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true

        // Das bisherige info-Textfeld bleibt nur als Datenhalter bestehen,
        // wird aber nicht mehr als sichtbare Fläche eingebaut.
        info.isHidden = true

        return card
    }

    private func buildResultCard() -> NSView {
        let card = makeCard()
        let col = NSStackView()
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 12
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            col.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            col.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            col.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])

        let heading = NSTextField(labelWithString: "Ergebnis-MIDI")
        heading.font = .systemFont(ofSize: 16, weight: .bold)
        col.addArrangedSubview(heading)

        configureInfo(resultInfo)
        resultInfo.string = "Noch kein Ergebnis. Eine von der KI erzeugte neue MIDI-Fassung erscheint hier."
        resultInfo.backgroundColor = .clear
        resultInfo.drawsBackground = false
        resultInfo.isVerticallyResizable = true
        resultInfo.isHorizontallyResizable = false
        resultInfo.textContainerInset = NSSize(width: 0, height: 0)
        resultInfo.textContainer?.widthTracksTextView = true
        resultInfo.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        resultInfo.translatesAutoresizingMaskIntoConstraints = false
        col.addArrangedSubview(resultInfo)
        resultInfo.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true
        resultInfo.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true

        let resultPlayerBox = NSView()
        resultPlayer.translatesAutoresizingMaskIntoConstraints = false
        resultPlayerBox.addSubview(resultPlayer)
        NSLayoutConstraint.activate([
            resultPlayer.leadingAnchor.constraint(equalTo: resultPlayerBox.leadingAnchor, constant: 4),
            resultPlayer.trailingAnchor.constraint(lessThanOrEqualTo: resultPlayerBox.trailingAnchor, constant: -4),
            resultPlayer.topAnchor.constraint(equalTo: resultPlayerBox.topAnchor, constant: 4),
            resultPlayer.bottomAnchor.constraint(equalTo: resultPlayerBox.bottomAnchor, constant: -4)
        ])
        resultPlayerBox.isHidden = true
        resultPlayerBox.identifier = NSUserInterfaceItemIdentifier("resultPlayerBox")
        col.addArrangedSubview(resultPlayerBox)
        resultPlayerBox.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true

        transferResultButton.title = "An Komposition übergeben"
        transferResultButton.target = self
        transferResultButton.action = #selector(transferResult)
        transferResultButton.isEnabled = false
        transferResultButton.isHidden = true
        col.addArrangedSubview(transferResultButton)

        return card
    }

    private func buildDialogCard() -> NSView {
        let card = makeCard()
        let col = NSStackView()
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 14
        col.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(col)
        NSLayoutConstraint.activate([
            col.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            col.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            col.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            col.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22)
        ])

        let heading = NSTextField(labelWithString: "KI-Dialog im Vergleichslabor")
        heading.font = .systemFont(ofSize: 16, weight: .bold)
        col.addArrangedSubview(heading)

        configureInfo(dialogOutput)
        dialogOutput.string = "Frage die KI nach A und B oder gib ihr einen Kompositionsauftrag. Wenn du eine neue Fassung verlangst, erscheint die erzeugte MIDI-Datei automatisch darunter."
        let so = scroll(dialogOutput, 120)
        col.addArrangedSubview(so)
        so.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true

        // Bewusst dieselbe robuste Eingabetechnik wie im Experimentallabor:
        // ein normales NSTextField statt einer verschachtelten NSTextView/NSScrollView.
        dialogInput.isEditable = true
        dialogInput.isSelectable = true
        dialogInput.isEnabled = true
        dialogInput.font = .systemFont(ofSize: 13.5)
        dialogInput.placeholderString = "Frage oder Kompositionsauftrag an die KI …"
        dialogInput.focusRingType = .default
        dialogInput.bezelStyle = .roundedBezel
        dialogInput.translatesAutoresizingMaskIntoConstraints = false
        dialogInput.target = self
        dialogInput.action = #selector(sendDialog)

        sendButton.title = "An KI senden"
        sendButton.bezelStyle = .rounded
        sendButton.toolTip = "Frage oder Auftrag an die KI senden"
        sendButton.target = self
        sendButton.action = #selector(sendDialog)

        let chatRow = NSStackView()
        chatRow.orientation = .horizontal
        chatRow.alignment = .centerY
        chatRow.spacing = 12
        chatRow.translatesAutoresizingMaskIntoConstraints = false
        chatRow.addArrangedSubview(dialogInput)
        chatRow.addArrangedSubview(sendButton)
        dialogInput.heightAnchor.constraint(equalToConstant: 34).isActive = true
        dialogInput.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sendButton.setContentHuggingPriority(.required, for: .horizontal)
        col.addArrangedSubview(chatRow)
        chatRow.widthAnchor.constraint(equalTo: col.widthAnchor).isActive = true

        let hint = NSTextField(labelWithString: "Frage stellen oder einen Auftrag formulieren – z. B. ‚Verbinde die Melodie aus A mit der harmonischen Idee aus B.‘")
        hint.font = .systemFont(ofSize: 11.5)
        hint.textColor = .secondaryLabelColor
        col.addArrangedSubview(hint)
        return card
    }

    private func build() {
        guard let w = window else { return }
        let root = NSView(frame: w.contentView?.bounds ?? .zero)
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        w.contentView = root
        contentRoot = root

        let outerScroll = NSScrollView()
        outerScroll.hasVerticalScroller = true
        outerScroll.autohidesScrollers = true
        outerScroll.drawsBackground = false
        outerScroll.borderType = .noBorder
        outerScroll.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(outerScroll)
        NSLayoutConstraint.activate([
            outerScroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerScroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerScroll.topAnchor.constraint(equalTo: root.topAnchor),
            outerScroll.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        let doc = TopAlignedDocumentView()
        doc.wantsLayer = true
        doc.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        doc.translatesAutoresizingMaskIntoConstraints = false
        outerScroll.documentView = doc
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: outerScroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: outerScroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: outerScroll.contentView.topAnchor),
            doc.widthAnchor.constraint(equalTo: outerScroll.contentView.widthAnchor)
        ])

        let st = NSStackView()
        st.orientation = .vertical
        st.alignment = .leading
        st.spacing = 24
        st.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(st)
        let width = st.widthAnchor.constraint(lessThanOrEqualToConstant: 1040)
        width.priority = .required
        NSLayoutConstraint.activate([
            st.centerXAnchor.constraint(equalTo: doc.centerXAnchor),
            st.leadingAnchor.constraint(greaterThanOrEqualTo: doc.leadingAnchor, constant: 72),
            st.trailingAnchor.constraint(lessThanOrEqualTo: doc.trailingAnchor, constant: -72),
            width,
            st.topAnchor.constraint(equalTo: doc.topAnchor, constant: 28),
            st.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -48)
        ])

        let h = NSTextField(labelWithString: "Vergleichslabor")
        h.font = .systemFont(ofSize: 20, weight: .bold)
        st.addArrangedSubview(h)

        dropA.onDropFile = { [weak self] url in self?.loadDroppedComposition(url: url, asA: true) }
        dropB.onDropFile = { [weak self] url in self?.loadDroppedComposition(url: url, asA: false) }

        let sourceRow = NSStackView()
        sourceRow.orientation = .horizontal
        sourceRow.alignment = .top
        sourceRow.spacing = 32
        sourceRow.distribution = .fillEqually
        let aCard = buildSourceCard(title: "Quelle A", popup: popA, asA: true, info: infoA, player: playerA, drop: dropA, loadSelector: #selector(loadMidiA))
        let bCard = buildSourceCard(title: "Quelle B", popup: popB, asA: false, info: infoB, player: playerB, drop: dropB, loadSelector: #selector(loadMidiB))
        sourceRow.addArrangedSubview(aCard)
        sourceRow.addArrangedSubview(bCard)
        st.addArrangedSubview(sourceRow)
        sourceRow.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true

        let dialogCard = buildDialogCard()
        st.addArrangedSubview(dialogCard)
        dialogCard.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true

        let resultCard = buildResultCard()
        st.addArrangedSubview(resultCard)
        resultCard.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true

        let historySep = NSBox()
        historySep.boxType = .separator
        st.addArrangedSubview(historySep)
        historySep.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true
        historyFooter.onAction = { [weak self] action, item in
            guard let self else { return }
            if action == 0 { self.currentA = item } else { self.currentB = item }
            self.updateSourceViews()
        }
        historyFooter.onDelete = { [weak self] item in
            self?.onDeleteHistory?(item)
        }
        st.addArrangedSubview(historyFooter)
        historyFooter.widthAnchor.constraint(equalTo: st.widthAnchor).isActive = true
    }

    func update(items newItems: [HistoryItem], historyItems: [HistoryItem]? = nil) {
        // Die Auswahllisten A/B dürfen weiterhin auf den gesamten verfügbaren
        // Materialpool zugreifen. Der sichtbare Verlauf unten zeigt dagegen nur
        // Ergebnisse, die im Vergleichslabor selbst entstanden sind.
        historyFooter.setItems(historyItems ?? newItems)

        // Quellen aktualisieren, ohne aktuell im Vergleichslabor geladene Dateien zu verlieren.
        // Direkt hineingezogene MIDI-Dateien liegen bewusst nicht im gespeicherten Verlauf.
        var merged = newItems
        for current in [currentA, currentB] {
            guard let current else { continue }
            if !merged.contains(where: { $0.id == current.id }) {
                merged.append(current)
            }
        }
        self.items = merged
        refreshHistoryMenus(preserveSelection: true)
    }

    private func displayName(_ item: HistoryItem) -> String {
        (item.model == "MIDI-Datei" || item.model == "MusicXML-Datei") ? "\(item.title) · \(item.model)" : "\(item.title) · \(item.provider.displayName)"
    }

    private func refreshHistoryMenus(preserveSelection: Bool) {
        let oldA = currentA?.id
        let oldB = currentB?.id
        popA.removeAllItems(); popB.removeAllItems()
        popA.addItems(withTitles: items.map(displayName))
        popB.addItems(withTitles: items.map(displayName))

        if preserveSelection, let oldA, let idx = items.firstIndex(where: { $0.id == oldA }) {
            popA.selectItem(at: idx)
        } else if !items.isEmpty {
            popA.selectItem(at: 0)
            currentA = items[0]
        }
        if preserveSelection, let oldB, let idx = items.firstIndex(where: { $0.id == oldB }) {
            popB.selectItem(at: idx)
        } else if items.count > 1 {
            popB.selectItem(at: 1)
            currentB = items[1]
        } else if let first = items.first {
            popB.selectItem(at: 0)
            currentB = first
        }
        updateSourceViews()
    }

    @objc private func selectionChanged(_ sender: NSPopUpButton) {
        guard !items.isEmpty else { return }
        let idx = max(0, min(sender.indexOfSelectedItem, items.count - 1))
        if sender === popA { currentA = items[idx] }
        if sender === popB { currentB = items[idx] }
        updateSourceViews()
    }

    private func updateSourceViews() {
        if let a = currentA {
            dropA.displayTitle = a.title
            infoA.string = a.concept
            playerA.setScore(a.score)
        } else {
            dropA.displayTitle = nil
            infoA.string = "Noch keine Quelle A."
            playerA.setScore(nil)
        }
        if let b = currentB {
            dropB.displayTitle = b.title
            infoB.string = b.concept
            playerB.setScore(b.score)
        } else {
            dropB.displayTitle = nil
            infoB.string = "Noch keine Quelle B."
            playerB.setScore(nil)
        }
    }

    private func selected() -> (HistoryItem, HistoryItem)? {
        guard let a = currentA, let b = currentB else {
            dialogOutput.string = "Bitte zuerst Quelle A und Quelle B auswählen oder MIDI-/MusicXML-Dateien hineinziehen."
            return nil
        }
        return (a, b)
    }

    private func importedItem(url: URL) throws -> HistoryItem {
        let data = try Data(contentsOf: url)
        let fallback = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        let isXML = ext == "musicxml" || ext == "xml"
        let score = try (isXML
            ? MusicXMLParser.parse(data: data, fallbackTitle: fallback)
            : MIDIParser.parse(data: data, fallbackTitle: fallback))
        let visibleTitle = fallback.isEmpty ? score.ti : fallback
        return HistoryItem(
            id: UUID(), time: Date(), title: visibleTitle, provider: .openai,
            model: isXML ? "MusicXML-Datei" : "MIDI-Datei",
            concept: isXML ? "Importierte MusicXML-Datei" : "Importierte MIDI-Datei",
            score: score
        )
    }

    private func installImported(_ item: HistoryItem, asA: Bool) {
        items.append(item)
        popA.addItem(withTitle: displayName(item))
        popB.addItem(withTitle: displayName(item))
        let idx = items.count - 1
        if asA {
            currentA = item
            popA.selectItem(at: idx)
        } else {
            currentB = item
            popB.selectItem(at: idx)
        }
        updateSourceViews()
    }

    private func loadMidi(asA: Bool) {
        let panel = NSOpenPanel()
        panel.title = asA ? "MIDI- oder MusicXML-Datei für Quelle A laden" : "MIDI- oder MusicXML-Datei für Quelle B laden"
        panel.allowedFileTypes = ["mid", "midi", "musicxml", "xml"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadDroppedComposition(url: url, asA: asA)
    }

    @objc private func loadMidiA() { loadMidi(asA: true) }
    @objc private func loadMidiB() { loadMidi(asA: false) }

    func loadDroppedComposition(url: URL, asA: Bool) {
        do {
            let item = try importedItem(url: url)
            installImported(item, asA: asA)
        } catch {
            let a = NSAlert()
            a.messageText = "Datei konnte nicht geladen werden"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
    }

    @objc private func compare() {
        guard let (a, b) = selected() else { return }
        dialogOutput.string = "KI vergleicht A und B …"
        onCompare?(a, b)
    }

    private func isCompositionRequest(_ text: String) -> Bool {
        let s = text.lowercased()

        // Eindeutige Formulierungen für einen neuen musikalischen Output.
        let explicit = [
            "neue midi", "midi-datei", "mididatei", "neue fassung", "neues stück",
            "neue komposition", "komponiere", "komponier", "erzeuge daraus",
            "erstelle daraus", "mach daraus", "schreibe daraus", "schreib daraus",
            "führe die beiden", "führe beide", "führe a und b", "verbinde a und b",
            "verbinde die beiden", "kombiniere a und b", "kombiniere die beiden",
            "verschmelze", "vereinige"
        ]
        if explicit.contains(where: { s.contains($0) }) { return true }

        // Freiere natürliche Formulierungen: ein Aktionsverb plus ein Hinweis darauf,
        // dass ein neues musikalisches Ergebnis aus A/B gewünscht ist.
        let actionStems = [
            "kompon", "erzeug", "erstell", "schreib", "mach", "verbind",
            "kombin", "zusammenführ", "zusammenfüh", "verschmelz", "vereinig",
            "entwickl", "form daraus", "gestalte daraus"
        ]
        let resultTerms = [
            "midi", "fassung", "stück", "komposition", "version", "ergebnis",
            "a und b", "a & b", "beide", "beiden", "aus a", "aus b", "zusammen"
        ]
        let hasAction = actionStems.contains(where: { s.contains($0) })
        let hasResult = resultTerms.contains(where: { s.contains($0) })
        return hasAction && hasResult
    }

    @objc private func sendDialog() {
        let q = dialogInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            appendDialog("Hinweis", "Bitte zuerst eine Frage oder einen Auftrag eingeben.")
            return
        }

        // Wie im Experimentallabor: Die eigene Eingabe wird IMMER sofort sichtbar,
        // noch bevor Quellen, API-Key oder Callback geprüft werden.
        appendDialog("Du", q)
        dialogInput.stringValue = ""

        guard let (a, b) = selected() else {
            appendDialog("Hinweis", "Bitte zuerst Quelle A und Quelle B auswählen oder MIDI-/MusicXML-Dateien hineinziehen.")
            return
        }

        sendButton.isEnabled = false
        appendDialog("KI", "arbeitet …")

        guard let onSend else {
            appendDialog("Fehler", "Der KI-Dialog ist nicht mit der Hauptanwendung verbunden.")
            sendButton.isEnabled = true
            return
        }
        // Die Entscheidung Chat oder neue MIDI-Fassung trifft die KI selbst.
        // Der Bool-Wert bleibt aus Kompatibilitätsgründen in der Callback-Signatur,
        // wird von der Hauptanwendung aber nicht mehr ausgewertet.
        onSend(a, b, q, false)
    }

    private func appendDialog(_ who: String, _ text: String) {
        if !dialogOutput.string.isEmpty { dialogOutput.string += "\n\n" }
        dialogOutput.string += "\(who): \(text)"
        dialogOutput.scrollToEndOfDocument(nil)
    }

    func setDialogText(_ text: String) {
        appendDialog("KI", text)
        sendButton.isEnabled = true
    }

    private func setResultControlsVisible(_ visible: Bool) {
        if let root = contentRoot {
            func findBox(in view: NSView) -> NSView? {
                if view.identifier == NSUserInterfaceItemIdentifier("resultPlayerBox") { return view }
                for child in view.subviews {
                    if let found = findBox(in: child) { return found }
                }
                return nil
            }
            findBox(in: root)?.isHidden = !visible
        }
        transferResultButton.isHidden = !visible
    }

    func beginGeneratedResult() {
        generatedResult = nil
        transferResultButton.isEnabled = false
        resultInfo.string = "KI komponiert aus A und B …"
        resultPlayer.setScore(nil)
        setResultControlsVisible(false)
        appendDialog("KI", "Kompositionsauftrag erkannt. Musikalischer Impuls und neue MIDI-Fassung werden erzeugt …")
    }

    func setGeneratedResult(score: Score, concept: String, provider: Provider, model: String) {
        let item = HistoryItem(id: UUID(), time: Date(), title: score.ti, provider: provider, model: model, concept: concept, score: score, area: .comparison)
        generatedResult = item
        onGeneratedResult?(item)
        resultInfo.string = concept.isEmpty
            ? score.ti
            : "\(score.ti)\nMusikalischer Impuls: \(concept)"
        resultPlayer.setScore(score)
        transferResultButton.isEnabled = true
        setResultControlsVisible(true)
        let current = dialogOutput.string
        if let range = current.range(of: "\n\nKI:\n") {
            let userPart = String(current[..<range.lowerBound])
            dialogOutput.string = "\(userPart)\n\nKI:\nDie neue Fassung ist fertig. Sie kann direkt unter dem Dialog angehört und an die Kompositionsseite übergeben werden."
        } else {
            dialogOutput.string = "\(current)\n\nDie neue Fassung ist fertig. Sie kann direkt unter dem Dialog angehört und an die Kompositionsseite übergeben werden."
        }
        sendButton.isEnabled = true
    }

    @objc private func transferResult() {
        guard let item = generatedResult else { return }
        onTransferResult?(item)
    }
}
