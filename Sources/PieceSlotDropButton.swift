import Cocoa

final class PieceSlotDropButton: NSButton {
    var onDropFile: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureDrop()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDrop()
    }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    private func configureDrop() {
        registerForDraggedTypes([.fileURL])
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.masksToBounds = true
    }

    override var state: NSControl.StateValue {
        didSet { needsDisplay = true }
    }

    override var title: String {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)

        let selected = state == .on
        let pressed = isHighlighted
        let fill: NSColor
        if pressed {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.20)
        } else if selected {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.11)
        } else {
            fill = NSColor.controlBackgroundColor
        }
        fill.setFill()
        path.fill()

        (selected ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = selected ? 2 : 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let textRect = rect.insetBy(dx: 8, dy: 10)
        let text = NSAttributedString(string: title, attributes: attrs)
        let size = text.boundingRect(with: NSSize(width: textRect.width, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading]).size
        let y = textRect.midY - min(size.height, textRect.height) / 2
        text.draw(with: NSRect(x: textRect.minX, y: y, width: textRect.width, height: min(size.height, textRect.height)),
                  options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    override func mouseDown(with event: NSEvent) {
        needsDisplay = true
        super.mouseDown(with: event)
        needsDisplay = true
    }

    private func acceptedURL(_ info: NSDraggingInfo) -> URL? {
        let pasteboard = info.draggingPasteboard
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              let url = items.first else { return nil }
        let ext = url.pathExtension.lowercased()
        return ["mid", "midi", "musicxml", "xml", "clab", "clabproject"].contains(ext) ? url : nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard acceptedURL(sender) != nil else { return [] }
        layer?.borderWidth = 2
        layer?.cornerRadius = 9
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderWidth = 0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { layer?.borderWidth = 0 }
        guard let url = acceptedURL(sender) else { return false }
        onDropFile?(url)
        return true
    }
}
