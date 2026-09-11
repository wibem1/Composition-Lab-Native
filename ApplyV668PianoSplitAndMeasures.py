from pathlib import Path

# --- MusicXML: piano grand-staff split -------------------------------------------------
p = Path('Sources/MusicXMLBuilder.swift')
s = p.read_text(encoding='utf-8')

old = '''    /// Zusammengesetzte Werte an Zählzeiten teilen und mit Haltebögen schreiben.\n    var splitAtBeatBoundaries: Bool = true\n'''
new = '''    /// Zusammengesetzte Werte an Zählzeiten teilen und mit Haltebögen schreiben.\n    var splitAtBeatBoundaries: Bool = true\n    /// Klavierdarstellung: "auto", "single" oder "two". Optional für alte Profile.\n    var pianoStaffMode: String? = "auto"\n    /// MIDI-Splitpunkt für Klavier-Zweiersystem. C4 = 60. Optional für alte Profile.\n    var pianoSplitPoint: Int? = 60\n'''
if old in s and 'var pianoStaffMode:' not in s:
    s = s.replace(old, new, 1)

raw_marker = '''        let rawNotes: [RawNote] = track.nt.compactMap { n in\n'''
insert = '''        // Klavier-MIDI liegt häufig vollständig in einer einzigen Spur/einem Staff.\n        // Für die Notation darf daraus automatisch ein Grand Staff entstehen, ohne MIDI\n        // oder internen Score zu verändern. Ein manueller Modus kann dies erzwingen/abschalten.\n        let trackNameLower = track.nm.lowercased()\n        let pianoLike = (0...7).contains(track.pg) || trackNameLower.contains("piano") || trackNameLower.contains("klavier")\n        let sourceStaffs = track.nt.compactMap { n -> Int? in n.count > 4 ? max(1, Int(n[4].rounded())) : 1 }\n        let sourceMaxStaff = max(1, sourceStaffs.max() ?? 1)\n        let sourcePitches = track.nt.compactMap { n -> Int? in n.count >= 3 ? max(0, min(127, Int(n[2].rounded()))) : nil }\n        let splitPoint = max(0, min(127, options.pianoSplitPoint ?? 60))\n        let pianoMode = options.pianoStaffMode ?? "auto"\n        let spansBothHands: Bool = {\n            guard let lo = sourcePitches.min(), let hi = sourcePitches.max() else { return false }\n            return lo <= splitPoint - 5 && hi >= splitPoint + 5\n        }()\n        let usePianoGrandStaff = sourceMaxStaff == 1 && pianoLike &&\n            (pianoMode == "two" || (pianoMode == "auto" && spansBothHands))\n\n        let rawNotes: [RawNote] = track.nt.compactMap { n in\n'''
if raw_marker in s and 'let usePianoGrandStaff' not in s:
    s = s.replace(raw_marker, insert, 1)

old_staff = '''                staff: n.count > 4 ? max(1, Int(n[4].rounded())) : 1,\n'''
new_staff = '''                staff: usePianoGrandStaff\n                    ? (max(0, min(127, Int(n[2].rounded()))) >= splitPoint ? 1 : 2)\n                    : (n.count > 4 ? max(1, Int(n[4].rounded())) : 1),\n'''
if old_staff in s and 'staff: usePianoGrandStaff' not in s:
    s = s.replace(old_staff, new_staff, 1)

p.write_text(s, encoding='utf-8')
print('V6.6.8: MusicXML piano grand-staff split added.')

# --- Main UI + notation controls + motif ------------------------------------------------
p = Path('Sources/MainViewController.swift')
s = p.read_text(encoding='utf-8')

# Editable combo box: preset values plus arbitrary typing.
s = s.replace('    private let measuresField = NSTextField(string: "")\n',
              '    private let measuresField = NSComboBox()\n', 1)

# Notation controls.
anchor = '    private let musicXMLSplitBeatsCheck = NSButton(checkboxWithTitle: "Zusammengesetzte Notenwerte an Zählzeiten teilen und binden", target: nil, action: nil)\n'
extra = anchor + '''    private let musicXMLPianoStaffPop = NSPopUpButton()\n    private let musicXMLPianoSplitPop = NSPopUpButton()\n'''
if anchor in s and 'musicXMLPianoStaffPop' not in s:
    s = s.replace(anchor, extra, 1)

