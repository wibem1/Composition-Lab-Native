# Composition Lab Native

Native macOS-Fassung des gemeinsamen Kompositionssystems.

## Rolle

Dieses Repository ist die aktive Quellbasis für **Composition Lab Native**. Die App ergänzt Music Chat Lab und Minimal Composer um native macOS-Funktionen, Partiturdarstellung, MIDI-Ausgänge, MusicXML und DAW-Anbindungen.

Gemeinsame Grundlagen sind insbesondere Engine Build 14, CLAB, MIDI und MusicXML. `Composer-Lab` ist keine aktive Abhängigkeit mehr.

## Aktiver Stand

`main` baut aktuell:

- Composition Lab Native **V6.0.0**
- Build **92**
- Engine Build **14**
- Architektur: **Composition Lab 2 · Main + Noten**

`Info.plist` und `Build Native App.command` stimmen auf V6.0.0 / Build 92 überein.

## Build-Architektur

Der 5.x-Quellstand dient weiterhin als stabile Basis. Beim Build werden reproduzierbar vier aktive Transformationsschritte angewendet:

- `ApplyWorkspaceLayoutFix.py`
- `ApplyCompositionLab2.py`
- `ApplyFullDragDrop.py`
- `ApplyFastScrollFix.py`

Diese Dateien sind **Bestandteil des aktuellen Build-Prozesses** und dürfen nicht als alte Patch-Reste gelöscht werden.

## Referenzstand

Der unveränderliche Ausgangsstand liegt im Branch `reference-v5.0.11`.

## Struktur

- `Sources/` — Swift-Quellbasis
- `tests/` — reproduzierbare MusicXML-Testfixtures
- `Apply*.py` — aktive, reproduzierbare V6-Transformationen
- `Info.plist` — V6.0.0 / Build 92
- `Build Native App.command` — baut die Universal-App für Intel und Apple Silicon
- technische Markdown-Dateien — Core-Vertrag, Audits und Testergebnisse

## CLAB

Composition Lab Native bleibt die Referenz für das gemeinsame `.clab`-Projektdokument. Music Chat Lab liest und schreibt dasselbe Projektformat und soll unbekannte optionale Felder erhalten.

## Entwicklungsregel

Der Referenzbranch `reference-v5.0.11` bleibt unverändert. Änderungen an MIDI-, MusicXML- oder CLAB-Semantik werden gegen den gemeinsamen Core geprüft. Build-Skripte werden erst entfernt, wenn ihre Transformationen vollständig in einen konsolidierten Quellbaum übernommen wurden.
