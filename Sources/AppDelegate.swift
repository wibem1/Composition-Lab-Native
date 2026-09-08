import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var mainVC: MainViewController?
    private let mainWindowFrameKey = "CompositionLab.MainWindow.Frame.v1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenus()
        createMainWindowIfNeeded()

        // Programmatically created AppKit windows can occasionally be ordered
        // behind other windows when an app is launched through `open` from a
        // shell script. Order it again on the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            self?.showMainWindow()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Also guarantees that a visible main window exists when the user
        // activates the app from Dock/menu bar.
        if window == nil || window?.isVisible == false {
            showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func createMainWindowIfNeeded() {
        guard window == nil else { return }

        let vc = MainViewController()
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1260, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Composition Lab Native · V3.5"
        w.contentViewController = vc
        w.minSize = NSSize(width: 1000, height: 680)
        w.isReleasedWhenClosed = false
        w.delegate = self

        // Fenstergröße und Position explizit speichern. Das ist robuster als
        // ausschließlich NSWindow-Frame-Autosave, insbesondere wenn die App
        // durch ein Update/Build beendet und neu gestartet wird.
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: mainWindowFrameKey), !saved.isEmpty {
            let restored = NSRectFromString(saved)
            if restored.width >= w.minSize.width,
               restored.height >= w.minSize.height,
               restored.width.isFinite,
               restored.height.isFinite {
                w.setFrame(restored, display: false)
                // Falls der gespeicherte Bildschirm nicht mehr vorhanden ist,
                // den sichtbaren Bereich des aktuellen Screens respektieren.
                if let screen = NSScreen.screens.first(where: { $0.frame.intersects(w.frame) }) {
                    var f = w.frame
                    let visible = screen.visibleFrame
                    f.size.width = min(f.width, visible.width)
                    f.size.height = min(f.height, visible.height)
                    f.origin.x = min(max(f.origin.x, visible.minX), visible.maxX - f.width)
                    f.origin.y = min(max(f.origin.y, visible.minY), visible.maxY - f.height)
                    w.setFrame(f, display: false)
                }
            } else {
                w.center()
            }
        } else {
            w.center()
        }

        mainVC = vc
        window = w
    }

    func windowDidResize(_ notification: Notification) {
        saveMainWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        saveMainWindowFrame()
    }

    func windowWillClose(_ notification: Notification) {
        saveMainWindowFrame()
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveMainWindowFrame()
    }

    private func saveMainWindowFrame() {
        guard let w = window, !w.frame.isEmpty else { return }
        UserDefaults.standard.set(NSStringFromRect(w.frame), forKey: mainWindowFrameKey)
        UserDefaults.standard.synchronize()
    }

    private func showMainWindow() {
        createMainWindowIfNeeded()
        guard let w = window else { return }

        if w.isMiniaturized {
            w.deminiaturize(nil)
        }
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func menuShowMainWindow() {
        showMainWindow()
    }

    private func buildMenus() {
        let main = NSMenu()

        let appItem = NSMenuItem(title: "Composition Lab", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Über Composition Lab · V3.5", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Composition Lab beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem(title: "Datei", action: nil, keyEquivalent: "")
        let file = NSMenu(title: "Datei")
        file.addItem(withTitle: "Projekt benennen …", action: #selector(MainViewController.menuNameProject), keyEquivalent: "")
        file.addItem(withTitle: "Composition-Lab-Datei öffnen …", action: #selector(MainViewController.menuLoadProject), keyEquivalent: "o")
        file.addItem(withTitle: "Composition-Lab-Datei sichern …", action: #selector(MainViewController.menuSaveProject), keyEquivalent: "s")
        file.addItem(NSMenuItem.separator())
        file.addItem(withTitle: "MIDI als Vorlage laden …", action: #selector(MainViewController.menuImportMIDI), keyEquivalent: "")
        file.addItem(withTitle: "MIDI-Vorlage löschen", action: #selector(MainViewController.menuClearImportedMIDI), keyEquivalent: "")
        file.addItem(NSMenuItem.separator())
        file.addItem(withTitle: "MIDI sichern …", action: #selector(MainViewController.menuSaveMIDI), keyEquivalent: "m")
        file.addItem(withTitle: "JSON sichern …", action: #selector(MainViewController.menuSaveJSON), keyEquivalent: "j")
        fileItem.submenu = file
        main.addItem(fileItem)

        let editItem = NSMenuItem(title: "Bearbeiten", action: nil, keyEquivalent: "")
        let edit = NSMenu(title: "Bearbeiten")
        edit.addItem(withTitle: "Rückgängig", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(NSMenuItem.separator())
        edit.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let compItem = NSMenuItem(title: "Komposition", action: nil, keyEquivalent: "")
        let comp = NSMenu(title: "Komposition")
        let c = NSMenuItem(title: "Mit gewählter KI komponieren", action: #selector(MainViewController.menuCompose), keyEquivalent: "\r")
        c.keyEquivalentModifierMask = [.command]
        comp.addItem(c)
        compItem.submenu = comp
        main.addItem(compItem)

        let experimentItem = NSMenuItem(title: "Experimentallabor", action: nil, keyEquivalent: "")
        let experiment = NSMenu(title: "Experimentallabor")
        experiment.addItem(withTitle: "Experimentallabor anzeigen", action: #selector(MainViewController.menuExperimentLab), keyEquivalent: "e")
        experiment.addItem(NSMenuItem.separator())
        experiment.addItem(withTitle: "Vergleichslabor anzeigen", action: #selector(MainViewController.menuCompareLab), keyEquivalent: "v")
        experimentItem.submenu = experiment
        main.addItem(experimentItem)

        let technicalItem = NSMenuItem(title: "Technisches", action: nil, keyEquivalent: "")
        let technical = NSMenu(title: "Technisches")
        technical.addItem(withTitle: "API-Schlüssel …", action: #selector(MainViewController.menuAPIKeys), keyEquivalent: "")
        technical.addItem(withTitle: "MIDI-Ausgabe …", action: #selector(MainViewController.menuMIDIOutput), keyEquivalent: "")
        technical.addItem(NSMenuItem.separator())
        technical.addItem(withTitle: "Backup laden …", action: #selector(MainViewController.menuImportBackup), keyEquivalent: "b")
        technical.addItem(withTitle: "Backup sichern …", action: #selector(MainViewController.menuExportBackup), keyEquivalent: "")
        technical.addItem(NSMenuItem.separator())
        technical.addItem(withTitle: "Diagnosedatei sichern …", action: #selector(MainViewController.menuSaveDiagnostic), keyEquivalent: "d")
        technicalItem.submenu = technical
        main.addItem(technicalItem)

        let displayItem = NSMenuItem(title: "Darstellung", action: nil, keyEquivalent: "")
        let display = NSMenu(title: "Darstellung")
        for (title, action) in [
            ("80 %", #selector(MainViewController.menuZoom80)),
            ("90 %", #selector(MainViewController.menuZoom90)),
            ("100 %", #selector(MainViewController.menuZoom100)),
            ("110 %", #selector(MainViewController.menuZoom110)),
            ("120 %", #selector(MainViewController.menuZoom120)),
            ("130 %", #selector(MainViewController.menuZoom130)),
            ("140 %", #selector(MainViewController.menuZoom140)),
            ("150 %", #selector(MainViewController.menuZoom150))
        ] {
            display.addItem(withTitle: title, action: action, keyEquivalent: "")
        }
        displayItem.submenu = display
        main.addItem(displayItem)

        let helpItem = NSMenuItem(title: "Hilfe", action: nil, keyEquivalent: "")
        let help = NSMenu(title: "Hilfe")
        let handbook = NSMenuItem(title: "Benutzerhandbuch (PDF) …", action: #selector(MainViewController.menuShowHelp), keyEquivalent: "?")
        handbook.keyEquivalentModifierMask = [.command]
        help.addItem(handbook)
        help.addItem(withTitle: "Kurzhilfe …", action: #selector(MainViewController.menuShowQuickHelp), keyEquivalent: "")
        helpItem.submenu = help
        main.addItem(helpItem)
        NSApp.helpMenu = help

        let windowItem = NSMenuItem(title: "Fenster", action: nil, keyEquivalent: "")
        let win = NSMenu(title: "Fenster")
        let show = NSMenuItem(title: "Composition Lab", action: #selector(menuShowMainWindow), keyEquivalent: "0")
        show.target = self
        win.addItem(show)
        win.addItem(NSMenuItem.separator())
        win.addItem(withTitle: "Minimieren", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "Zoomen", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowItem.submenu = win
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = win
    }
}
