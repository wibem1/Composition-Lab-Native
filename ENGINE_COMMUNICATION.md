# Composition Lab – KI-Kommunikation ab V3.4.0

## Grundsatz
Die App entscheidet nichts Musikalisches. Sie transportiert Nutzerauftrag, bewusst gewählten Kontext und technische Ausgabeanforderungen.

## Ablauf
1. Musikalische Vorstellung – freie KI-Antwort auf den Nutzerauftrag; keine Notation/JSON/MIDI.
2. Komposition – KI komponiert eigenständig aus Auftrag und aktueller musikalischer Vorstellung.
3. Technische Realisation – das JSON-Schema beschreibt ausschließlich die Ausgabe.

## Kontext
- Chat-/Projektgedächtnis ist nicht automatisch Kompositionsmaterial.
- Slot-Scores werden nicht pauschal in jeden MusicChat-Aufruf kopiert.
- Vollständige Scores werden nur dort übertragen, wo die Funktion sie tatsächlich benötigt.
- Der an die KI gesendete Gesprächskontext wird begrenzt; der vollständige Chat bleibt lokal erhalten.

## Protokoll
Jeder zentrale API-Aufruf protokolliert Zweck/Funktion, Provider, Modell, Reasoning, System- und User-Prompt, Antwort, Tokens, Zeit und Fehler. API-Schlüssel und Autorisierungsdaten werden nie protokolliert.

## Entwicklungsregel
Keine Build-Zeit-Patches. Sources ist die maßgebliche, direkt kompilierbare Quelle.
