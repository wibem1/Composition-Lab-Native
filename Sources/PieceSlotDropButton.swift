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
        wantsLayer = true
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
        layer?.cornerRadius = 8
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
