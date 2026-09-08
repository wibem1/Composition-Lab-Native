# Composition Lab Native

Native macOS-Fassung von Composition Lab.

## Rolle im Music-Lab-System

Dieses Repository ist die aktive Quellbasis für Composition Lab Native. Die App gehört zusammen mit Composition Lab WebApp (`wibem1/Composer-Lab`) und Music Chat Lab (`wibem1/Music-Chat-Lab`) zum gemeinsamen Music-Lab-System.

Gemeinsame Grundlagen sind Score-Schema, Engine Build 14, CLAB, MIDI und MusicXML. Anwendungsspezifisch sind hier native macOS-Funktionen, Partiturdarstellung, MIDI-Ausgänge und DAW-Anbindungen.

## Aktiver Entwicklungsstand

Branch: `native-core-alignment`

- Composition Lab Native **V5.0.12**
- Build **84**
- Engine Build **14**

V5.0.12 basiert auf dem unverändert gesicherten Referenzstand V5.0.11 / Build 83 und enthält ausschließlich die bisher konsolidierten Core-Korrekturen:

- MIDI-Import: importierte reale Notendauer mit `gate = 1.0`
- MusicXML-Import für zentrale `ev`-Ereignisse
- zweistaffige Staff-Zuordnung geprüft
- MusicXML-Tie-Import und Tie-Export
- dokumentierte Roundtrip-Tests

## Referenzstand

Der unveränderliche Ausgangsstand liegt ausschließlich im Branch `reference-v5.0.11`.

Der aktive Entwicklungsbranch enthält deshalb keine zweite Referenzkopie. Das verifizierte Source-ZIP `Composition_Lab_Native_V5_0_11_SOURCE.zip` bleibt nur als reproduzierbare Buildbasis erhalten; seine SHA-256 wird vor dem Entfalten geprüft.

## Struktur

- `Sources/` — bereits ausgerichtete/aktive Quelldateien
- `tests/` — reproduzierbare MusicXML-Testfixtures
- `*.md` — Core-Vertrag, Audits und Testergebnisse
- `Expand Native Source.command` — stellt den vollständigen 25-Dateien-Quellbaum aus dem verifizierten Source-ZIP her
- `Build Native App.command` — baut die macOS-App nach dem Entfalten

## CLAB

Composition Lab Native bleibt derzeit die Referenz für das gemeinsame `.clab`-Projektdokument. WebApp und Music Chat Lab sollen dasselbe Projektformat lesen und schreiben und unbekannte optionale Felder erhalten.

## Entwicklungsregel

Keine neue Funktion, solange eine Änderung nicht gegen den gemeinsamen Core-Vertrag geprüft wurde. Der Referenzbranch `reference-v5.0.11` bleibt unverändert.

Die systemweiten Regeln stehen in `wibem1/Composer-Lab` unter `SYSTEM-ARCHITECTURE.md`, `CORE-CONTRACT.md` und `DEVELOPMENT-RULES.md`.
