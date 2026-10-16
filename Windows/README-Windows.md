# Composition Lab Native · Windows · V4.1 · 16.10.2026

Das gesamte ZIP in einen neuen Ordner entpacken und `Composition Lab 4.0.exe`
starten. Die Unterordner `Core`, `LilyPond` und `Notices` beibehalten. .NET,
Swift und LilyPond müssen nicht zusätzlich installiert werden. Voraussetzung:
Windows 10/11 auf Intel/AMD 64 Bit und Microsoft Edge WebView2 Runtime.

## V4.1 – konsolidierte Oberfläche

Die Windows-Version trägt ab sofort die lesbare Versionsnummer **V4.1** statt
einer fortlaufenden Alpha-/Build-Kombination. Der gemeinsame Entwicklungszweig
ist `v4-cross-platform`. Der Menüpunkt **Hilfe → Entwicklungsstand /
Über Composition Lab** nennt geprüfte Funktionen, bekannte Grenzen und den
Entwicklungszweig. Die Hauptmenüs sind jetzt Datei, Bearbeiten, Komposition,
Einstellungen und Hilfe.

Redundante Diagnose-Menüs und nicht verfügbare Mac-Backup-Befehle wurden aus
der Menüleiste entfernt. Projekt öffnen ist weiterhin bewusst vom
**Datei → Diagnose importieren** getrennt, damit JSON-Diagnosen nicht mit
Arbeitsplatzdateien verwechselt werden.

**Wichtig:** Um vorhandene Nutzerdateien nicht zu gefährden, bleiben der
bisherige Installationsordnername, die Windows-EXE und das lokale Datenverzeichnis
vorläufig gleich. Die Umbenennung ändert das interne Projektformat nicht.
Weitere Vereinfachungen der Verarbeitung müssen einzeln gegen die Windows-
Selbsttests und reale Diagnosefälle geprüft werden; dies ist keine Behauptung
einer abgeschlossenen Kern-Refaktorierung.

## Automatische Oktavprüfung

Neue LilyPond-Kompositionen und **Aktualisieren** prüfen die tatsächlichen
MIDI-Tonhöhen. Klaviertöne außerhalb A0–C8 sowie anhaltend extreme Höhen nach
zentralem Beginn in relativer Notation lösen höchstens einen KI-Korrekturversuch
aus. Unauffällige Stücke benötigen keine weitere Anfrage. Der Korrekturversuch
nutzt den Provider und das Modell der Komposition; dessen Schlüssel muss
verfügbar sein. Zusätzliche Tokens und Kosten erscheinen in der Diagnose.

Die Korrektur wird lokal erneut kompiliert und nur übernommen, wenn alle
Tonklassen, Einsätze, Dauern, Dynamikwerte, Stimmen, Instrumente, Tonart,
Taktart und das Grundtempo erhalten bleiben und die Prüfung danach besteht.
Scheitert die automatische Korrektur, bleibt das vollständige Original als
Notation und MIDI verfügbar. **Oktavprüfung offen** bleibt dann im Main- und
Noten-Tab sichtbar. Eine ausdrücklich verlangte Korrektur ersetzt die vorhandene
Fassung nur nach erfolgreicher Prüfung. Original, Befund und Korrekturantwort
stehen in der Diagnose. Fertige Antworten werden bereits vor der Verarbeitung
gesichert und lassen sich über **Komposition → Fertige Komposition übernehmen**
wiederherstellen. **Datei → Diagnose-JSON importieren …** lädt Diagnosedateien.

Für bereits gespeicherte Stücke: **Komposition → Oktavlagen prüfen und
korrigieren**. **Oktavlagen automatisch prüfen** ist standardmäßig eingeschaltet
und für bewusst extreme Kompositionen abschaltbar. Die Prüfung erkennt keine
beliebigen musikalischen Fehler und beurteilt bisher nur Klavierstimmen.
Neue Anfragen erhalten zusätzlich einen Hinweis auf absolute Oktavangaben,
um schleichende Fehler durch durchlaufendes `\relative` zu vermeiden.

## LilyPond bearbeiten und aktualisieren

Den LilyPond-Code im Textfeld der geladenen Komposition bearbeiten und im
Noten-Tab **Aktualisieren** drücken. Die App kompiliert den aktuellen Editorinhalt
und übernimmt Notation, MIDI, Titel und interne Partitur gemeinsam in dasselbe
Stück. Dafür wird keine KI angefragt. Erfolgreiche Änderungen bleiben beim
Wechseln der Slots, in CLAB-Dateien und in Projektdateien erhalten. LilyPond-Export
und Hacklily-Übergabe verwenden den aktuellen Quelltext.
Hacklily erhält den Code direkt über seinen URL-Import; manuelles Einfügen ist
nicht mehr nötig. Auch lange Kompositionen werden über eine lokale Startdatei
vollständig übergeben. Hacklily behandelt URL-Importe als schreibgeschützt;
zum Bearbeiten dort eine Kopie speichern. Die direkte Website-Übernahme konnte
hier mangels Browserfreigabe nicht live geprüft werden.

Speichern: **Datei → LilyPond sichern …** und **Datei → MusicXML sichern …**.
Beide Formate sind auch unten im Notenbereich erreichbar. MusicXML ist eine
vereinfachte Austauschfassung; LilyPond-spezifische Bögen und Oktavlinien sind
darin nicht vollständig enthalten.

Bei einem Syntaxfehler bleiben die letzte gültige Notation und Wiedergabe
erhalten. Der fehlerhafte Entwurf bleibt im Editor zur Korrektur stehen; die
Fehlermeldung erscheint in der Statusleiste und in der Diagnose.

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
