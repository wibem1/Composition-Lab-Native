from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# V6.6.5 diagnostic: suspend periodic Main-thread work while Noten is visible.
workspace_marker = '    @objc private func workspaceChanged() {\n'
if workspace_marker not in s:
    raise SystemExit('V6.6.5: workspaceChanged not found')

helper = '''    private func v665SetNotationDiagnosticMode(_ enabled: Bool) {
        if enabled {
            reaperBridgeTimer?.invalidate()
            reaperBridgeTimer = nil
            playerTimer?.invalidate()
            playerTimer = nil
            musicXMLPreviewTimer?.invalidate()
            musicXMLPreviewTimer = nil
        } else {
            if reaperBridgeTimer == nil { startReaperBridgeWatcher() }
        }
    }

'''
if 'private func v665SetNotationDiagnosticMode' not in s:
    s = s.replace(workspace_marker, helper + workspace_marker, 1)

# The stable workspace architecture no longer uses NSTabView selection here.
# It toggles workspaceViews via host.isHidden. Inject after the visibility loop.
loop_block = '''        for (index, host) in workspaceViews.enumerated() {
            host.isHidden = index != i
        }
'''
if loop_block not in s:
    raise SystemExit('V6.6.5: neutral workspace visibility loop not found')
if 'v665SetNotationDiagnosticMode(i == 1)' not in s:
    s = s.replace(loop_block,
                  loop_block + '        v665SetNotationDiagnosticMode(i == 1)\n',
                  1)

# Disable automatic notation refresh in the workspace handler for this diagnostic.
s = s.replace('        if i == 1 { scheduleMusicXMLPreviewRefresh() }\n',
              '        // V6.6.5 Diagnose: kein automatisches Noten-Refresh beim Seitenwechsel.\n',
              1)
s = s.replace('        if i == 3 { scheduleMusicXMLPreviewRefresh() }\n',
              '        // V6.6.5 Diagnose: kein automatisches Noten-Refresh beim Seitenwechsel.\n',
              1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.5 notation scroll diagnostic: periodic timers suspended in Noten.')
