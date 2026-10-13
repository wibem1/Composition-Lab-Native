# Composition Lab Native 4.0 – erste Windows-Testversion

Version 4.0.0-alpha.2 · Build 4002 · Windows 10/11, 64 Bit Intel/AMD

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
