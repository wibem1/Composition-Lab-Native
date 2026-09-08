# CompositionLab

Native macOS-Fassung des Music-Lab-Systems.

## Rolle im Music-Lab-System

Dieses Repository ist die aktive Quellbasis für **CompositionLab**. Die App gehört zusammen mit **ComposeLab** (`wibem1/Composer-Lab`) und **MusicChatLab** (`wibem1/Music-Chat-Lab`) zum gemeinsamen Music-Lab-System.

Gemeinsame Grundlagen sind Score-Schema, Engine Build 14, CLAB, MIDI und MusicXML. Anwendungsspezifisch sind hier native macOS-Funktionen, Partiturdarstellung, MIDI-Ausgänge und DAW-Anbindungen.

## Aktiver Stand

`main` ist der freigegebene aktive Quellstand:

- CompositionLab **V5.0.12**
- Build **84**
- Engine Build **14**

V5.0.12 basiert auf dem unverändert gesicherten Referenzstand V5.0.11 / Build 83 und enthält die konsolidierten Core-Korrekturen:

- MIDI-Import: reale importierte Notendauer mit `gate = 1.0`
- MusicXML-Import für zentrale `ev`-Ereignisse
- zweistaffige Staff-Zuordnung geprüft
- MusicXML-Tie-Import und Tie-Export
- dokumentierte Roundtrip-Tests

## Referenzstand

Der unveränderliche Ausgangsstand liegt im Branch `reference-v5.0.11`.

Der aktive `main` enthält **keine Referenz-ZIP, keine Entfaltungslogik und keinen zweiten Quellbaum**. Alle 25 Swift-Dateien liegen direkt und normal versioniert unter `Sources/`.

## Struktur

- `Sources/` — vollständiger aktiver Swift-Quellbaum
- `tests/` — reproduzierbare MusicXML-Testfixtures
- `*.md` — Core-Vertrag, Audits und Testergebnisse
- `Info.plist` — Produktversion und macOS-Bundlekonfiguration
- `Build Native App.command` — baut die macOS-App direkt aus `Sources/`

## CLAB

CompositionLab bleibt die Referenz für das gemeinsame `.clab`-Projektdokument. ComposeLab und MusicChatLab lesen und schreiben dasselbe Projektformat und erhalten unbekannte optionale Felder.

## Entwicklungsregel

Keine neue Funktion, solange eine Änderung nicht gegen den gemeinsamen Core-Vertrag geprüft wurde. Der Referenzbranch `reference-v5.0.11` bleibt unverändert.

Die systemweiten Regeln stehen in `wibem1/Composer-Lab` unter `SYSTEM-ARCHITECTURE.md`, `CORE-CONTRACT.md` und `DEVELOPMENT-RULES.md`.
