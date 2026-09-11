# Composition Lab Native 3.0

## Leitentscheidung

Composition Lab Native 3.0 übernimmt das Arbeitsmodell von Music Chat Lab als Kern. Die Native-App ergänzt dieses Modell um ihre nativen Möglichkeiten: 10 Stück-Slots, Notenbild/Verovio, MIDI-Player, MusicXML, CLAB/CLABPROJECT, Drag & Drop, DAW-Brücken, Verlauf, Dateiablage und Diagnose.

## Zentrale Zustände

### 1. MusicChat
Freier musikalischer Dialog mit vollständigem Gesprächskontext. Die KI sieht den musikalischen Arbeitstisch und darf bei musikalisch relevanter Mehrdeutigkeit nachfragen. Keine lokale Triggerwort- oder Regex-Routinglogik entscheidet über die Bedeutung eines Auftrags.

### 2. Musikalischer Arbeitstisch
Alle belegten Stück-Slots 1–10 stehen dem Dialog als mögliche Quellen zur Verfügung. Ein aktiver Slot ist eine UI-Auswahl, keine semantische Festlegung. Mehrere Slots können gleichzeitig verglichen, analysiert oder als Material verwendet werden.

### 3. Kompositionsauftrag
Der Nutzerauftrag entsteht aus Dialog, aktuellem Kontext und den oberen musikalischen Eckdaten. Er ist nicht identisch mit der Kompositionsidee.

### 4. Kompositionsidee
Eigenständiger musikalischer Zwischenzustand. Die KI entwickelt zunächst einen kurzen musikalischen Gedanken/Impuls. Die Kompositionsidee wird rechts in einem direkt editierbaren mehrzeiligen Textfeld angezeigt. Der Nutzer kann sie frei ändern, kürzen, ergänzen oder ersetzen. Die aktuell sichtbare Fassung ist maßgeblich für die anschließende Partiturerzeugung.

### 5. Partitur
Eine Partitur wird nicht allein durch das Absenden einer MusicChat-Nachricht erzeugt. Die bewusste Ausführung über die Kompositionsfunktion verwendet den aktuellen Auftrag, die aktuell editierte Kompositionsidee, relevante Quellen und die musikalischen Eckdaten.

## Workflow

1. Nutzer arbeitet im MusicChat und/oder mit vorhandenen Slots.
2. KI versteht den Kontext und fragt nur bei musikalisch relevanter Mehrdeutigkeit nach.
3. KI entwickelt einen kurzen Kompositionsvorschlag / eine Kompositionsidee.
4. Die Idee erscheint im editierbaren Ideenfeld.
5. Nutzer diskutiert oder bearbeitet die Idee direkt.
6. Erst die bewusste Kompositionsausführung erzeugt die JSON-Partitur.
7. Ergebnis landet deterministisch in einem Zielslot; Quellenwahl und Speicherziel sind getrennte Konzepte.

## Diagnose

Die Diagnose muss die musikalische Pipeline nachvollziehbar dokumentieren:
- Gesprächskontext / aktueller Nutzerauftrag
- obere musikalische Eckdaten
- verfügbare Slot-Metadaten
- von der KI tatsächlich verwendete Quellen
- erzeugte Kompositionsidee
- vom Nutzer editierte endgültige Kompositionsidee
- endgültiger Partitur-Prompt
- Rohantwort / Decode-Ergebnis / Fehler
- Provider, Modell, Tokens und Kosten soweit verfügbar

Der Diagnose-Export muss unabhängig vom aktuellen UI-Fokus zuverlässig funktionieren und sichtbar fehlschlagen, falls kein Export möglich ist.

## Nicht mehr zulässig

- lokale Triggerwortlisten zur Entscheidung "neu / bearbeiten / vergleichen"
- Slot-Belegung als Bedeutungsheuristik
- MusicChat-Senden erzeugt ungefragt sofort eine Partitur
- Kompositionsauftrag im Feld "Kompositionsidee" anzeigen
- KI-Kompositionsidee nach manueller Bearbeitung heimlich wieder überschreiben
- alte Partitur-/Ideenzustände mit einem neuen noch nicht ausgeführten Auftrag vermischen

## Native Zusatzfunktionen, die erhalten bleiben

- 10 Stück-Slots und Karten
- Main / Noten / Technik
- Notenansicht mit Slotwahl und vollständigem Player
- Piano-Ein-/Zwei-System-Darstellung mit Splitpunkt
- MIDI / MusicXML / CLAB / CLABPROJECT
- Drag & Drop
- Verlauf
- Kostenanzeige
- API-/Modellauswahl
- asynchrone DAW-Brücke ohne Scroll-Bremse
- Reaper / Studio One und weitere DAW-Workflows
- Projekt speichern/laden und Backup
