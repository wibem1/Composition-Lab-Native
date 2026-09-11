from pathlib import Path

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

start = s.find('    private func updatePieceSlotButtons() {\n')
end = s.find('    private func captureCurrentInActiveSlot() {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V6.3 card labels: updatePieceSlotButtons boundaries not found')

new = r'''    private func updatePieceSlotButtons() {
        for (i, b) in mainPieceSlotButtons.enumerated() where i < pieceSlots.count {
            if let item = pieceSlots[i] {
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let short = title.count > 20 ? String(title.prefix(19)) + "…" : title
                b.title = "Stück \(i + 1)\n\(short)"
                b.toolTip = "Stück \(i + 1): \(item.title)"
            } else {
                b.title = "Stück \(i + 1)\nleer"
                b.toolTip = "Stück \(i + 1): leer · Datei hierher ziehen"
            }
            b.state = i == activePieceSlot ? .on : .off
        }
        for (i, b) in notationPieceSlotButtons.enumerated() where i < pieceSlots.count {
            let filled = pieceSlots[i] != nil
            b.title = filled ? "●\(i + 1)" : "\(i + 1)"
            b.state = i == activePieceSlot ? .on : .off
            b.toolTip = pieceSlots[i].map { "Stück \(i + 1): \($0.title)" } ?? "Stück \(i + 1): leer"
        }
    }

'''

s = s[:start] + new + s[end:]
p.write_text(s, encoding='utf-8')
print('Applied V6.3 robust card labels.')
