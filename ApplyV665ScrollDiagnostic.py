from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# V6.6.5 diagnostic: while Noten is visible, suspend every periodic Main-thread timer
# that can steal event-loop time. No functional redesign; this isolates the source
# of the repeated ~2 s scroll latency reported in V6.

old = '''    @objc private func workspaceChanged() {
'''
if old not in s:
    raise SystemExit('V6.6.5: workspaceChanged not found')

# Add a tiny helper before workspaceChanged. We deliberately stop bridge/player timers
# on entry to Noten. Bridge polling is restarted on leaving Noten; player timer will
# restart naturally on next Play.
helper = '''    private func v665SetNotationDiagnosticMode(_ enabled: Bool) {
        if enabled {
            reaperBridgeTimer?.invalidate()
            reaperBridgeTimer = nil
            playerTimer?.invalidate()
            playerTimer = nil
            musicXMLPreviewTimer?.invalidate()
            musicXMLPreviewTimer = nil
        } else {
            if reaperBridgeTimer == nil { startReaperBridgeTimer() }
        }
    }

'''
s = s.replace(old, helper + old, 1)

# Patch the final V6 workspace handler. The build chain has already converted the
# visible workspaces to Main=0, Noten=1, Technik=2.
needle = '''        workspaceTabs.selectTabViewItem(at: i)
        if i == 2 { refreshVisibleHistories() }
        if i == 1 { scheduleMusicXMLPreviewRefresh() }
'''
replacement = '''        workspaceTabs.selectTabViewItem(at: i)
        v665SetNotationDiagnosticMode(i == 1)
        if i == 2 { refreshVisibleHistories() }
        // Diagnostic build: no automatic notation refresh while Noten is visible.
        // Existing rendered notation stays untouched so scrolling can be measured alone.
'''
if needle not in s:
    raise SystemExit('V6.6.5: final workspace handler pattern not found')
s = s.replace(needle, replacement, 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.5 notation scroll diagnostic: timers suspended in Noten.')
