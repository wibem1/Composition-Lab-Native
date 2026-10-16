# Composition Lab Native 4.0 – Mac / Windows

**Entwicklungszweig `v4-cross-platform` · 4.0.0-alpha.12 / Build 4012**

Die bisherige Version 3.5.3 bleibt auf `main` und unter
`reference-v3.5.3-before-v4` unverändert. Version 4.0 installiert sich getrennt.

Die erste grafische Windows-Alpha ist gebaut und automatisch gestartet/geprüft:
KI-Chat/Komposition, zehn Slots, CLAB-Dateien, MIDI/MusicXML, Diagnose und
DPAPI-Schlüsselablage. Der gemeinsame Swift-Kern wird von der Mac-App und der
Windows-Oberfläche verwendet. Runtime-DLLs und .NET sind im Windows-ZIP enthalten.

- Windows: [Start und Funktionen](Windows/README-Windows.md)
- Architektur: [V4-ARCHITECTURE.md](V4-ARCHITECTURE.md)
- Tests und Downloads: [GitHub Actions](https://github.com/wibem1/Composition-Lab-Native/actions/runs/38592958286)
- Tests lokal: `swift test`
- Mac-Test-App: `bash 'Build Native App.command'`
- Windows-Bundle: `pwsh Windows/Build.ps1` nach `swift build -c release`

Die Kerntests und Release-Builds bestehen auf Windows, Mac und Linux.
Der Windows-Starttest prüft außerdem Dateien, Schlüsselverschlüsselung und
Fenstergeometrie ohne installierte Swift-Toolchain im Suchpfad.
Hörbare Wiedergabe (Testrechner ohne MIDI-Gerät), ein echter KI-Aufruf und die
Verovio-Notensatz mit realen Stücken sind noch praktisch zu bestätigen. Die native WebView2-Vorschau wird seit Alpha 12 auch mit einer offline geladenen Testseite auf Scroll- und Tab-Stabilität geprüft.

Alpha 3 korrigiert die UTF-8-Kommunikation unter Windows und das Einlesen von
Ausdruckszeichen. Das gemeinsame technische Format ist jetzt ausdrücklich
beschrieben; ein Decoder übernimmt definierte ältere Alias-/Bereichsformen.
Die Komposition selbst wird bei der Normalisierung nicht verändert.

Windows verwendet Main / Noten / Technik, MusicChat und Komposition nebeneinander
sowie zehn Stück-Karten. API-Schlüssel und Diagnose stehen unter Technik.
Über Öffnen / Import kann eine Diagnose mit scoreResponse ohne KI-Neuanfrage
wiederhergestellt und als CLAB gespeichert werden. Elf Kerntests sowie Windows-
Starttests für Umlaute, Diagnose-Rettung und sichtbare Fenstergrenzen bestehen.

Alpha 4 ergänzt gezieltes Laden, Dateidrop und einzelnes Löschen je Stück-Karte.
Ein fehlgeschlagener Import erhält das bisherige Stück. Die kompaktere Oberfläche
verwendet ein Dateimenü. LilyPond-Quelltext lässt sich als `.ly` exportieren und
per Zwischenablage an Hacklily übergeben, ohne neue KI-Anfrage.

Alpha 5 (13.10.2026) ersetzt die provisorische Windows-Oberfläche durch eine
Werkstatt mit Stück-Bibliothek, gerundeten Flächen, klarer Typografie und Petrol-
Akzent. `StudioTheme.cs` kapselt die Windows-Darstellung. Der gemeinsame Kern
und die kompatible Arbeitsablage bleiben erhalten. Alle drei Arbeitsbereiche
bestehen die Fensterprüfungen bei kleiner und großer angeforderter Fenstergröße;
der Windows-Testrechner begrenzt die große Größe auf seine Bildschirmauflösung.

Alpha 6 übernimmt die Mac-GUI aus `main` in die Windows-Adapter. Die Referenz
ist unter [MAC-GUI-REFERENCE.md](Shared/Interface/MAC-GUI-REFERENCE.md) dokumentiert.
Reale Mac-Bilder und Windows-Starttests gehören zum Abgleich. Dreizehn Kerntests
prüfen unter anderem die gemeinsamen Notationsoptionen und das Mac-Projektformat.
Die plattformspezifischen Funktionsgrenzen stehen in der Windows-Anleitung.

Alpha 7 korrigiert die Windows-DPI-Initialisierung, skaliert Scrollflächen mit dem Monitor und verhindert überdeckte Titel sowie zu flache Textzeilen. Alpha 8 passt die Hauptseite an die sichtbare Fensterbreite an und ergänzt eine verschiebbare, gespeicherte Trennlinie zwischen MusicChat und Kompositionsidee. Parameter und Aktionen brechen bei schmalen Fenstern um. Die Windows-Prüfung kontrolliert Schriftmetriken, Geometrie und die verstellbaren Bereiche bei simulierten 100, 125, 150 und 200 Prozent.

Alpha 9 stabilisiert Tabwechsel und Fokuswiederherstellung, fasst Layoutänderungen zusammen und speichert die Aufteilung nur nach einer tatsächlichen Bewegung der Trennlinie. Die Windows-Prüfung besteht 144 wiederholte Tabwechsel bei vier simulierten Skalierungen und zwei Fenstergrößen ohne verschwundene Hauptbedienelemente oder verschobene Parameterpositionen.

Alpha 10 übernimmt fertige LilyPond-Kompositionen aus dem Windows-Chat über eine einzelne technische Übersetzung in einen freien aktiven Slot mit MIDI. Frühere Chat-Antworten lassen sich aus der Diagnose oder über das Kompositionsmenü übernehmen. Der ursprüngliche Quelltext und die bisherigen Kosten bleiben erhalten. Karten und Slot-Leiste sind kleiner. Fünfzehn Kerntests und die Windows-Integration bestehen.

Alpha 11 verteilt die zehn Windows-Slots auf die sichtbare Breite ohne eigene Scrollbalken und korrigiert die MusicXML-Schlüssel der Solo-Streicher. Vorhandene Tonhöhen und MIDI-Daten bleiben erhalten. Sechzehn Kerntests und die Windows-Prüfung der vollständigen Slot-Leiste bei allen getesteten Skalierungen und Fenstergrößen bestehen.

Alpha 12 vergrößert das mehrzeilige Auftragsfeld mit automatischem Zeilenumbruch. Enter fügt eine neue Zeile ein, Strg+Enter sendet. Die Notenvorschau passt direkt in die Fensterfläche ohne zusätzlichen äußeren Scrollbereich; Große Ansicht blendet Zusatzbereiche aus, ohne den Browser umzuhängen. Kurze Fenster sparen Platz bei der doppelten Slot-/Player-Leiste, die Notenoptionen bleiben erreichbar. Native Unterfenster werden nach Scrollen und Tabwechsel neu gezeichnet. Die Windows-Prüfung umfasst außerdem 36 Tabwechsel mit einer echten WebView2-Testseite und 144 Wechsel bei vier simulierten DPI-Skalierungen.

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
