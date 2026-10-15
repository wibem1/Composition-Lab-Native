# Composition Lab Native · Windows · Alpha 16 · Build 4016 · 15.10.2026

Das gesamte ZIP in einen neuen Ordner entpacken und `Composition Lab 4.0.exe`
starten. Die Unterordner `Core`, `LilyPond` und `Notices` beibehalten. .NET,
Swift und LilyPond müssen nicht zusätzlich installiert werden. Voraussetzung:
Windows 10/11 auf Intel/AMD 64 Bit und Microsoft Edge WebView2 Runtime.

## MIDI und Originalnoten

Fertiger LilyPond-Code wird mit dem mitgelieferten LilyPond 2.26.0 lokal in
MIDI und Notenseiten (SVG) umgesetzt. Dafür ist keine zweite KI-Anfrage nötig.
Auftakt, Takte, Stimmen, Tonhöhen und Artikulation stammen aus dem Original.
Notenvorschau, Blättern, Zoom und Drucken funktionieren für diese Ausgabe ohne
Internet. Bereits erzeugte Dateien werden beim erneuten Öffnen wiederverwendet.
Die Diagnose nennt Compiler, Laufzeit, Seitenzahl, Warnungen und KI-Aufrufzahl.

Bereits gespeicherte Stücke behalten ihre bisherige Wiedergabe. Die frühere
KI-Übertragung konnte Tonhöhen anders deuten als der LilyPond-Compiler. Eine
Originalausgabe erzeugt deshalb eine zusätzliche Fassung in einem freien Slot:

1. Das gewünschte Stück auswählen.
2. Im Menü **Komposition → LilyPond-Original in freien Slot ausgeben** wählen.
3. Die bisherige Fassung bleibt daneben erhalten.

Alternativ kann eine Diagnose mit vollständigem LilyPond-Original in einen
freien Slot geladen werden. Die lokale Ausgabe braucht keinen API-Schlüssel.
Fehlerhafter LilyPond-Code wird mit einer Meldung abgewiesen; eine zusätzliche
KI-Übersetzung wird dabei nicht stillschweigend gestartet. Externe Includes und
beliebiger ausführbarer Scheme-Code werden nicht zugelassen. Für andere
vollständige Notationsformate bleibt der bisherige KI-Übersetzungsweg verfügbar.

MIDI sichern exportiert bei einer direkten Ausgabe die originale MIDI-Datei.
LilyPond sichern erhält die ursprüngliche Notation. MusicXML ist weiterhin eine
vereinfachte Austauschansicht aus der internen Partitur; es enthält nicht alle
Informationen des LilyPond-Originals. MusicXML- und MIDI-Importe verwenden die
bestehende Verovio-Anzeige; dafür wird Verovio über das Internet geladen. Die
Darstellungsquantisierung betrifft diesen MusicXML-Weg, nicht Originalnoten.

## Bedienung und Modellwahl

Main, Noten und Technik folgen dem Aufbau der Mac-Oberfläche. Zehn Stückplätze,
MusicChat, editierbare Stückbeschreibungen, Player, Verlauf, MIDI-/CLAB-Import
und Export bleiben verfügbar. Beim Tabwechsel wird der vorige Ausschnitt
wiederhergestellt. Die Trennlinie zwischen MusicChat und Kompositionsidee lässt
sich verschieben. Längere Aufträge haben Zeilenumbruch; Strg+Enter sendet sie.

Unter **Modelle …** lassen sich vollständige Providerlisten durchsuchen,
aktualisieren und auswählen. Vorhandene Schlüssel werden automatisch benutzt.
Übernehmen schließt den Schlüsseldialog und lädt die Modelle; Fortschritt und
Fehler erscheinen im Auswahlfenster. Sitzungsschlüssel bleiben beim Wechsel
des Providers erhalten. Die letzte vollständige Liste bleibt offline verfügbar.
Nicht jedes vom Provider gelistete Spezialmodell unterstützt Komposition.

## Speichern und Diagnose

Einstellungen und Stücke liegen unter
`%LOCALAPPDATA%/Klangwerke/Composition Lab 4.0`. Gespeicherte API-Schlüssel sind
separat mit Windows-DPAPI verschlüsselt und gehören zum Windows-Benutzerkonto.
Sie stehen nicht in Projekt-, Stück- oder Diagnosedateien. Ohne Speichern gilt
ein eingegebener Schlüssel bis zum Beenden der App.

Stücke lassen sich als CLAB und Arbeitsplätze als CLABPROJECT speichern. Diese
Dateien enthalten bei direkten Ausgaben auch das Original-MIDI. Für eine
Fehlermeldung kann unter **Technisches → Diagnosedatei sichern …** eine Diagnose
mit Auftrag, Modell, Musikquelle, Kosten und technischen Ergebnissen gespeichert
werden. Automatische Tests verwenden keine echten API-Schlüssel und erzeugen
keine kostenpflichtigen KI-Anfragen.

Die vollständige Mac-MusicChat-Aktionssteuerung, verschlüsselte Mac-Backups
und Soundfont-/direkte MIDI-Ausgangswahl sind noch nicht vollständig portiert.
Hörbarer Klang und Druckerausgabe hängen vom jeweiligen Windows-System ab.
Der gemeinsame Kern bleibt für das bestehende Dateiformat auf Alpha 12. Die
Mac-Version auf `main` wird durch diesen Windows-Build nicht verändert.

## Mitgelieferte Programme

LilyPond 2.26.0 wird unverändert als separates Programm mitgeliefert. Seine
Lizenzen und die Lizenzen der Abhängigkeiten stehen unter `LilyPond/licenses`.
Weitere Lizenzhinweise stehen unter `Notices` und in der beiliegenden GPL.
Unverändertes Originalpaket, zugehörige Quellen und Bauanleitungen:

- https://gitlab.com/lilypond/lilypond/-/releases/v2.26.0
- https://lilypond.org/source.html
- https://gitlab.com/lilypond/lilypond/-/tree/v2.26.0/release/binaries
