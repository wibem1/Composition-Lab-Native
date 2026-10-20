# Composition Lab Native 4.2

Gemeinsame musikalische Dienste mit eigenständiger AppKit-Oberfläche auf Mac
und nativer WinForms-Oberfläche auf Windows. Build 4200, 20.10.2026.

- Dynamische Provider-Modelle und gleiche MusicChat-/Laborverträge.
- Lokaler Original-LilyPond-Notensatz mit mitgeliefertem Compiler auf beiden Systemen.
- Interaktive Notenauswahl im Quelltext, sichere Übernahme und Wiederherstellung.
- Gemeinsame Oktavprüfung und ausdrückliche, streng validierte Korrektur.
- Partitur-Undo/Redo, geschützte Originale und portable Projektmetadaten.
- MIDI-Ausgangswahl, Lautstärke/Tempo als Wiedergabekopie mit erhaltener Tempokarte.
- Kompatible verschlüsselte Backups; DAW-Dateibrücken entfernt.

Vorhandene Datenverzeichnisse und Bundle-IDs bleiben erhalten. `main` und die
Referenzzweige werden nicht verändert. Pakete heißen `Composition-Lab-4.2-Mac.zip`
und `Composition-Lab-4.2-Windows-x64.zip`; die Mac-App ist universal.

Installation: Auf Mac das ZIP entpacken und die App in Programme ablegen.
Auf Windows das gesamte ZIP entpacken und `Composition Lab 4.2.exe` starten.
Die Pakete enthalten LilyPond und die benötigten Laufzeitdateien.

Die Veröffentlichung ist an den erfolgreichen vollständigen Testlauf gekoppelt.
CI hat keine externen MIDI-Geräte und keinen Windows-Synthesizer; konkreter
Hardwareklang muss auf dem Zielrechner geprüft werden. Die Mac-App ist ad hoc
signiert, nicht von Apple notarisiert.
Prüfung, Datenflüsse und praktische Grenzen stehen in `V4.2-AUDIT.md`.
