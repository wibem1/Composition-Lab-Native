# Composition Lab Native

Native macOS-Fassung des gemeinsamen Kompositionssystems.

## Rolle

Dieses Repository ist die aktive Quellbasis für **Composition Lab Native**. Die App ergänzt Music Chat Lab und Minimal Composer um native macOS-Funktionen, Partiturdarstellung, MIDI-Ausgänge, MusicXML und DAW-Anbindungen.

Gemeinsame Grundlagen sind insbesondere Engine Build 14, CLAB, MIDI und MusicXML. `Composer-Lab` ist keine aktive Abhängigkeit mehr.

## Aktiver Stand

`main` ist der freigegebene aktive Quellstand:

- Composition Lab Native **V5.0.12**
- Build **84**
- Engine Build **14**

V5.0.12 basiert auf dem gesicherten Referenzstand V5.0.11 / Build 83 und enthält die konsolidierten Core-Korrekturen:

- MIDI-Import: reale importierte Notendauer mit `gate = 1.0`
- MusicXML-Import für zentrale `ev`-Ereignisse
- zweistaffige Staff-Zuordnung geprüft
- MusicXML-Tie-Import und Tie-Export
- dokumentierte Roundtrip-Tests

## Referenzstand

Der unveränderliche Ausgangsstand liegt im Branch `reference-v5.0.11`.

Der aktive `main` enthält den vollständigen Swift-Quellbaum direkt unter `Sources/`.

## Struktur

- `Sources/` — vollständiger aktiver Swift-Quellbaum
- `tests/` — reproduzierbare MusicXML-Testfixtures
- `*.md` — Core-Vertrag, Audits und Testergebnisse; sollen schrittweise unter `docs/` gebündelt werden
- `Info.plist` — Produktversion und macOS-Bundlekonfiguration
- `Build Native App.command` — baut die macOS-App direkt aus `Sources/`

## CLAB

Composition Lab Native bleibt die Referenz für das gemeinsame `.clab`-Projektdokument. Music Chat Lab liest und schreibt dasselbe Projektformat und soll unbekannte optionale Felder erhalten.

## Entwicklungsregel

Keine neue Funktion, solange eine Änderung nicht gegen den gemeinsamen Core-Vertrag geprüft wurde. Der Referenzbranch `reference-v5.0.11` bleibt unverändert.

Historische Hilfs- und Apply-Skripte im Repository werden nur entfernt, wenn ihre Änderungen nachweislich vollständig im aktuellen Quellstand enthalten sind und sie vom Build nicht mehr verwendet werden.
