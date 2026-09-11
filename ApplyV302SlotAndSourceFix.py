from pathlib import Path

# Composition Lab Native 3.0.2
# Two architecture fixes:
# 1) A new score is bound to the selected empty slot or, if the active slot is
#    occupied, to the first free slot. V3.0 replaced composePressed after the old
#    V6 slot patch, accidentally dropping this binding and therefore repeatedly
#    writing to slot 1.
# 2) basePrompt must not automatically inject importedReferenceScore. In the
#    MusicChat architecture, musical sources are chosen explicitly from context
#    and arrive through musicChatCompositionContextOverride.

p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# ---------------------------------------------------------------------------
# 1) Remove unconditional legacy imported-reference injection from basePrompt.
# ---------------------------------------------------------------------------
old = '''        if let imported=importedReferenceScore,\n           let data=try? JSONEncoder().encode(imported),\n           let json=String(data:data,encoding:.utf8) {\n            result += "\\n\\nVORHANDENES MATERIAL (\\(imported.ti)):\\n\\(json)"\n        }\n'''
if old in s:
    s = s.replace(old, '', 1)

# musicChatCompositionContextOverride remains the only explicit source channel.
if 'MUSICCHAT-ARBEITSMATERIAL:' not in s:
    raise SystemExit('V3.0.2: explicit MusicChat source material hook missing')

# ---------------------------------------------------------------------------
# 2) Bind the score request to a destination slot before asynchronous generation.
#    Idea-only generation must not consume a slot.
# ---------------------------------------------------------------------------
anchor = '''        // An idea exists: use EXACTLY the currently visible editable text.\n        let finalIdea = visibleIdea\n        lastConcept = finalIdea\n'''
replacement = '''        // An idea exists: use EXACTLY the currently visible editable text.\n        // Bind this asynchronous score request to a concrete destination slot.\n        // An explicitly selected empty slot wins; otherwise use the first free slot.\n        let destinationSlot: Int\n        if activePieceSlot >= 0, activePieceSlot < pieceSlots.count, pieceSlots[activePieceSlot] == nil {\n            destinationSlot = activePieceSlot\n        } else if let freeSlot = pieceSlots.firstIndex(where: { $0 == nil }) {\n            destinationSlot = freeSlot\n        } else {\n            status("Alle 10 Stück-Slots sind belegt. Bitte zuerst einen Slot löschen.", good: false)\n            return\n        }\n        pendingCompositionSlot = destinationSlot\n\n        let finalIdea = visibleIdea\n        lastConcept = finalIdea\n'''
if anchor not in s:
    raise SystemExit('V3.0.2: score-generation destination anchor not found')
s = s.replace(anchor, replacement, 1)

# Add destination to diagnostics so future slot bugs are directly visible.
diag_anchor = '''            "stage": "score-request",\n            "assignment": assignment,\n            "finalEditedCompositionIdea": finalIdea,\n'''
diag_replacement = '''            "stage": "score-request",\n            "destinationSlot": destinationSlot + 1,\n            "assignment": assignment,\n            "finalEditedCompositionIdea": finalIdea,\n'''
if diag_anchor not in s:
    raise SystemExit('V3.0.2: diagnostic score-request anchor not found')
s = s.replace(diag_anchor, diag_replacement, 1)

# If the score request fails or decoding fails, release the reservation. This is
# not strictly necessary for correctness but avoids a stale target surviving a
# failed asynchronous request.
s = s.replace('''                    if var d = self?.lastDiagnostic {\n                        d["stage"] = "score-failed"\n''', '''                    self?.pendingCompositionSlot = nil\n                    if var d = self?.lastDiagnostic {\n                        d["stage"] = "score-failed"\n''', 1)
s = s.replace('''                        if var d = self?.lastDiagnostic {\n                            d["stage"] = "decode-failed"\n''', '''                        self?.pendingCompositionSlot = nil\n                        if var d = self?.lastDiagnostic {\n                            d["stage"] = "decode-failed"\n''', 1)

# Version diagnostic payloads from the V3 core/corrections.
s = s.replace('"interfaceVersion": "3.0.1"', '"interfaceVersion": "3.0.2"')
s = s.replace('"interfaceVersion": "3.0.0"', '"interfaceVersion": "3.0.2"')

p.write_text(s, encoding='utf-8')
print('Applied Composition Lab Native 3.0.2: deterministic next-free slot targeting and explicit-only source material.')
