import Cocoa

@MainActor
final class HistoryFooterView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private var items: [HistoryItem] = []
    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let buttons: [NSButton]
    var onAction: ((Int, HistoryItem) -> Void)?
    var onDelete: ((HistoryItem) -> Void)?

    init(buttonTitles: [String]) {
        self.buttons = buttonTitles.enumerated().map { index, title in
            let b = NSButton(title: title, target: nil, action: nil)
            b.tag = index
            b.bezelStyle = .rounded
            return b
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let heading = NSTextField(labelWithString: "Verlauf")
        heading.font = .systemFont(ofSize: 14, weight: .bold)
        stack.addArrangedSubview(heading)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.title = "Titel"
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 22
        table.intercellSpacing = NSSize(width: 0, height: 1)
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(doubleClicked)

        let contextMenu = NSMenu()
        let deleteItem = NSMenuItem(title: "Löschen", action: #selector(deleteFromContextMenu), keyEquivalent: "")
        deleteItem.target = self
        contextMenu.addItem(deleteItem)
        table.menu = contextMenu

        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 92).isActive = true
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        for button in buttons {
            button.target = self
            button.action = #selector(actionPressed(_:))
            row.addArrangedSubview(button)
        }
        stack.addArrangedSubview(row)
    }

    func setItems(_ newItems: [HistoryItem]) {
        items = newItems
        table.reloadData()
        if table.selectedRow >= items.count { table.deselectAll(nil) }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < items.count else { return nil }
        let id = NSUserInterfaceItemIdentifier("historyTitleCell")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField) ?? {
            let f = NSTextField(labelWithString: "")
            f.identifier = id
            f.lineBreakMode = .byTruncatingTail
            return f
        }()
        field.stringValue = items[row].title
        field.toolTip = items[row].title
        return field
    }

    private func selectedItem() -> HistoryItem? {
        let r = table.selectedRow
        guard r >= 0 && r < items.count else { return nil }
        return items[r]
    }

    @objc private func actionPressed(_ sender: NSButton) {
        guard let item = selectedItem() else { return }
        onAction?(sender.tag, item)
    }

    @objc private func doubleClicked() {
        guard let item = selectedItem() else { return }
        onAction?(0, item)
    }

    @objc private func deleteFromContextMenu() {
        let r = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard r >= 0 && r < items.count else { return }
        onDelete?(items[r])
    }
}
