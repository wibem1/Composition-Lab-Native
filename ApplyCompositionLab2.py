from pathlib import Path

main_path = Path('Sources/MainViewController.swift')
app_path = Path('Sources/AppDelegate.swift')

s = main_path.read_text(encoding='utf-8')

# V6: Main + Noten + Technik. The old experiment/compare controllers remain
# compiled only as a rollback/reference layer and are no longer workspaces.
old = '    private let workspaceSegment = NSSegmentedControl(labels: ["Komposition", "Experimentallabor", "Vergleichslabor", "Notensatz"], trackingMode: .selectOne, target: nil, action: nil)\n'
new = '    private let workspaceSegment = NSSegmentedControl(labels: ["Main", "Noten", "Technik"], trackingMode: .selectOne, target: nil, action: nil)\n'
if old in s:
    s = s.replace(old, new, 1)
elif '["Main", "Noten", "Technik"]' not in s:
    raise SystemExit('V6 workspace segment pattern not found')

old_views = '''    private var workspaceViews: [NSView] {\n        [compositionWorkspaceHost, experimentWorkspaceHost, compareWorkspaceHost, notationWorkspaceHost]\n    }\n'''
new_views = '''    private var workspaceViews: [NSView] {\n        [compositionWorkspaceHost, notationWorkspaceHost, experimentWorkspaceHost]\n    }\n'''
if old_views in s:
    s = s.replace(old_views, new_views, 1)
elif new_views not in s:
    raise SystemExit('V6 workspaceViews pattern not found')

s = s.replace('workspaceSegment.widthAnchor.constraint(equalToConstant: 650)',
              'workspaceSegment.widthAnchor.constraint(equalToConstant: 390)', 1)

# Noten is index 1 in V6.
s = s.replace('        if i == 3 { scheduleMusicXMLPreviewRefresh() }\n',
              '        if i == 1 { scheduleMusicXMLPreviewRefresh() }\n', 1)
s = s.replace('workspaceSegment.selectedSegment = max(0, min(index, 3))',
              'workspaceSegment.selectedSegment = max(0, min(index, 2))')

s = s.replace('left.addArrangedSubview(title("Notensatz"))',
              'left.addArrangedSubview(title("Noten"))', 1)

# The experiment host becomes the clean Technik workspace. Remove the embedded
# legacy experiment view at runtime and build the new technical workspace.
marker = '''        buildMusicXMLWorkspace(notationHost)\n\n        // All four workspaces live in one neutral container.'''
replacement = '''        buildMusicXMLWorkspace(notationHost)\n\n        experimentWorkspaceHost.subviews.forEach { $0.removeFromSuperview() }\n        buildTechnicalWorkspace(experimentWorkspaceHost)\n\n        // V6 workspaces live in one neutral container.'''
if marker in s:
    s = s.replace(marker, replacement, 1)
elif 'buildTechnicalWorkspace(experimentWorkspaceHost)' not in s:
    raise SystemExit('V6 technical workspace insertion marker not found')

main_path.write_text(s, encoding='utf-8')

# Remove obsolete lab navigation from the application menu.
a = app_path.read_text(encoding='utf-8')
start = '''        let experimentItem = NSMenuItem(title: "Experimentallabor", action: nil, keyEquivalent: "")\n'''
end = '''        main.addItem(experimentItem)\n\n'''
if start in a:
    i = a.index(start)
    j = a.index(end, i) + len(end)
    a = a[:i] + a[j:]
app_path.write_text(a, encoding='utf-8')

print('Applied V6 workspace architecture: Main + Noten + Technik.')
