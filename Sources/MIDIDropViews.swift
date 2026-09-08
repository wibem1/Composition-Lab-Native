import Cocoa

/// Liest eine aus Finder oder einer anderen macOS-App gezogene MIDI-Datei robust aus dem Pasteboard.
private func droppedMIDIURL(from sender: NSDraggingInfo) -> URL? {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLsOnly: true
    ]
    guard let urls = sender.draggingPasteboard.readObjects(
        forClasses: [NSURL.self],
        options: options
    ) as? [URL] else { return nil }

    return urls.first { url in
        let ext = url.pathExtension.lowercased()
        return ext == "mid" || ext == "midi"
    }
}


/// Liest eine MIDI- oder MusicXML-Datei aus dem Pasteboard.
private func droppedCompositionURL(from sender: NSDraggingInfo) -> URL? {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else { return nil }
    return urls.first { ["mid", "midi", "musicxml", "xml", "clab", "clabproject"].contains($0.pathExtension.lowercased()) }
}

@MainActor
final class CompositionFileDropHostView: NSView {
    var onDropFile: ((URL) -> Void)?
    private var dragActive = false { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        unregisterDraggedTypes(); registerForDraggedTypes([.fileURL])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard droppedCompositionURL(from: sender) != nil else { return [] }
        dragActive = true; return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedCompositionURL(from: sender) == nil ? [] : .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { dragActive = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { dragActive = false }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { droppedCompositionURL(from: sender) != nil }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedCompositionURL(from: sender) else { dragActive = false; return false }
        dragActive = false
        let action = onDropFile
        DispatchQueue.main.async { [weak self] in
            action?(url)
            self?.unregisterDraggedTypes(); self?.registerForDraggedTypes([.fileURL])
        }
        return true
    }
}

@MainActor
final class CompositionSlotDropView: NSView {
    let slotName: String
    var onDropFile: ((URL) -> Void)?
    var displayTitle: String? { didSet { needsDisplay = true } }
    private var dragActive = false { didSet { needsDisplay = true } }

    init(slotName: String) {
        self.slotName = slotName
        super.init(frame: .zero)
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
        toolTip = "MIDI- oder MusicXML-Datei aus dem Finder hierher ziehen"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        unregisterDraggedTypes()
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard droppedCompositionURL(from: sender) != nil else { return [] }
        dragActive = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedCompositionURL(from: sender) == nil ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { dragActive = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { dragActive = false }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        droppedCompositionURL(from: sender) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedCompositionURL(from: sender) else { dragActive = false; return false }
        dragActive = false
        let action = onDropFile
        DispatchQueue.main.async { [weak self] in
            action?(url)
            self?.unregisterDraggedTypes()
            self?.registerForDraggedTypes([.fileURL])
        }
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        (dragActive ? NSColor.selectedControlColor.withAlphaComponent(0.13) : NSColor.textBackgroundColor).setFill()
        path.fill()
        (dragActive ? NSColor.selectedControlColor : NSColor.separatorColor).setStroke()
        path.lineWidth = dragActive ? 2 : 1
        path.stroke()

        let title = displayTitle ?? "MIDI / MusicXML hier ablegen"
        let sub = displayTitle == nil
            ? "\(slotName) · .mid, .midi, .musicxml oder .xml"
            : "\(slotName) · zum Ersetzen neue Datei hier ablegen"
        let p = NSMutableParagraphStyle(); p.alignment = .center
        let attrs1: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor, .paragraphStyle: p]
        let attrs2: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: p]
        title.draw(in: NSRect(x: 8, y: bounds.midY - 4, width: bounds.width - 16, height: 20), withAttributes: attrs1)
        sub.draw(in: NSRect(x: 8, y: bounds.midY - 24, width: bounds.width - 16, height: 18), withAttributes: attrs2)
    }
}

/// Gemeinsame Basisklasse: registriert sich erneut, sobald die View in ihr endgültiges Fenster
/// eingehängt wurde. Das ist wichtig, weil die Laboransichten in Composition Lab aus ihren
/// ursprünglichen NSWindow-Containern in das zentrale Tab-Fenster umgehängt werden.
@MainActor
class MIDIRegisteredDropView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerMIDIType()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerMIDIType()
    }

    func registerMIDIType() {
        unregisterDraggedTypes()
        registerForDraggedTypes([.fileURL])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerMIDIType()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        droppedMIDIURL(from: sender) != nil
    }
}

