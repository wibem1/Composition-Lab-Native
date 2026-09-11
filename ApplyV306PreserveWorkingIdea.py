from pathlib import Path

# Composition Lab Native 3.0.6
# A piece-slot click changes the loaded musical result (playback/notation), not
# the current editable working idea. Slot-stored concepts remain metadata of the
# pieces and must not overwrite the current MusicChat working state.

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

start = s.find('    @objc private func pieceSlotPressed(_ sender: NSButton) {\n')
end = s.find('    @objc private func generateMotifPressed() {\n', start)
if start < 0 or end < 0:
    raise SystemExit('V3.0.6: pieceSlotPressed block not found')

new = r'''    @objc private func pieceSlotPressed(_ sender: NSButton) {
        let newIndex = sender.tag
        guard newIndex >= 0, newIndex < pieceSlots.count else { return }

        // Composition Lab 3.x: the right-hand composition idea is one global,
        // user-editable working state. Merely browsing a piece slot must never
        // replace it with the historical concept stored in that slot.
        let preservedWorkingIdea = conceptView.string
        let preservedLastConcept = lastConcept
        let preservedAssignment = promptView.string
        let preservedSourceContext = musicChatCompositionContextOverride

        activePieceSlot = newIndex
        guard let item = pieceSlots[newIndex] else {
            updatePieceSlotButtons()
            status("Stück-Slot \(newIndex + 1) ist leer. Die nächste Komposition oder importierte Datei landet hier.", good: true)
            return
        }

        slotSelectionLoad = true
        install(score: item.score,
                concept: item.concept,
                provider: item.provider,
                model: item.model,
                addHistory: false,
                costUSD: item.costUSD,
                inputTokens: item.inputTokens,
                outputTokens: item.outputTokens)
        slotSelectionLoad = false

        // install() intentionally loads the piece metadata for legacy workflows.
        // Restore the independent 3.x working state immediately afterwards.
        conceptView.string = preservedWorkingIdea
        lastConcept = preservedLastConcept
        promptView.string = preservedAssignment
        musicChatCompositionContextOverride = preservedSourceContext

        updatePieceSlotButtons()
        scheduleMusicXMLPreviewRefresh()
        status("Stück \(newIndex + 1) geladen: \(item.title) · Kompositionsidee bleibt unverändert.", good: true)
    }

'''

s = s[:start] + new + s[end:]
s = s.replace('"interfaceVersion": "3.0.5"', '"interfaceVersion": "3.0.6"')
p.write_text(s, encoding='utf-8')
print('Applied V3.0.6: slot browsing no longer overwrites the editable working composition idea.')
