import Cocoa

@MainActor
final class MIDIOutputSettingsWindowController: NSWindowController {
    private let modePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let destinationPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var destinations: [MIDIOutputManager.Destination] = []

    init() {
        super.init(window: nil)

        let vc = NSViewController()
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "MIDI-Ausgabe")
        title.font = NSFont.boldSystemFont(ofSize: 17)
        root.addArrangedSubview(title)
        root.addArrangedSubview(NSTextField(labelWithString: "Ausgabemodus"))

        modePopup.addItems(withTitles: ["Eingebauter Sound", "Mac MIDI-Ausgang"])
        modePopup.target = self
        modePopup.action = #selector(modeChanged(_:))
        root.addArrangedSubview(modePopup)

        root.addArrangedSubview(NSTextField(labelWithString: "MIDI-Ziel"))
        root.addArrangedSubview(destinationPopup)

        let hint = NSTextField(wrappingLabelWithString: "Für virtuelle MIDI-Ausgabe kann z. B. der IAC-Treiber aus Audio-MIDI-Setup gewählt werden. Diese Einstellung gilt für den Hauptplayer und alle Player in den Laboren.")
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 430
        root.addArrangedSubview(hint)

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let cancel = NSButton(title: "Abbrechen", target: self, action: #selector(cancelPressed(_:)))
        let apply = NSButton(title: "Übernehmen", target: self, action: #selector(applyPressed(_:)))
        apply.keyEquivalent = "\r"
        buttons.addArrangedSubview(cancel)
        buttons.addArrangedSubview(apply)
        root.addArrangedSubview(buttons)

        vc.view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 270))
        vc.view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 22),
            root.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -22),
            root.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 20)
        ])

        let w = NSWindow(contentViewController: vc)
        w.title = "MIDI-Ausgabe"
        w.styleMask = [.titled, .closable]
        w.setContentSize(NSSize(width: 500, height: 270))
        w.center()
        self.window = w
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func reload() {
        let mgr = MIDIOutputManager.shared
        destinations = mgr.destinations()
        modePopup.selectItem(at: mgr.mode == .midiDestination ? 1 : 0)
        destinationPopup.removeAllItems()
        if destinations.isEmpty {
            destinationPopup.addItem(withTitle: "Kein MIDI-Ausgang gefunden")
            destinationPopup.isEnabled = false
        } else {
            destinationPopup.addItems(withTitles: destinations.map(\.name))
            if let idx = destinations.firstIndex(where: { $0.uniqueID == mgr.selectedUniqueID }) {
                destinationPopup.selectItem(at: idx)
            }
            destinationPopup.isEnabled = modePopup.indexOfSelectedItem == 1
        }
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        destinationPopup.isEnabled = sender.indexOfSelectedItem == 1 && !destinations.isEmpty
    }

    @objc private func cancelPressed(_ sender: Any?) { close() }

    @objc private func applyPressed(_ sender: Any?) {
        let mgr = MIDIOutputManager.shared
        if modePopup.indexOfSelectedItem == 0 {
            mgr.mode = .internalSound
        } else if !destinations.isEmpty {
            let idx = max(0, min(destinations.count - 1, destinationPopup.indexOfSelectedItem))
            mgr.selectedUniqueID = destinations[idx].uniqueID
            mgr.mode = .midiDestination
        }
        close()
    }
}
