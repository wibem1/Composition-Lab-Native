from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# V6.6.6 interactive diagnostic switches. V6.6.5 remains the baseline with all
# three suspects disabled in Noten; these menu actions allow each one to be
# re-enabled independently without rebuilding the app.
marker = '    @objc private func workspaceChanged() {\n'
if marker not in s:
    raise SystemExit('V6.6.6: workspaceChanged not found')

block = r'''    private var v666BridgeEnabledInNotation = false
    private var v666PlayerTimerEnabledInNotation = false
    private var v666PreviewEnabledInNotation = false

    @objc func menuDiagnosticBridge(_ sender: NSMenuItem) {
        v666BridgeEnabledInNotation.toggle()
        sender.state = v666BridgeEnabledInNotation ? .on : .off
        if workspaceSegment.selectedSegment == 1 {
            if v666BridgeEnabledInNotation {
                if reaperBridgeTimer == nil { startReaperBridgeWatcher() }
            } else {
                reaperBridgeTimer?.invalidate()
                reaperBridgeTimer = nil
            }
        }
        status("Diagnose · DAW-Brücke: \(v666BridgeEnabledInNotation ? "AN" : "AUS")", good: true)
    }

    @objc func menuDiagnosticPlayerTimer(_ sender: NSMenuItem) {
        v666PlayerTimerEnabledInNotation.toggle()
        sender.state = v666PlayerTimerEnabledInNotation ? .on : .off
        if workspaceSegment.selectedSegment == 1 {
            if v666PlayerTimerEnabledInNotation {
                if playerTimer == nil {
                    let timer = Timer(timeInterval: 0.10,
                                      target: self,
                                      selector: #selector(playerTimerFired(_:)),
                                      userInfo: nil,
                                      repeats: true)
                    timer.tolerance = 0.03
                    RunLoop.main.add(timer, forMode: .default)
                    playerTimer = timer
                }
            } else {
                playerTimer?.invalidate()
                playerTimer = nil
            }
        }
        status("Diagnose · Player-Timer: \(v666PlayerTimerEnabledInNotation ? "AN" : "AUS")", good: true)
    }

    @objc func menuDiagnosticPreview(_ sender: NSMenuItem) {
        v666PreviewEnabledInNotation.toggle()
        sender.state = v666PreviewEnabledInNotation ? .on : .off
        if workspaceSegment.selectedSegment == 1 {
            if v666PreviewEnabledInNotation {
                scheduleMusicXMLPreviewRefresh()
            } else {
                musicXMLPreviewTimer?.invalidate()
                musicXMLPreviewTimer = nil
            }
        }
        status("Diagnose · Noten/Verovio-Aktualisierung: \(v666PreviewEnabledInNotation ? "AN" : "AUS")", good: true)
    }

    private func v666ApplyNotationDiagnosticSwitches() {
        guard workspaceSegment.selectedSegment == 1 else { return }
        if !v666BridgeEnabledInNotation {
            reaperBridgeTimer?.invalidate()
            reaperBridgeTimer = nil
        } else if reaperBridgeTimer == nil {
            startReaperBridgeWatcher()
        }
        if !v666PlayerTimerEnabledInNotation {
            playerTimer?.invalidate()
            playerTimer = nil
        }
        if !v666PreviewEnabledInNotation {
            musicXMLPreviewTimer?.invalidate()
            musicXMLPreviewTimer = nil
        } else {
            scheduleMusicXMLPreviewRefresh()
        }
    }

'''
if 'menuDiagnosticBridge' not in s:
    s = s.replace(marker, block + marker, 1)

# V6.6.5 first establishes the known-good all-off baseline. Then apply the
# interactive switches so enabled suspects can be restored independently.
needle = '        v665SetNotationDiagnosticMode(i == 1)\n'
if needle not in s:
    raise SystemExit('V6.6.6: V6.6.5 diagnostic hook not found')
if 'v666ApplyNotationDiagnosticSwitches()' not in s.split(needle,1)[1][:120]:
    s = s.replace(needle, needle + '        if i == 1 { v666ApplyNotationDiagnosticSwitches() }\n', 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.6 interactive diagnostic switches.')

# Add a visible Diagnose menu to AppDelegate.
a = Path('Sources/AppDelegate.swift')
t = a.read_text(encoding='utf-8')
anchor = '''        let displayItem = NSMenuItem(title: "Darstellung", action: nil, keyEquivalent: "")
'''
menu = '''        let diagnoseItem = NSMenuItem(title: "Diagnose", action: nil, keyEquivalent: "")
        let diagnose = NSMenu(title: "Diagnose")
        for (title, action) in [
            ("DAW-Brücke im Notenview", #selector(MainViewController.menuDiagnosticBridge(_:))),
            ("Player-Timer im Notenview", #selector(MainViewController.menuDiagnosticPlayerTimer(_:))),
            ("Noten/Verovio-Aktualisierung", #selector(MainViewController.menuDiagnosticPreview(_:)))
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.state = .off
            diagnose.addItem(item)
        }
        diagnoseItem.submenu = diagnose
        main.addItem(diagnoseItem)

'''
if anchor not in t:
    raise SystemExit('V6.6.6: AppDelegate display-menu anchor not found')
if 'DAW-Brücke im Notenview' not in t:
    t = t.replace(anchor, menu + anchor, 1)
a.write_text(t, encoding='utf-8')
print('Added visible Diagnose menu with three independent switches.')
