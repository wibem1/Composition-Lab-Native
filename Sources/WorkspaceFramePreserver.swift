import Cocoa
import ObjectiveC.runtime

/// Verhindert, dass ein Wechsel zwischen den integrierten Arbeitsbereichen
/// die vom Benutzer gewählte Größe und Position des Hauptfensters verändert.
///
/// `workspaceChanged()` ist bereits als Objective-C-Action exponiert. Dadurch
/// können wir die bestehende Implementierung kapseln, ohne die umfangreiche
/// MainViewController-Datei für diese kleine Korrektur anfassen zu müssen.
enum WorkspaceFramePreserver {
    private static var installed = false

    @MainActor
    static func install() {
        guard !installed else { return }
        installed = true

        let cls: AnyClass = MainViewController.self
        let originalSelector = NSSelectorFromString("workspaceChanged")
        let replacementSelector = #selector(MainViewController.cl_workspaceChangedPreservingWindowFrame)

        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let replacementMethod = class_getInstanceMethod(cls, replacementSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, replacementMethod)
    }
}

extension MainViewController {
    /// Nach dem Swizzling ruft diese Methode über denselben Selektor die
    /// ursprüngliche `workspaceChanged()`-Implementierung auf.
    @objc fileprivate func cl_workspaceChangedPreservingWindowFrame() {
        let oldFrame = view.window?.frame

        // Nach method_exchangeImplementations() verweist dieser Aufruf auf die
        // ursprüngliche workspaceChanged()-Implementierung.
        cl_workspaceChangedPreservingWindowFrame()

        guard let window = view.window, let oldFrame else { return }

        // Manche Auto-Layout-Anpassungen erfolgen erst am Ende des aktuellen
        // Runloops. Deshalb den gewünschten Frame einmal sofort und einmal im
        // nächsten Runloop-Takt wiederherstellen.
        window.setFrame(oldFrame, display: true)
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            window.setFrame(oldFrame, display: true)
        }
    }
}
