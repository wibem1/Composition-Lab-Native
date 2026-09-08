# Composition Lab Native

Native macOS-Fassung von Composition Lab.

## Rolle im Music-Lab-System

Dieses Repository ist die **aktive Quellbasis für Composition Lab Native**. Die App gehört zusammen mit Composition Lab WebApp (`wibem1/Composer-Lab`) und Music Chat Lab (`wibem1/Music-Chat-Lab`) zu einem gemeinsamen Musiksystem.

Gemeinsame Grundlagen sind insbesondere Score-Schema, Engine, CLAB, MIDI- und MusicXML-Grundmodell. Anwendungsspezifisch sind hier vor allem native macOS-Funktionen, Partiturdarstellung, MIDI-Ausgänge und DAW-Anbindungen.

## Wichtiger aktueller Status

Das GitHub-Repository enthält derzeit **noch nicht den vollständigen aktuellen Programmstand**.

Der derzeit bekannte Referenzstand der tatsächlich entwickelten App ist:

- Composition Lab Native V5.0.11
- Build 83
- Engine Build 14

Dieser Referenzstand muss als nächster Konsolidierungsschritt **unverändert und vollständig** in dieses Repository übernommen werden. Bis das geschehen ist, darf der derzeitige GitHub-Inhalt nicht mit dem vollständigen Native-Quellstand verwechselt werden.

## CLAB

Composition Lab Native ist derzeit die Referenz für das gemeinsame `.clab`-Projektdokument. Das Ziel ist, dass Composition Lab WebApp und Music Chat Lab dasselbe Projektformat lesen und schreiben können.

## Entwicklungsregel

Keine neue Native-Funktion, bevor der vollständige Referenzstand V5.0.11 reproduzierbar in GitHub gesichert ist.

Die systemweiten Regeln sind im Repository `wibem1/Composer-Lab` in `SYSTEM-ARCHITECTURE.md` und `DEVELOPMENT-RULES.md` dokumentiert.
