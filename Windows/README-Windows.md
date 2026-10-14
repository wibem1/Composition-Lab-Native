# Alpha 7 · Build 4007 · 14.10.2026 – Korrektur der Windows-Skalierung

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

---

# Neue Werkstatt · Alpha 5 · Build 4005 · 13.10.2026

Eine neue Windows-Oberfläche mit eigenem Erscheinungsbild: dunkler Kopfbereich, helle gerundete Arbeitsflächen, Petrol als Akzent und lesbare Typografie. Links stehen die zehn Stücke dauerhaft in einer Bibliothek. Die nummerierten Karten zeigen vollständige Titel soweit Platz vorhanden ist; **+** lädt eine Datei in diesen Platz, **×** löscht ihn. Rechtsklick und Dateidrop bleiben verfügbar.

**Werkstatt / Noten / Technik** wechseln den Arbeitsbereich. Player, aktuelles Stück und Auftrag bleiben erreichbar. Dateiaktionen stehen unter **Datei & Export**. Der Auftrag hat klar beschriftete Parameterfelder und eine hervorgehobene Komponieren-Schaltfläche. Der musikalische Ablauf, Exporte und gespeicherte Arbeitsstände bleiben kompatibel.

Das Fenster passt sich nach dem Start an den verfügbaren Bildschirm an. Windows übernimmt die DPI-Skalierung. Automatische geometrische Prüfungen kontrollieren alle drei Arbeitsbereiche mit angeforderten Größen 1000×700 und 1400×940 Pixeln (der Testrechner begrenzt das große Fenster auf seine Bildschirmauflösung); zusätzlich werden echte Fensterbilder erzeugt. Die bisherige Mac-Version wird nicht ersetzt.

# Windows Alpha 4 · Build 4005

Die Stück-Karten zeigen Titel und Auswahl. Klick auf einen freien Platz öffnet den Import. Jeder Platz besitzt **Laden** und **×** zum einzelnen Löschen; außerdem gibt es ein Rechtsklick-Menü und Dateidrop. Unterstützt werden einzelne CLAB-Stücke, MIDI, MusicXML und Kompositionsdiagnosen. Ersetzen und Löschen werden bestätigt. Ein ungültiger Import lässt das bisherige Stück erhalten.

**LilyPond …** exportiert den vorhandenen KI-Quelltext unverändert als UTF-8-Datei `.ly`, ohne Markdown-Hülle und ohne neue KI-Anfrage. **Hacklily ↗** kopiert ihn und öffnet den Editor: dort links Strg+A, Strg+V. Der kurze Hinweis erläutert die Übergabe. Stücke aus MIDI/MusicXML enthalten nicht automatisch LilyPond; hier gibt es eine klare Meldung statt einer erfundenen Konvertierung.

Dateiaktionen befinden sich im Menü **Datei**. Die kompaktere Oberfläche lässt mehr Platz für MusicChat und Noten. API-Schlüssel und Diagnosen bleiben unter Technik.

# Composition Lab Native 4.0 – erste Windows-Testversion

Version 4.0.0-alpha.5 · Build 4005 · Windows 10/11, 64 Bit Intel/AMD

## Start

Das **gesamte ZIP** entpacken, dann `Composition Lab 4.0.exe` im entpackten Ordner
starten. Den Unterordner `Core` mit seinen DLLs beibehalten. .NET und Swift müssen
nicht separat installiert werden. Die App installiert oder überschreibt keine
bisherige Version.

## Was funktioniert

- KI-Chat und Komposition mit dem gemeinsamen Mac-/Windows-Swift-Kern.
- Freies Modellfeld für Claude, OpenAI und Gemini; API-Schlüssel eingeben.
- Zwei Stufen: vollständige Komposition, dann technische Übertragung.
- Zehn Stück-Slots, lokale Wiederherstellung von Dialog und Stücken.
- `.clab`-Stücke öffnen/speichern und mit der Mac-App austauschen.
- MIDI/MusicXML importieren und exportieren.
- Notenanzeige mit Verovio, Zoom und allen Seiten.
- Abspielen, Pause und Stopp über den Windows-General-MIDI-Synthesizer.
- Diagnose mit vollständiger Komposition, Score, Tokens und geschätzten Kosten.
- Abbrechen einer lokalen KI-Anfrage.

## Erster Versuch

1. Zunächst eine vorhandene MIDI-, MusicXML- oder CLAB-Datei öffnen.
2. Unter „Noten“ die Darstellung prüfen und „Abspielen“ benutzen.
3. KI-Anbieter und einen für deinen API-Zugang gültigen Modellnamen wählen.
4. Schlüssel eintragen. „Schlüssel speichern“ ist optional und verwendet DPAPI.
5. Auftrag eingeben; „Chat“ bespricht ihn, „Komponieren“ erzeugt das Stück.
6. Ergebnis als `.clab` speichern; optional MIDI oder MusicXML exportieren.

Die voreingestellten Modellnamen stammen aus der bisherigen Native-App. Bei
„Modell nicht gefunden“ den aktuellen Modellnamen deines Anbieters einsetzen.

## Grenzen dieser Alpha

Die Notenanzeige benötigt Microsoft Edge WebView2 Runtime und zum Laden von
Verovio Internet. Fehlt die Runtime, erscheint ein Hinweis; Export und Player
sind unabhängig davon. Noch keine Soundfont-/MIDI-Gerätewahl, keine DAW-Brücke,
kein automatisches Update und kein Import kompletter `.clabproject`-Arbeitsplätze.
Die Windows-Werkstatt speichert ihre zehn Slots lokal; einzelne `.clab`-Stücke
sind mit Mac austauschbar.

Die Kostenschätzung ist dieselbe wie auf Mac und kann für andere Modellnamen
abweichen. Abbrechen verhindert keine bereits beim Anbieter entstandenen Kosten.
Automatische Tests verursachen keine echten KI-Anfragen. Die hörbare Klangqualität
und ein echter API-Aufruf müssen zusätzlich praktisch geprüft werden.

Einstellungen und Projekte liegen unter `%LOCALAPPDATA%/Klangwerke/Composition Lab 4.0`.
API-Schlüssel stehen getrennt und mit DPAPI verschlüsselt in `keys.dpapi`; der
Schlüssel lässt sich nur im selben Windows-Benutzerkonto wieder öffnen.
Keine Schlüssel in Exporten oder Diagnosedateien.

## Korrekturen in Alpha 7

DPI-Skalierung wird erst nach dem vollständigen Aufbau angewendet. Scrollflächen berücksichtigen die Skalierung. Titel und Navigation überdecken sich nicht mehr; Überschriften und Parameterzeile erhalten die tatsächlich benötigte Texthöhe. Die Windows-Prüfung prüft zusätzlich Layout und Schriftmetriken bei simulierten 100, 125, 150 und 200 Prozent.
