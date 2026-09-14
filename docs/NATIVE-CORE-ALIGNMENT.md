# Native Core Alignment

Stand: 8. September 2026

Branch: `native-core-alignment`
Basis: `reference-v5.0.11`
Referenz: Composition Lab Native V5.0.11 / Build 83 / Engine Build 14

## MIDI-Import-Gatekorrektur

In `Sources/MIDIParser.swift` wurde ausschließlich die Gate-Semantik für bereits vorhandene MIDI-Dateien korrigiert.

Vorher:

```swift
[st, dur, pitch, velocity, 0, 0.95]
```

Nachher:

```swift
[st, dur, pitch, velocity, 0, 1.0]
```

### Begründung

Beim MIDI-Import ist `dur` bereits die reale Zeitdifferenz zwischen Note-On und Note-Off. Ein zusätzliches Gate von `0.95` würde diese reale Klingdauer bei einem späteren MIDI-Export nochmals um 5 % verkürzen.

Daher gilt für importierte MIDI-Noten:

- `d` = reale importierte Note-On→Note-Off-Dauer
- `g` = `1.0`

### Nicht geändert

Andere `0.95`-Vorkommen wurden bewusst nicht angefasst. Sie betreffen andere Semantiken, darunter:

- Standard-Gate für neu erzeugte Scores ohne explizites Gate
- MusicXML-Import/Export
- DAW-Bridge-Erzeugung
- Playback-/Output-Fallbacks
- UI-Farbalpha

Diese Bereiche werden separat geprüft und nicht pauschal vereinheitlicht.

## Status

- Referenzbranch `reference-v5.0.11` unverändert
- Änderung nur im Branch `native-core-alignment`
- kein Engine-14-Prompt geändert
- keine UI-Änderung
- keine CLAB-Änderung
