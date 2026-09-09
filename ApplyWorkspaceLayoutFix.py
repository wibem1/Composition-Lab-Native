from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Idempotent: if the neutral workspace container is already present, do nothing.
if 'private let workspaceHost = NSView()' in s:
    raise SystemExit(0)

old = '    private let workspaceTabs = NSTabView()\n'
new = '''    private let workspaceHost = NSView()\n    private let compositionWorkspaceHost = CompositionFileDropHostView()\n    private let experimentWorkspaceHost = NSView()\n    private let compareWorkspaceHost = NSView()\n    private let notationWorkspaceHost = NSView()\n    private var workspaceViews: [NSView] {\n        [compositionWorkspaceHost, experimentWorkspaceHost, compareWorkspaceHost, notationWorkspaceHost]\n    }\n'''
if old not in s:
    raise SystemExit('Workspace property pattern not found')
s = s.replace(old, new, 1)

s = s.replace('        workspaceTabs.wantsLayer = true\n        workspaceTabs.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n',
              '        workspaceHost.wantsLayer = true\n        workspaceHost.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n', 1)

old_block = '''        workspaceTabs.tabViewType = .noTabsNoBorder\n        workspaceTabs.translatesAutoresizingMaskIntoConstraints = false\n        view.addSubview(workspaceTabs)\n\n        let compositionItem = NSTabViewItem(identifier: "composition")\n        let experimentItem = NSTabViewItem(identifier: "experiment")\n        let compareItem = NSTabViewItem(identifier: "compare")\n        let notationItem = NSTabViewItem(identifier: "notation")\n        compositionItem.label = "Komposition"\n        experimentItem.label = "Experimentallabor"\n        compareItem.label = "Vergleichslabor"\n        notationItem.label = "Notensatz"\n        workspaceTabs.addTabViewItem(compositionItem)\n        workspaceTabs.addTabViewItem(experimentItem)\n        workspaceTabs.addTabViewItem(compareItem)\n        workspaceTabs.addTabViewItem(notationItem)\n\n        let compositionHost = CompositionFileDropHostView()\n'''
new_block = '''        workspaceHost.translatesAutoresizingMaskIntoConstraints = false\n        view.addSubview(workspaceHost)\n\n        let compositionHost = compositionWorkspaceHost\n'''
if old_block not in s:
    raise SystemExit('Workspace tab construction pattern not found')
s = s.replace(old_block, new_block, 1)

s = s.replace('        compositionItem.view = compositionHost\n', '', 1)

old_exp = '''            let host = NSView()\n            host.wantsLayer = true\n            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n            labView.translatesAutoresizingMaskIntoConstraints = false\n            host.addSubview(labView)\n'''
new_exp = '''            let host = experimentWorkspaceHost\n            host.wantsLayer = true\n            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n            labView.translatesAutoresizingMaskIntoConstraints = false\n            host.addSubview(labView)\n'''
if old_exp not in s:
    raise SystemExit('Experiment host pattern not found')
s = s.replace(old_exp, new_exp, 1)
s = s.replace('            experimentItem.view = host\n', '', 1)

old_cmp = '''            let host = NSView()\n            host.wantsLayer = true\n            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n            host.addSubview(labView)\n'''
new_cmp = '''            let host = compareWorkspaceHost\n            host.wantsLayer = true\n            host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor\n            host.addSubview(labView)\n'''
if old_cmp not in s:
    raise SystemExit('Compare host pattern not found')
s = s.replace(old_cmp, new_cmp, 1)
s = s.replace('            compareItem.view = host\n', '', 1)

s = s.replace('        let notationHost = NSView()\n', '        let notationHost = notationWorkspaceHost\n', 1)
s = s.replace('        notationItem.view = notationHost\n', '', 1)

marker = '''        buildMusicXMLWorkspace(notationHost)\n\n        refreshVisibleHistories()\n'''
replacement = '''        buildMusicXMLWorkspace(notationHost)\n\n        // All four workspaces live in one neutral container. Switching only\n        // toggles visibility and never changes NSWindow geometry.\n        for (index, host) in workspaceViews.enumerated() {\n            host.translatesAutoresizingMaskIntoConstraints = false\n            if host.superview !== workspaceHost { workspaceHost.addSubview(host) }\n            NSLayoutConstraint.activate([\n                host.leadingAnchor.constraint(equalTo: workspaceHost.leadingAnchor),\n                host.trailingAnchor.constraint(equalTo: workspaceHost.trailingAnchor),\n                host.topAnchor.constraint(equalTo: workspaceHost.topAnchor),\n                host.bottomAnchor.constraint(equalTo: workspaceHost.bottomAnchor)\n            ])\n            host.isHidden = index != 0\n        }\n\n        refreshVisibleHistories()\n'''
if marker not in s:
    raise SystemExit('Notation completion marker not found')
s = s.replace(marker, replacement, 1)

s = s.replace('            workspaceTabs.leadingAnchor.constraint(equalTo: view.leadingAnchor),\n            workspaceTabs.trailingAnchor.constraint(equalTo: view.trailingAnchor),\n            workspaceTabs.topAnchor.constraint(equalTo: header.bottomAnchor),\n            workspaceTabs.bottomAnchor.constraint(equalTo: statusBar.topAnchor),\n',
              '            workspaceHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),\n            workspaceHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),\n            workspaceHost.topAnchor.constraint(equalTo: header.bottomAnchor),\n            workspaceHost.bottomAnchor.constraint(equalTo: statusBar.topAnchor),\n', 1)

old_changed = '''    @objc private func workspaceChanged() {\n        let i = max(0, min(workspaceSegment.selectedSegment, workspaceTabs.numberOfTabViewItems - 1))\n        workspaceTabs.selectTabViewItem(at: i)\n        refreshVisibleHistories()\n        if i == 3 { scheduleMusicXMLPreviewRefresh() }\n    }\n'''
new_changed = '''    @objc private func workspaceChanged() {\n        let i = max(0, min(workspaceSegment.selectedSegment, workspaceViews.count - 1))\n        for (index, host) in workspaceViews.enumerated() {\n            host.isHidden = index != i\n        }\n        refreshVisibleHistories()\n        if i == 3 { scheduleMusicXMLPreviewRefresh() }\n    }\n'''
if old_changed not in s:
    raise SystemExit('workspaceChanged pattern not found')
s = s.replace(old_changed, new_changed, 1)

# Places that previously selected tab 0 directly now use the normal workspace switcher.
s = s.replace('workspaceTabs.selectTabViewItem(at: 0)', 'selectWorkspace(0)')

if 'workspaceTabs' in s:
    raise SystemExit('Unexpected workspaceTabs reference remains after patch')

p.write_text(s, encoding='utf-8')
print('Applied neutral workspace container fix.')