# Configure Takte combo in approved V6.4 controls.
old = '        label("Takte"); field(measuresField, "24", 54); field(meterField, "4/4", 54); label("Tempo"); field(tempoField, "96", 58); label("Tonart"); field(musicalKeyField, "C-Dur", 86)\n'
new = '''        if measuresField.numberOfItems == 0 {\n            measuresField.addItems(withObjectValues: [2, 4, 8, 16, 24, 32, 48, 64].map(String.init))\n            measuresField.isEditable = true\n            measuresField.completes = false\n        }\n        label("Takte"); field(measuresField, "24", 62); field(meterField, "4/4", 54); label("Tempo"); field(tempoField, "96", 58); label("Tonart"); field(musicalKeyField, "C-Dur", 86)\n'''
if old in s:
    s = s.replace(old, new, 1)

# Populate new notation controls.
old = '''        musicXMLBarStartPop.removeAllItems()\n\n        musicXMLPresetPop.addItems(withTitles: ["Klavier – lesbar", "MIDI-nah", "Benutzerdefiniert"])\n'''
new = '''        musicXMLBarStartPop.removeAllItems()\n        musicXMLPianoStaffPop.removeAllItems()\n        musicXMLPianoSplitPop.removeAllItems()\n\n        musicXMLPresetPop.addItems(withTitles: ["Klavier – lesbar", "MIDI-nah", "Benutzerdefiniert"])\n'''
if old in s:
    s = s.replace(old, new, 1)

old = '''        musicXMLBarStartPop.addItems(withTitles: ["Aus", "bis 32tel", "bis 16tel", "bis Achtel"])\n\n        musicXMLPresetPop.target = self\n'''
new = '''        musicXMLBarStartPop.addItems(withTitles: ["Aus", "bis 32tel", "bis 16tel", "bis Achtel"])\n        musicXMLPianoStaffPop.addItems(withTitles: ["Automatisch", "Ein System", "Zwei Systeme"])\n        let splitNotes = ["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]\n        musicXMLPianoSplitPop.addItems(withTitles: splitNotes)\n\n        musicXMLPresetPop.target = self\n'''
if old in s:
    s = s.replace(old, new, 1)

old = '''        for pop in [musicXMLRhythmModePop, musicXMLStraightNotePop, musicXMLTripletNotePop, musicXMLRestPop, musicXMLSmoothingPop, musicXMLBarStartPop] {\n'''
new = '''        for pop in [musicXMLRhythmModePop, musicXMLStraightNotePop, musicXMLTripletNotePop, musicXMLRestPop, musicXMLSmoothingPop, musicXMLBarStartPop, musicXMLPianoStaffPop, musicXMLPianoSplitPop] {\n'''
if old in s:
    s = s.replace(old, new, 1)

old = '''        left.addArrangedSubview(label("Mini-Pausen am Taktanfang"))\n        left.addArrangedSubview(musicXMLBarStartPop)\n\n        left.addArrangedSubview(separatorBox())\n'''
new = '''        left.addArrangedSubview(label("Mini-Pausen am Taktanfang"))\n        left.addArrangedSubview(musicXMLBarStartPop)\n\n        left.addArrangedSubview(separatorBox())\n        left.addArrangedSubview(title("Klaviersystem"))\n        left.addArrangedSubview(label("Darstellung"))\n        left.addArrangedSubview(musicXMLPianoStaffPop)\n        left.addArrangedSubview(label("Splitpunkt"))\n        left.addArrangedSubview(musicXMLPianoSplitPop)\n\n        left.addArrangedSubview(separatorBox())\n'''
if old in s:
    s = s.replace(old, new, 1)

# Options from controls: map C4 to MIDI 60; UI uses scientific pitch notation.
old = '''            minimumTripletNoteValue: triplet,\n            barStartSnapThreshold: bs,\n            splitAtBeatBoundaries: musicXMLSplitBeatsCheck.state == .on\n        )\n'''
new = '''            minimumTripletNoteValue: triplet,\n            barStartSnapThreshold: bs,\n            splitAtBeatBoundaries: musicXMLSplitBeatsCheck.state == .on,\n            pianoStaffMode: ["auto", "single", "two"][max(0, min(musicXMLPianoStaffPop.indexOfSelectedItem, 2))],\n            pianoSplitPoint: [48,50,52,53,55,57,59,60,62,64,65,67,69,71,72][max(0, min(musicXMLPianoSplitPop.indexOfSelectedItem, 14))]\n        )\n'''
if old in s:
    s = s.replace(old, new, 1)

