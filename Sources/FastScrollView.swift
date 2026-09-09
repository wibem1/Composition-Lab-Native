import Cocoa

/// Beschleunigt nur klassische Mausrad-Ereignisse.
/// Präzises Trackpad-Scrollen bleibt vollständig dem normalen AppKit-Verhalten überlassen.
final class FastScrollView: NSScrollView {
    private let mouseWheelMultiplier: CGFloat = 2.5

    override func scrollWheel(with event: NSEvent) {
        // Trackpads und hochauflösende Scrollgeräte liefern präzise Deltas.
        // Hier nichts verändern, damit Trägheit und Gesten natürlich bleiben.
        if event.hasPreciseScrollingDeltas {
            super.scrollWheel(with: event)
            return
        }

        guard let documentView else {
            super.scrollWheel(with: event)
            return
        }

        var origin = contentView.bounds.origin

        // Für klassische Mausräder ist scrollingDelta typischerweise nur ein kleiner
        // Schritt. Wir multiplizieren genau diesen diskreten Schritt.
        let verticalStep = max(verticalLineScroll, 10) * mouseWheelMultiplier
        let horizontalStep = max(horizontalLineScroll, 10) * mouseWheelMultiplier

        origin.y -= event.scrollingDeltaY * verticalStep
        origin.x += event.scrollingDeltaX * horizontalStep

        let maxX = max(0, documentView.frame.width - contentView.bounds.width)
        let maxY = max(0, documentView.frame.height - contentView.bounds.height)
        origin.x = min(max(origin.x, 0), maxX)
        origin.y = min(max(origin.y, 0), maxY)

        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }
}
