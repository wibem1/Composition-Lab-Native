import Cocoa

/// Exportknopf mit zwei Bedienarten:
/// Klick = gewohnter Speichern-Dialog, Ziehen = temporaere Datei als macOS-Datei-Drag.
final class ExportDragButton: NSButton, NSDraggingSource {
    var exportFileProvider: (() -> URL?)?

    override func mouseDown(with event: NSEvent) {
        let start = convert(event.locationInWindow, from: nil)
        highlight(true)

        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            switch next.type {
            case .leftMouseDragged:
                let p = convert(next.locationInWindow, from: nil)
                if hypot(p.x - start.x, p.y - start.y) >= 4.0 {
                    highlight(false)
                    startFileDrag(with: next)
                    return
                }
            case .leftMouseUp:
                highlight(false)
                if bounds.contains(convert(next.locationInWindow, from: nil)) {
                    _ = sendAction(action, to: target)
                }
                return
            default:
                break
            }
        }
        highlight(false)
    }

    private func startFileDrag(with event: NSEvent) {
        guard let url = exportFileProvider?() else { return }
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let image = dragImage()
        let mouse = convert(event.locationInWindow, from: nil)
        let frame = NSRect(x: mouse.x - image.size.width / 2,
                           y: mouse.y - image.size.height / 2,
                           width: image.size.width,
                           height: image.size.height)
        item.setDraggingFrame(frame, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    private func dragImage() -> NSImage {
        let size = NSSize(width: max(150, bounds.width), height: max(28, bounds.height))
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlBackgroundColor.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 6, yRadius: 6).fill()
        let text = title as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: max(6, (size.width - textSize.width) / 2),
                              y: max(2, (size.height - textSize.height) / 2)),
                  withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}
