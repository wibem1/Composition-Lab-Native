import Cocoa

/// Verwendet vollständig das native AppKit-Scrollverhalten.
/// Keine Veränderung von Scrolltempo, Deltas oder Trägheit.
final class FastScrollView: NSScrollView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureResponsiveScrolling()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureResponsiveScrolling()
    }

    private func configureResponsiveScrolling() {
        // Nur die dominante Achse bevorzugen. Das Scrolltempo und die eigentliche
        // Ereignisverarbeitung bleiben vollständig bei AppKit.
        usesPredominantAxisScrolling = true
    }
}
