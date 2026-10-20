# Composition Lab Native – Entwicklung zu Version 4.2

Arbeitszweig: `v4-cross-platform`. **Version 4.2 ist noch nicht freigegeben.**
`main` und die bisherigen Referenzzweige bleiben unverändert.

Mac und Windows verwenden denselben Swift-Kern mit eigenständigen nativen
Oberflächen (AppKit bzw. WinForms). Gemeinsame Module übernehmen KI-Zugriff,
Modellkatalog, Formaterkennung, MIDI/MusicXML, portable Dokumente, LilyPond-
Quellprüfung und die Zuordnung von SVG-Noten zum Editor. Gemeinsame Dienste
regeln außerdem MusicChat, Labore, Oktavprüfung und Partiturrevisionen.

Der Hauptkompositionsweg bewahrt die Originalantwort. LilyPond wird lokal mit
mitgeliefertem 2.26.0 gesetzt; unbekannte Formate lösen keine ungefragte zweite
KI-Anfrage aus. Fehlerhafte Bearbeitungen erhalten die letzte gültige Fassung.
Mac und Windows verwenden dieselbe interaktive SVG-Vorlage. Die automatischen
REAPER-/Studio-Pro-Dateibrücken sind entfernt; normale Ein-/Ausgaben bleiben.

- [Aktueller Prüfstand und Freigabesperren](V4.2-AUDIT.md)
- [Modulverträge und Entwicklungsprotokoll](DEVELOPMENT-MODULES.md)
- [Builds und native Tests](https://github.com/wibem1/Composition-Lab-Native/actions)
- Kerntests: `swift test`
- Mac-Build: `bash 'Build Native App.command'` (Intel und Apple Silicon)
- Mac-Funktionstest: `COMPOSITION_LAB_TEST_DOMAIN=de.klangwerke.compositionlab.ci 'Composition Lab 4.2.app/Contents/MacOS/Composition Lab 4.2' --native-self-test /tmp/CompositionLab-Test`
- Windows-Bundle und GUI-Tests: `pwsh Windows/Build.ps1` nach `swift build -c release`

Die bisherigen Datenpfade und Bundle-IDs bleiben stabil. Pakete und Apps sind
eindeutig mit 4.2 bezeichnet. Ein grüner Build bedeutet bestandene automatische Prüfungen; noch offene
Funktionsunterschiede stehen im aktuellen Audit. Es gibt keinen 4.2-Release-Tag.

Die nachfolgende historische Dokumentation beschreibt 3.5.3 und frühere Stände.


---

# Composition Lab Native

> **CURRENT TEST CANDIDATE: V3.5.3 Build 3503** on `main`.
>
> Local Composition Engine **2.3.1 Build 231**. `main` is now the single current development line recorded in `Composition-Engine/PROJECT_INDEX.md`. The former 6.1.1 / Build 94 line is preserved as historical reference branch `reference-v6.1.1-build94`. Practical user acceptance of V3.5.3 is still pending, so this state is CURRENT TEST CANDIDATE, not SAFE.

Native macOS-Fassung des Music-Lab-Systems.

## Rolle im Music-Lab-System

Dieses Repository ist die aktive Quellbasis für **CompositionLab**. Die App gehört zusammen mit **ComposeLab** (`wibem1/Composer-Lab`) und **MusicChatLab** (`wibem1/Music-Chat-Lab`) zum gemeinsamen Music-Lab-System.

Gemeinsame Grundlagen sind Score-Schema, Engine Build 14, CLAB, MIDI und MusicXML. Anwendungsspezifisch sind hier native macOS-Funktionen, Partiturdarstellung, MIDI-Ausgänge und DAW-Anbindungen.

## Aktiver Stand

The historical text below documents earlier development states and is not the current runtime specification.

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

## Entwicklungsdokumentation und Modulverträge

Die fortlaufende Entwicklungsdokumentation einschließlich Modulverzeichnis, Aufgaben, Ein-/Ausgabeparametern, Architekturregeln, offenen Schwachstellen und Änderungsprotokoll steht in [DEVELOPMENT-MODULES.md](DEVELOPMENT-MODULES.md). Die tatsächliche Modularisierung ist noch nicht abgeschlossen; Zielmodule sind ausdrücklich als Planung gekennzeichnet.