@MainActor
final class MIDIDropHostView: MIDIRegisteredDropView {
    var onDropMIDI: ((URL) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedMIDIURL(from: sender) == nil ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedMIDIURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedMIDIURL(from: sender) else { return false }
        let action = onDropMIDI
        // Wichtig: Die Zielansicht nicht während des noch laufenden AppKit-Drag-Vorgangs
        // umfangreich umbauen. Das eigentliche Laden startet im nächsten Main-Loop-Durchlauf.
        DispatchQueue.main.async { [weak self] in
            action?(url)
            self?.registerMIDIType()
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        super.concludeDragOperation(sender)
        registerMIDIType()
    }
}

@MainActor
final class MIDIDropButton: NSButton {
    var onDropMIDI: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerMIDIType()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerMIDIType()
    }

    func registerMIDIType() {
        unregisterDraggedTypes()
        registerForDraggedTypes([.fileURL])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerMIDIType()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard droppedMIDIURL(from: sender) != nil else { return [] }
        state = .on
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedMIDIURL(from: sender) == nil ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        droppedMIDIURL(from: sender) != nil
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        state = .off
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        state = .off
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { state = .off }
        guard let url = droppedMIDIURL(from: sender) else { return false }
        onDropMIDI?(url)
        return true
    }
}

/// Drop-Ziel für das Vergleichslabor. Die linke Fensterhälfte ist A, die rechte B.
@MainActor
final class MIDICompareDropHostView: MIDIRegisteredDropView {
    var onDropMIDI: ((URL, Bool) -> Void)?   // true = A, false = B

    private func isA(_ sender: NSDraggingInfo) -> Bool {
        let point = convert(sender.draggingLocation, from: nil)
        return point.x < bounds.midX
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedMIDIURL(from: sender) == nil ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedMIDIURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedMIDIURL(from: sender) else { return false }
        let targetIsA = isA(sender)
        let action = onDropMIDI
        // Erst den Drag sauber abschließen; danach Popups, Textfelder und Player aktualisieren.
        DispatchQueue.main.async { [weak self] in
            action?(url, targetIsA)
            self?.registerMIDIType()
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        super.concludeDragOperation(sender)
        registerMIDIType()
    }
}

/// Große, dauerhaft aktive Drop-Fläche für genau einen MIDI-Slot im Vergleichslabor.
/// Sie enthält bewusst keine Unteransichten, damit Finder-Drags immer direkt diese View treffen.
@MainActor
final class MIDISlotDropView: MIDIRegisteredDropView {
    let slotName: String
    var onDropMIDI: ((URL) -> Void)?
    var displayTitle: String? { didSet { needsDisplay = true } }
    private var dragActive = false { didSet { needsDisplay = true } }

    init(slotName: String) {
        self.slotName = slotName
        super.init(frame: .zero)
        wantsLayer = true
        toolTip = "MIDI-Datei aus dem Finder hierher ziehen"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard droppedMIDIURL(from: sender) != nil else { return [] }
        dragActive = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedMIDIURL(from: sender) == nil ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { dragActive = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { dragActive = false }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = droppedMIDIURL(from: sender) else { dragActive = false; return false }
        dragActive = false
        onDropMIDI?(url)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        super.concludeDragOperation(sender)
        dragActive = false
        registerMIDIType()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        (dragActive ? NSColor.selectedControlColor.withAlphaComponent(0.13) : NSColor.textBackgroundColor).setFill()
        path.fill()
        (dragActive ? NSColor.selectedControlColor : NSColor.separatorColor).setStroke()
        path.lineWidth = dragActive ? 2 : 1
        path.stroke()

        let title = displayTitle ?? "MIDI hier hineinziehen"
        let sub = displayTitle == nil ? "\(slotName) · .mid oder .midi" : "\(slotName) · zum Ersetzen neue MIDI hier hineinziehen"
        let p = NSMutableParagraphStyle(); p.alignment = .center
        let attrs1: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor, .paragraphStyle: p]
        let attrs2: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: p]
        let r1 = NSRect(x: 8, y: bounds.midY - 4, width: bounds.width - 16, height: 20)
        let r2 = NSRect(x: 8, y: bounds.midY - 24, width: bounds.width - 16, height: 18)
        title.draw(in: r1, withAttributes: attrs1)
        sub.draw(in: r2, withAttributes: attrs2)
    }
}
