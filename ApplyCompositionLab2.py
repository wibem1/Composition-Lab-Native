from pathlib import Path

main_path = Path('Sources/MainViewController.swift')
app_path = Path('Sources/AppDelegate.swift')

s = main_path.read_text(encoding='utf-8')

# This patch is intentionally applied AFTER ApplyWorkspaceLayoutFix.py.
# It turns the existing four-workspace shell into the Composition Lab 2
# two-page architecture while leaving the old lab controllers in the source
# as a rollback/reference layer for now.

old = '    private let workspaceSegment = NSSegmentedControl(labels: ["Komposition", "Experimentallabor", "Vergleichslabor", "Notensatz"], trackingMode: .selectOne, target: nil, action: nil)\n'
new = '    private let workspaceSegment = NSSegmentedControl(labels: ["Main", "Noten"], trackingMode: .selectOne, target: nil, action: nil)\n'
if old in s:
    s = s.replace(old, new, 1)
elif '["Main", "Noten"]' not in s:
    raise SystemExit('Composition Lab 2: workspace segment pattern not found')

old_views = '''    private var workspaceViews: [NSView] {\n        [compositionWorkspaceHost, experimentWorkspaceHost, compareWorkspaceHost, notationWorkspaceHost]\n    }\n'''
new_views = '''    private var workspaceViews: [NSView] {\n        [compositionWorkspaceHost, notationWorkspaceHost]\n    }\n'''
if old_views in s:
    s = s.replace(old_views, new_views, 1)
elif new_views not in s:
    raise SystemExit('Composition Lab 2: workspaceViews pattern not found')

s = s.replace('workspaceSegment.widthAnchor.constraint(equalToConstant: 650)',
              'workspaceSegment.widthAnchor.constraint(equalToConstant: 300)', 1)

# After the neutral-container patch workspaceChanged uses workspaceViews.count.
# The notation page is now index 1 instead of old index 3.
s = s.replace('        if i == 3 { scheduleMusicXMLPreviewRefresh() }\n',
              '        if i == 1 { scheduleMusicXMLPreviewRefresh() }\n', 1)

# selectWorkspace may still carry the old hard-coded maximum in older source.
s = s.replace('workspaceSegment.selectedSegment = max(0, min(index, 3))',
              'workspaceSegment.selectedSegment = max(0, min(index, 1))')

# Visible wording: the page is now simply Noten; the underlying MusicXML
# implementation and settings remain unchanged.
s = s.replace('left.addArrangedSubview(title("Notensatz"))',
              'left.addArrangedSubview(title("Noten"))', 1)

main_path.write_text(s, encoding='utf-8')

# Remove obsolete top-level lab navigation from the application menu. The old
# controller code remains compiled for rollback while the v6 replacement is
# introduced incrementally.
a = app_path.read_text(encoding='utf-8')
start = '''        let experimentItem = NSMenuItem(title: "Experimentallabor", action: nil, keyEquivalent: "")\n'''
end = '''        main.addItem(experimentItem)\n\n'''
if start in a:
    i = a.index(start)
    j = a.index(end, i) + len(end)
    a = a[:i] + a[j:]
app_path.write_text(a, encoding='utf-8')

print('Applied Composition Lab 2 two-page architecture: Main + Noten.')
