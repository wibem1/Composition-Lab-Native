from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

if 'private func buildTechnicalWorkspace(_ parent: NSView)' in s:
    print('V6.3 Technik workspace already present.')
    raise SystemExit(0)

marker = '    @objc private func workspaceChanged() {\n'
idx = s.find(marker)
if idx < 0:
    raise SystemExit('V6.3 Technik: workspaceChanged marker not found')

func = r'''    private func buildTechnicalWorkspace(_ parent: NSView) {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            root.topAnchor.constraint(equalTo: parent.topAnchor),
            root.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        root.addArrangedSubview(title("Technik"))
        let intro = NSTextField(wrappingLabelWithString: "API-Schlüssel, MIDI-Ausgabe, technische Prüfung, JSON, Diagnose und Verlauf. Diese Werkzeuge sind bewusst von der musikalischen Hauptseite getrennt.")
        intro.textColor = .secondaryLabelColor
        root.addArrangedSubview(intro)
        intro.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.addArrangedSubview(NSButton(title: "API-Schlüssel …", target: self, action: #selector(menuAPIKeys)))
        actions.addArrangedSubview(NSButton(title: "MIDI-Ausgabe …", target: self, action: #selector(menuMIDIOutput)))
        actions.addArrangedSubview(NSButton(title: "CLAB öffnen …", target: self, action: #selector(openCLABPressed)))
        actions.addArrangedSubview(NSButton(title: "CLAB sichern …", target: self, action: #selector(saveCLABPressed)))
        actions.addArrangedSubview(NSButton(title: "JSON sichern …", target: self, action: #selector(saveJSONPressed)))
        root.addArrangedSubview(actions)

        let tabs = NSTabView()
        tabs.translatesAutoresizingMaskIntoConstraints = false

        let validationTab = NSTabViewItem(identifier: "validation")
        validationTab.label = "Technische Prüfung"
        validationView.isEditable = false
        validationTab.view = textScroll(validationView, minHeight: 360)
        tabs.addTabViewItem(validationTab)

        let jsonTab = NSTabViewItem(identifier: "json")
        jsonTab.label = "JSON"
        jsonView.isEditable = false
        jsonTab.view = textScroll(jsonView, minHeight: 360)
        tabs.addTabViewItem(jsonTab)

        let historyTab = NSTabViewItem(identifier: "history")
        historyTab.label = "Verlauf"
        historyTab.view = buildHistoryTab()
        tabs.addTabViewItem(historyTab)

        root.addArrangedSubview(tabs)
        tabs.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        tabs.heightAnchor.constraint(greaterThanOrEqualToConstant: 430).isActive = true
    }

'''

s = s[:idx] + func + s[idx:]
p.write_text(s, encoding='utf-8')
print('Applied V6.3 Technik workspace restore.')
