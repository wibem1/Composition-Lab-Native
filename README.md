# Composition Lab Native 4.0 – Mac / Windows

**Entwicklungszweig `v4-cross-platform` · 4.0.0-alpha.4 / Build 4004**

Die bisherige Version 3.5.3 bleibt auf `main` und unter
`reference-v3.5.3-before-v4` unverändert. Version 4.0 installiert sich getrennt.

Die erste grafische Windows-Alpha ist gebaut und automatisch gestartet/geprüft:
KI-Chat/Komposition, zehn Slots, CLAB-Dateien, MIDI/MusicXML, Diagnose und
DPAPI-Schlüsselablage. Der gemeinsame Swift-Kern wird von der Mac-App und der
Windows-Oberfläche verwendet. Runtime-DLLs und .NET sind im Windows-ZIP enthalten.

- Windows: [Start und Funktionen](Windows/README-Windows.md)
- Architektur: [V4-ARCHITECTURE.md](V4-ARCHITECTURE.md)
- Tests und Downloads: [GitHub Actions](https://github.com/wibem1/Composition-Lab-Native/actions/runs/38376535382)
- Tests lokal: `swift test`
- Mac-Test-App: `bash 'Build Native App.command'`
- Windows-Bundle: `pwsh Windows/Build.ps1` nach `swift build -c release`

Die Kerntests und Release-Builds bestehen auf Windows, Mac und Linux.
Der Windows-Starttest prüft außerdem Dateien, Schlüsselverschlüsselung und
Fenstergeometrie ohne installierte Swift-Toolchain im Suchpfad.
Hörbare Wiedergabe (Testrechner ohne MIDI-Gerät), ein echter KI-Aufruf und die
WebView2-/Verovio-Notenanzeige sind noch praktisch zu bestätigen.

Alpha 4 korrigiert die UTF-8-Kommunikation unter Windows und das Einlesen von
Ausdruckszeichen. Das gemeinsame technische Format ist jetzt ausdrücklich
beschrieben; ein Decoder übernimmt definierte ältere Alias-/Bereichsformen.
Die Komposition selbst wird bei der Normalisierung nicht verändert.

Windows verwendet Main / Noten / Technik, MusicChat und Komposition nebeneinander
sowie zehn Stück-Karten. API-Schlüssel und Diagnose stehen unter Technik.
Über Öffnen / Import kann eine Diagnose mit scoreResponse ohne KI-Neuanfrage
wiederhergestellt und als CLAB gespeichert werden. Elf Kerntests sowie Windows-
Starttests für Umlaute, Diagnose-Rettung und sichtbare Fenstergrenzen bestehen.

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
