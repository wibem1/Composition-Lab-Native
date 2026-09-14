# MusicXML Tie Import Test

Stand: 8. September 2026
Branch: `native-core-alignment`

## Anlass

Ein externer MuseScore-3.0-Fall (`scores/polarity/forgotten/piano_r.xml`) enthält reale Notenbindungen sowohl als `<tie type="..."/>` als auch als `<notations><tied type="..."/></notations>`.

Der Native-Import soll daraus genau ein semantisches `ev`-Ereignis erzeugen, nicht zwei.

## Implementierung

`Sources/MusicXMLParser.swift` erkennt jetzt `tie` und `tied` mit `type="start"` bzw. `type="stop"`.

Die beiden parallel vorhandenen MusicXML-Repräsentationen werden pro Note dedupliziert. Die Bindung wird intern als ein Bereich gespeichert:

```json
{"t":"tie","b":0.0,"e":2.0,"st":1,"p":60}
```

Der Schlüssel für offene Ties verwendet Part, Staff und Pitch.

## Ausführbarer Test

Die Testdatei `tests/musicxml-musescore-tie-import.musicxml` bildet genau die MuseScore-typische Kombination aus `<tie>` und `<tied>` ab.

Ergebnis:

- Tracks: 1
- Noten: 2
- `tie`-Events: 1
- Start: `b=0.0`
- Ende: `e=2.0`
- Staff: `1`
- Pitch: `60`

Der Test ist bestanden.

## Bezug zum externen MuseScore-Fall

Der öffentlich geprüfte MuseScore-Export verwendet dieselbe Doppelrepräsentation aus `tie` und `tied`; damit deckt der Test genau den real beobachteten Importfall ab.

## Noch offen

Der Import ist damit abgesichert. Für einen vollständigen `MusicXML -> Score/ev -> MusicXML`-Roundtrip muss der explizite `tie`-EV zusätzlich in den MusicXML-Builder integriert werden. Der bestehende Builder erzeugt zwar bereits automatisch Ties für intern aufgeteilte lange Noten, interpretiert aber noch keine importierten `ev.t == "tie"`-Bereiche. Dieser Export-Schritt wird separat durchgeführt, damit keine bestehende Notationslogik beschädigt wird.
