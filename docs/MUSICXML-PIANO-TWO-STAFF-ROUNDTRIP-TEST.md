# Zweistaffiger MusicXML-EV-Roundtrip-Test

Branch: `native-core-alignment`

## Ziel

Pruefen, ob zweistaffige Klavier-MusicXML-Dateien die Staff-Zuordnung von Noten und Notationsereignissen im Roundtrip erhalten:

`MusicXML -> Score/ev -> MusicXML -> Score/ev`

## Testfall

Eine kontrollierte Klavierpartitur mit zwei Systemen:

- Staff 1: C5-D5, Staccato auf C5, Dynamik `p`, Slur von C5 nach D5
- Staff 2: C3-B2, Tenuto auf C3, Dynamik `f`, eigener Slur von C3 nach B2

## Ergebnis

Der Roundtrip ist bestanden.

Vor und nach dem Export/Reimport bleiben erhalten:

- vier Noten mit unveraenderter Staff-Zuordnung 1/2
- `art|staccato` auf Staff 1 und Pitch 72
- `art|tenuto` auf Staff 2 und Pitch 48
- `dyn|p` auf Staff 1
- `dyn|f` auf Staff 2
- ein Slur auf Staff 1 von Beat 0 bis Beat 1
- ein separater Slur auf Staff 2 von Beat 0 bis Beat 1

Die beiden Haende werden also nicht vermischt. Anders als beim einstaffigen Test bleibt `st` fuer notengebundene Ereignisse hier explizit erhalten, weil die Staff-Nummer fuer die zweistaffige Notation semantisch notwendig ist.

## Fazit

Die aktuelle MusicXML-EV-Erweiterung ist fuer die getesteten zweistaffigen Klavierfaelle staff-sicher. Weitere Tests sollten spaeter komplexere Stimmenfuehrung, mehrere Slurs gleicher Staff-Nummer, Pedal ueber beide Systeme sowie echte externe MusicXML-Dateien abdecken.
