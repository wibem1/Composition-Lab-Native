# Alpha 11 · Build 4012 · 14.10.2026 – Korrektur der Windows-Skalierung

Maßgeblich ist die GUI aus `main` (Mac 3.5.3, Commit a2aefd7). Die folgenden älteren Abschnitte beschreiben frühere Windows-Stände.

- Main: gleiche Parameterleiste, MusicChat mit eigener Eingabe, editierbare Kompositionsidee, horizontales Deck aus zehn Karten, Player und Funktionsleiste darunter.
- Noten: linke Parameterseite aus dem Mac-Code, gleiche Presets/Quantisierungswerte, Stück-Auswahl, Player, Seiten-/Zoomsteuerung, Vorschau und MusicXML-Export einschließlich Dateidrag.
- Technik: API-Schlüssel/MIDI/CLAB/JSON-Aktionen, Technische Prüfung, JSON und Verlauf. Diagnose im Menü.
- Karten: auswählen, Datei hineinziehen, Rechtsklick zum Laden/Löschen. Die Idee bleibt beim Stückwechsel erhalten.
- Einzelstücke, Verlauf und Einstellungen werden weiter lokal gespeichert. Projektdateien verwenden das Mac-Format `composition-lab-v6-project` und werden im gemeinsamen Kern geprüft.
- Presets greifen auf den gemeinsamen MusicXML-Exporter zu; MIDI und Score bleiben dabei unverändert.

Schrift, Menüleisten und System-Steuerelemente werden von Windows gezeichnet. Eine pixel- oder binäridentische Übernahme von Apple-AppKit ist keine Windows-Funktion. Der Aufbau wurde anhand der real ausgeführten Mac-Oberfläche abgeglichen. Bei kleinen Fenstern sind Deck und Arbeitsbereiche scrollbar.

Die vollständige Mac-MusicChat-Aktionssteuerung ist noch nicht portiert; der bisherige Windows-Chat bleibt bestehen. Verschlüsselte Mac-Backups und Soundfont-/direkte MIDI-Ausgangswahl benötigen weitere Windows-Adapter. Die zugehörigen Menüpunkte melden diese Einschränkung. Hörbarer Klang, Druck und tatsächliche WebView2-Noteninteraktion bleiben praktisch zu prüfen; der CI-Testrechner besitzt keinen MIDI-Synthesizer. Automatische Tests erzeugen keine bezahlten KI-Anfragen.

Das gesamte ZIP in einen neuen Ordner entpacken und `Composition Lab 4.0.exe` starten. Bestehende Windows-Stücke und Schlüssel bleiben in ihrer bisherigen Arbeitsablage. Die bisherige Mac-Version auf `main` bleibt unverändert.


## Start und Arbeitsablage

Windows 10/11, Intel/AMD 64 Bit. Das gesamte ZIP entpacken, dann `Composition Lab 4.0.exe` starten. Den Unterordner `Core` mit seinen DLLs beibehalten. .NET und Swift müssen nicht separat installiert werden. Die Notenanzeige benötigt Microsoft Edge WebView2 Runtime und Internet zum Laden von Verovio.

Einstellungen und Stücke liegen unter `%LOCALAPPDATA%/Klangwerke/Composition Lab 4.0`. API-Schlüssel stehen getrennt, mit Windows-DPAPI verschlüsselt, in `keys.dpapi`. Sie lassen sich nur im selben Windows-Benutzerkonto öffnen und stehen nicht in Exporten oder Diagnosen.

## Korrekturen in Alpha 8

DPI-Skalierung wird erst nach dem vollständigen Aufbau angewendet. Scrollflächen berücksichtigen die Skalierung. Titel und Navigation überdecken sich nicht mehr; Überschriften, Erklärungstexte und Parameterzeile erhalten die tatsächlich benötigte Texthöhe. Die Windows-Prüfung prüft Layout und Schriftmetriken bei simulierten 100, 125, 150 und 200 Prozent, jeweils mit kleiner und großer Fenstergröße. Die Simulation ersetzt keinen praktischen Test auf jedem Bildschirm.

## Anpassbare Hauptansicht in Alpha 8

MusicChat und Kompositionsidee teilen sich beim ersten Start die sichtbare Fensterbreite gleichmäßig. Die graue Trennlinie lässt sich mit der Maus verschieben; ihre Position bleibt beim nächsten Start erhalten. Die Parameter- und Aktionsleisten brechen bei Bedarf um. Beide Textbereiche bleiben innerhalb der sichtbaren Fensterbreite; die zehn Karten bleiben separat horizontal scrollbar.

## Stabile Tabwechsel in Alpha 9

Beim Aktivieren eines Arbeitsbereichs wird seine Scrollposition auf den Anfang gesetzt. Die native Fokuswiederherstellung darf dabei die oberen Elemente nicht wegscrollen; der Fokus bleibt auf dem gewählten Tab. Größenänderungen und Zeilenhöhen werden zusammen angewendet, unveränderte Größen bleiben unangetastet. Die Aufteilung wird nur nach einer tatsächlichen Bewegung der Trennlinie gespeichert. Gepufferte Container reduzieren Zwischenbilder. Die Windows-Prüfung wechselt die Tabs wiederholt nach Fokus auf einem unteren Button bei allen vier simulierten Skalierungen und zwei Fenstergrößen.

## Chat-Kompositionen und kleinere Slots in Alpha 10

Fertige LilyPond-Kompositionen aus dem Chat werden einmal technisch in die interne Partitur übertragen, anschließend in einem freien Slot gespeichert, ausgewählt und für MIDI-Abspielen vorbereitet. Eine neue Komposition wird dabei nicht angefordert. Die Diagnose enthält Quelltext, technische Antwort und Gesamtkosten. Bei Fehlern bleibt die fertige Musik erhalten.

Zum Übernehmen einer früheren Chat-Komposition: Komposition → Fertige Komposition übernehmen. Alternativ ihre Diagnose-JSON öffnen/importieren. Diese technische Übertragung benötigt den eingetragenen KI-Schlüssel und verursacht die Kosten einer Übersetzungsanfrage; die ursprüngliche Komposition wird nicht neu erzeugt.

Die Karten sind 104 × 100 statt 116 × 164 logische Pixel groß; die Slot-Leiste ist entsprechend flacher.

## Slot-Leiste und Streicherschlüssel in Alpha 11

Alle zehn Slot-Buttons teilen sich die sichtbare Breite ohne eigene horizontale oder vertikale Scrollfläche. Lange Titel werden gekürzt; der vollständige Titel bleibt als Tooltip verfügbar.

Die Zuordnung der Solo-Streicher im MusicXML-Export ist korrigiert: Violine G2, Viola C3, Cello/Kontrabass F4. Tonhöhen und MIDI bleiben erhalten. Vorhandene Stücke brauchen keine neue KI-Anfrage: neu laden oder unter Noten aktualisieren.

Alpha 12: Mehrzeiliges Auftragsfeld mit Zeilenumbruch (Enter: neue Zeile, Strg+Enter: senden). Noten passen ins Fenster; Große Ansicht blendet Zusatzbereiche aus. Native Neuzeichnung nach Scrollen und Tabwechsel.
