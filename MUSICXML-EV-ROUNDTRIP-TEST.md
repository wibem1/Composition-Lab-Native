# MusicXML EV Roundtrip Test

Branch: `native-core-alignment`

## Goal
Verify the first five imported notation/expression event types across:

`MusicXML -> Score/ev -> MusicXML -> Score/ev`

Covered event types:
- `dyn`
- `art`
- `pedal`
- `slur`
- `wedge`

## Fixture
`tests/musicxml-ev-roundtrip.musicxml`

The fixture contains:
- dynamic `p` at beat 0
- crescendo from beat 0 to beat 4
- dynamic `f` at beat 4
- pedal start at beat 0 and stop at beat 4
- staccato on C4 at beat 0
- slur from beat 0 to beat 4

## Result after first import

- `art|staccato|b=0|st=1|p=60`
- `dyn|p|b=0|st=1`
- `pedal|start|b=0|st=1`
- `slur|b=0|e=4|st=1`
- `wedge|crescendo|b=0|e=4|st=1`
- `dyn|f|b=4|st=1`
- `pedal|stop|b=4|st=1`

## Result after export and second import

All seven semantic events are preserved with their musical meaning, values, beat positions, and range endpoints:

- `art|staccato|b=0|p=60`
- `dyn|p|b=0|st=1`
- `pedal|start|b=0|st=1`
- `slur|b=0|e=4`
- `wedge|crescendo|b=0|e=4|st=1`
- `dyn|f|b=4|st=1`
- `pedal|stop|b=4|st=1`

## Small normalization difference
For a single-staff part, the builder may omit explicit `<staff>1</staff>` on note-bound notation such as articulation and slur. On re-import this becomes `st=nil` instead of `st=1`.

This is semantically equivalent for a one-staff instrument because staff 1 is implicit. Direction-based events (`dyn`, `pedal`, `wedge`) remain explicitly assigned to staff 1.

## Conclusion
The first MusicXML EV import stage passes the controlled semantic roundtrip test.

No further code change is required for these five event types before testing with real-world MusicXML files. A later two-staff piano test should verify that staff-specific articulation/slur data remains explicit where staff identity is musically significant.
