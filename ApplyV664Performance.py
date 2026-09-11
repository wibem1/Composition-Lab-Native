from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# PERFORMANCE ROUND V6.6.4
# 1. Bridge polling no longer runs during event tracking/scrolling and polls less often.
old = '''        let timer = Timer(timeInterval: 1.50,\n                          target: self,\n                          selector: #selector(reaperBridgeTimerFired(_:)),\n                          userInfo: nil,\n                          repeats: true)\n        timer.tolerance = 0.50\n        RunLoop.main.add(timer, forMode: .default)\n        reaperBridgeTimer = timer\n'''
new = '''        let timer = Timer(timeInterval: 3.0,\n                          target: self,\n                          selector: #selector(reaperBridgeTimerFired(_:)),\n                          userInfo: nil,\n                          repeats: true)\n        timer.tolerance = 1.0\n        // Intentionally .default: bridge polling pauses while AppKit is tracking\n        // scroll wheels, sliders, menus and mouse drags. UI interaction wins.\n        RunLoop.main.add(timer, forMode: .default)\n        reaperBridgeTimer = timer\n'''
if old in s:
    s = s.replace(old, new, 1)
elif 'timeInterval: 3.0' not in s:
    raise SystemExit('V6.6.4: bridge timer block not found')

# 2. Do not build/render notation while the user is working on Main/Technik.
old = '''    private func scheduleMusicXMLPreviewRefresh() {\n        musicXMLPreviewTimer?.invalidate()\n        musicXMLPreviewTimer = Timer.scheduledTimer(timeInterval: 0.35,\n                                                    target: self,\n                                                    selector: #selector(musicXMLPreviewTimerFired(_:)),\n                                                    userInfo: nil,\n                                                    repeats: false)\n    }\n'''
new = '''    private func scheduleMusicXMLPreviewRefresh() {\n        musicXMLPreviewTimer?.invalidate()\n        musicXMLPreviewTimer = nil\n        // Notation is expensive (MusicXML generation + WebKit/Verovio rendering).\n        // Only refresh it while the Noten workspace is actually visible.\n        guard workspaceSegment.selectedSegment == 1 else { return }\n        let timer = Timer(timeInterval: 0.20,\n                          target: self,\n                          selector: #selector(musicXMLPreviewTimerFired(_:)),\n                          userInfo: nil,\n                          repeats: false)\n        timer.tolerance = 0.08\n        RunLoop.main.add(timer, forMode: .default)\n        musicXMLPreviewTimer = timer\n    }\n'''
if old in s:
    s = s.replace(old, new, 1)
elif 'Only refresh it while the Noten workspace is actually visible.' not in s:
    raise SystemExit('V6.6.4: notation scheduling block not found')

# 3. Current V6 workspace indices are Main=0, Noten=1, Technik=2. Ensure switching to Noten refreshes once.
old = '''        if i == 3 { scheduleMusicXMLPreviewRefresh() }\n'''
new = '''        if i == 1 { scheduleMusicXMLPreviewRefresh() }\n'''
if old in s:
    s = s.replace(old, new, 1)

# 4. Avoid history/table work on every workspace switch. It is irrelevant for Main/Noten.
old = '''        workspaceTabs.selectTabViewItem(at: i)\n        refreshVisibleHistories()\n        if i == 1 { scheduleMusicXMLPreviewRefresh() }\n'''
new = '''        workspaceTabs.selectTabViewItem(at: i)\n        if i == 2 { refreshVisibleHistories() }\n        if i == 1 { scheduleMusicXMLPreviewRefresh() }\n'''
if old in s:
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('Applied V6.6.4 performance round: slower bridge polling, no notation rendering offscreen, less history refresh.')
