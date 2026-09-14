# MusicXML EV Import – native-core-alignment

Stand: 8. September 2026

Diese Änderung erweitert ausschließlich den MusicXML-Import. Der Referenzbranch `reference-v5.0.11` bleibt unverändert.

## Neu importierte EV-Typen

| MusicXML | Score `ev` |
|---|---|
| `<dynamics><p/>` usw. | `{"t":"dyn","v":"p"}` usw. |
| `<articulations><staccato/>` | `{"t":"art","v":"staccato"}` |
| `<articulations><tenuto/>` | `{"t":"art","v":"tenuto"}` |
| `<articulations><accent/>` | `{"t":"art","v":"accent"}` |
| `<strong-accent>` | `{"t":"art","v":"marcato"}` |
| `<pedal type="start/change/stop">` | `{"t":"pedal","v":"start/change/stop"}` |
| `<wedge type="crescendo/diminuendo"> ... <wedge type="stop">` | `{"t":"wedge","v":"crescendo/diminuendo","e":...}` |
| `<slur type="start"> ... <slur type="stop">` | `{"t":"slur","e":...}` |

## Positionssemantik

- `b` und `e` sind Viertelnoten-Beats im gemeinsamen Score-System.
- MusicXML-`<offset>` wird berücksichtigt.
- `<staff>` wird nach `st` übernommen, soweit vorhanden.
- Artikulationen werden zusätzlich mit MIDI-Pitch `p` an die konkrete Note gebunden.
- Slur- und Wedge-Paare werden über ihre MusicXML-`number` getrennt verfolgt.

## Bewusst nicht verändert

- Notenimport und `gate=0.95` für MusicXML bleiben in diesem Schritt unverändert. MusicXML beschreibt eine notierte Dauer und nicht zwingend die reale MIDI-Klingdauer.
- MIDI-Import-Gatekorrektur ist ein separater bereits dokumentierter Schritt.
- Ornamente, Fermaten, Grace-Notation, freie Wörter und weitere EV-Typen werden in einem späteren Schritt behandelt.
- Der Referenzstand V5.0.11 wird nicht verändert.

## Testziel

Für eine MusicXML-Datei mit Dynamik, Artikulation, Pedal, Slur und Crescendo/Diminuendo muss der Roundtrip

`MusicXML -> Score/ev -> MusicXML`

diese fünf Ausdrucksschichten semantisch erhalten.