# Restore controls from profile.
old = '''        musicXMLSmoothingPop.selectItem(at: smoothingIndex)\n        musicXMLSplitBeatsCheck.state = o.splitAtBeatBoundaries ? .on : .off\n'''
new = '''        musicXMLSmoothingPop.selectItem(at: smoothingIndex)\n        musicXMLSplitBeatsCheck.state = o.splitAtBeatBoundaries ? .on : .off\n        switch o.pianoStaffMode ?? "auto" {\n        case "single": musicXMLPianoStaffPop.selectItem(at: 1)\n        case "two": musicXMLPianoStaffPop.selectItem(at: 2)\n        default: musicXMLPianoStaffPop.selectItem(at: 0)\n        }\n        let splitMIDIs = [48,50,52,53,55,57,59,60,62,64,65,67,69,71,72]\n        let targetSplit = o.pianoSplitPoint ?? 60\n        let splitIndex = splitMIDIs.indices.min(by: { abs(splitMIDIs[$0] - targetSplit) < abs(splitMIDIs[$1] - targetSplit) }) ?? 7\n        musicXMLPianoSplitPop.selectItem(at: splitIndex)\n'''
if old in s:
    s = s.replace(old, new, 1)

# Add piano setting to summary.
old = '''            "Taktanfang bis \\(o.barStartSnapThreshold) Beat · " +\n            (o.splitAtBeatBoundaries ? "Bindungen an Zählzeiten aktiv." : "keine automatische Zählzeitenteilung.")\n'''
new = '''            "Taktanfang bis \\(o.barStartSnapThreshold) Beat · " +\n            "Klavier \\((o.pianoStaffMode ?? "auto") == "two" ? "2 Systeme" : ((o.pianoStaffMode ?? "auto") == "single" ? "1 System" : "automatisch")), Split \\(o.pianoSplitPoint ?? 60) · " +\n            (o.splitAtBeatBoundaries ? "Bindungen an Zählzeiten aktiv." : "keine automatische Zählzeitenteilung.")\n'''
if old in s:
    s = s.replace(old, new, 1)

# Motif: all upper musical settings are inherited; only bar count is temporary.
# V6.6.3 prioritizes chatInput over the hidden legacy prompt, so set/restore both.
old = '''        let oldMeasures = measuresField.stringValue\n        let oldPrompt = promptView.string\n        measuresField.stringValue = String(bars)\n        promptView.string = "Komponiere ein prägnantes musikalisches Motiv als Ausgangspunkt für eine spätere Komposition."\n        composePressed()\n        measuresField.stringValue = oldMeasures\n        promptView.string = oldPrompt\n        saveSettingsFromUI()\n'''
new = '''        let oldMeasures = measuresField.stringValue\n        let oldPrompt = promptView.string\n        let oldChatInput = chatInput.stringValue\n        measuresField.stringValue = String(bars)\n        let motifTask = "Komponiere ein prägnantes musikalisches Motiv als Ausgangspunkt für eine spätere Komposition. Übernimm Tonart, Taktart, Tempo und Instrumentierung aus den eingestellten Feldern."\n        promptView.string = motifTask\n        chatInput.stringValue = motifTask\n        composePressed()\n        measuresField.stringValue = oldMeasures\n        promptView.string = oldPrompt\n        chatInput.stringValue = oldChatInput\n        saveSettingsFromUI()\n'''
if old in s:
    s = s.replace(old, new, 1)

required = [
    'private let measuresField = NSComboBox()',
    'private let musicXMLPianoStaffPop',
    'musicXMLPianoStaffPop.addItems',
    'pianoStaffMode:',
    'let oldChatInput = chatInput.stringValue'
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('V6.6.8 Main patch incomplete: ' + ', '.join(missing))

p.write_text(s, encoding='utf-8')
print('V6.6.8: editable measure presets, piano notation controls and motif inheritance added.')
