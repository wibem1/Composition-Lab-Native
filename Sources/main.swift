import Cocoa

// Explicit AppKit bootstrap. This avoids relying on implicit @main behavior
// and guarantees that the application delegate is installed and retained.
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.regular)
application.run()
