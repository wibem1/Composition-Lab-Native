# External MuseScore MusicXML Audit

Stand: 8. September 2026
Branch: `native-core-alignment`

## Quelle

Öffentliche MusicXML-Datei:

`subsevenx/scarletdawnmusic/scores/polarity/forgotten/piano_r.xml`

Commit: `fbe97605247f732964a9d2d697a81ba67e5b4d20`

Die Datei weist sich selbst als `MuseScore`-Export aus (Encoding-Date 2017-04-13) und verwendet MusicXML 3.0.

## Relevante Fremdformat-Merkmale

Die Datei enthält unter anderem:

- zwei Stäbe (`<staves>2</staves>`)
- explizite `<staff>1</staff>` / `<staff>2</staff>`-Zuordnung
- `<backup>` für parallele Staff-/Voice-Struktur
- Tempo über Metronom und `<sound tempo="...">`
- Tonart
- Taktart
- spätere Taktartwechsel, z. B. 4/4 -> 6/4
- MuseScore-spezifische Layoutattribute
- notengebundene Playbackattribute wie `dynamics` / `end-dynamics`
- echte MusicXML-Ties über `<tie>` und `<notations><tied .../></notations>`

## Abgleich mit Native-MusicXMLParser

### Bereits passend

Der aktuelle Parser kann die folgenden musikalischen Kerninformationen aus diesem MuseScore-Stil lesen:

- Noten/Pitches
- Dauer über `divisions`
- Staff-Zuordnung 1/2
- Backup-/Forward-Cursorlogik
- Tempo
- Tonart
- Taktart
- Wechsel der Taktart während des Stücks
- Instrument-/Partname

Zusätzliche Layoutattribute und unbekannte XML-Elemente führen nicht zu einem Konflikt, weil der Parser nur die semantisch relevanten Elemente auswertet.

### Neuer offener Punkt: Tie

Die Fremddatei enthält echte Notenbindungen (`tie`/`tied`). Der aktuelle Import erzeugt daraus noch kein `ev`-Ereignis.

Das ist ein realer Interoperabilitätsbefund und keine künstliche Testanforderung.

`tie` ist deshalb im EV Contract 1.1 ausdrücklich als reservierter nächster Importtyp festgelegt.

## Weitere Beobachtung

Die Datei enthält notengebundene Attribute wie `dynamics="..."` und `end-dynamics="..."`. Diese sind nicht dasselbe wie notierte Dynamikzeichen `<direction><dynamics>...` und werden vom aktuellen Parser nicht als `dyn` übernommen. Das ist zunächst akzeptabel, weil sie primär Playback-/Interpretationsinformationen darstellen; falls sie später benötigt werden, muss entschieden werden, ob sie in `nt`-Velocity, `ev` oder einen separaten Ausdruckspfad gehören.

## Bewertung

Der externe MuseScore-Fall bestätigt, dass die grundlegende zweistaffige MusicXML-Struktur unseres Parsers mit real erzeugtem Material kompatibel ist.

Er deckt zugleich den nächsten sinnvollen Ausbaupunkt auf:

1. MusicXML-Ties importieren und semantisch erhalten.
2. Danach einen echten Fremdfall mit notierten Dynamikzeichen, Slurs, Artikulationen oder Pedal testen.

Der Referenzbranch `reference-v5.0.11` bleibt unverändert.
