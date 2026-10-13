# Composition Lab Native 4.0 – Mac / Windows

**Entwicklungszweig `v4-cross-platform` · 4.0.0-alpha.1 / Build 4001**

Die bisherige Version 3.5.3 bleibt auf `main` und unter
`reference-v3.5.3-before-v4` unverändert erhalten. Diese Alpha ersetzt sie nicht.

Gemeinsamer Swift-Kern für Mac und Windows: MIDI, MusicXML, Datenmodell,
Projektformate, KI-Kommunikation und zweistufiger Kompositionsablauf.
Die Mac-Test-App verwendet denselben Kern und hat eine eigene App-Kennung sowie
getrennte Einstellungen und Schlüsselablage. Die grafische Windows-App ist noch
nicht umgesetzt; vorerst gibt es den Kern und ein Konvertierungs-/Prüfprogramm.

- Architektur und Grenzen: [V4-ARCHITECTURE.md](V4-ARCHITECTURE.md)
- Tests: `swift test`
- Kern/CLI: `swift build -c release`
- Mac-Test-App: `bash 'Build Native App.command'`
- Version: `swift run composition-lab-core --version`
- Plattformprüfung: `.github/workflows/v4-core.yml`

Die nachfolgende historische Dokumentation beschreibt 3.5.3 und frühere Stände.
Sie ist keine Spezifikation der Windows-Oberfläche.

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
