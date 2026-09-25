# Composition Lab Native 3.5.2 – isolierte Motivfunktion
Stand: 2026-09-25. Entwicklungszweig: `release/v3.5.2-motif`.

**Status:** Build-Kandidat, nicht als funktionierend freigegeben, solange der macOS-CI-Build und ein praktischer Funktionstest nicht erfolgreich abgeschlossen sind.

## Ausgangsbasis
Der eigenständige 3.x-Zweig `v3.5-reference-engine13` (3.5.1, Build 3501) ist die Basis. Er verwendet freie musikalische Komposition und getrennte technische Übersetzung (Engine 1.3). Die installierte 3.3.1 des Nutzers wird nicht überschrieben.

## Gezielte Übernahme
Die isolierte Motiverzeugung aus `fix/experiment-motif-pipeline` wurde in `Sources/MainViewController.swift` übernommen und an die 3.5-API-Signatur und das dortige HistoryItem-Modell angepasst:
- ein separater KI-Aufruf nur für das Experimentallabor statt der normalen Kompositionspipeline;
- explizite 2/4/8-Takt-Motivaufgabe (je nach gewählter Taktzahl);
- Längenprüfung vor Übernahme des Ergebnisses;
- getrennte Ablage als Experiment, keine automatische Veränderung der Hauptkomposition;
- Diagnosedaten mit Auftrag, Prompt, Antwort, Modell und Taktzahl.

Die harte Längenprüfung verwirft derzeit überlange Motive statt sie zu reparieren; das ist eine bewusst dokumentierte Einschränkung.

## Build und Prüfung
`Build Native App.command` baut ohne historische Apply-Skriptkette. `.github/workflows/release-v352.yml` prüft Versionsmetadaten, kompiliert auf macOS und fordert ein Universal Binary für x86_64 und arm64. Erst ein grüner Lauf belegt den technischen Build; musikalische Funktion und Wiedergabe müssen anschließend praktisch geprüft werden.

**Wichtig:** Die 6er-Serie ist veraltet. `main` gehört noch zur alten Linie. Diesen Branch nicht blind nach `main` mergen, bevor die aktive 3er-Serie ausdrücklich als neue Hauptlinie festgelegt wurde.
