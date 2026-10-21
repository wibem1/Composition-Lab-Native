# Composition Lab Native 4.2.10 — Romanze A4 correction

The uploaded Windows 4.2.9 diagnostic from 21 October 2026 failed in the shared source policy before starting LilyPond. The original Romanze uses the normal literal paper-size constructor `#(set-paper-size "a4")`. Strings were masked before the policy allowed notation constructors, so this paper declaration was wrongly rejected. This is separate from the resolved Guile initialization timeout.

The shared policy now recognizes literal paper-name constructors (and optional literal landscape orientation) against the original source only when the call begins in actual notation. The source and its line offsets remain unchanged; nested expressions, extra arguments and unrelated executable calls remain rejected. No automatic paid model call is used for this repair.

The exact original Romanze source is stored as `Tests/CompositionCoreTests/Fixtures/romanze-violin-piano-a4.ly`. New shared regression tests cover this entire source, landscape, comments/strings and rejected executable arguments. Both native Windows bundle tests now compile it to MIDI/SVG, verify violin and piano through all 37 bars, import the document and check exact original source/MIDI exports. The release gate requires both Romanze test reports alongside Pastorale and all 374 Guile-pair repair checks.

All version/title/package metadata now identify 4.2.10, build 4210. The existing published 4.2.9 is preserved. Architecture check: PASS (23 Windows operations and package/version consistency).

Full cross-platform and native workflow verification: pending. No release is authorized by this document alone; the existing full test gate controls publication.

## Second defect exposed by the original-score test

Run 39678542323 passed shared tests and the full Mac build but rejected the original Romanze MIDI after engraving. Independent Windows engraving in run 39679810313 produced five SVG pages. Downloaded raw MIDI shows bass pitches written as bytes 251, 255, 246, 253, 239, corresponding to negative pitches; the relative bass descends below MIDI zero. This is a source octave error and must not be admitted as valid MIDI.

The MIDI parser now rejects invalid note data bytes immediately with track, note, velocity and a precise octave-range explanation. A separately named bass-corrected fixture uses absolute bass pitches. A token comparison requires unchanged pitch names, chords, durations, accidentals and all other notation except bass octave marks. The violin and right-hand source remain unchanged. Native tests require original A4 acceptance, explicit rejection of invalid original MIDI, and complete corrected-score import/export. No silent octave folding or paid automatic repair was added. Full tests remain required before release.


## Final verification and release

Workflow https://github.com/wibem1/Composition-Lab-Native/actions/runs/39681244303 completed SUCCESS on commit 967667213c9cbdddf020f54ac7f7b5ce1649afc4. Mac, Linux and Windows regression jobs all passed. The standalone Windows compilation gate also passed. During development a missing Regex import in the new native comparison test was corrected before this successful full run.

Downloaded Windows-Starttest artifact 12385670130 was inspected:

| Evidence | Original bundle | Extracted ZIP |
| --- | --- | --- |
| Native report | passed, version 4.2.10, 40 areas | passed, version 4.2.10, 40 areas |
| Original A4 declaration accepted | true | true |
| Invalid original bass MIDI explicitly rejected | true | true |
| Corrected Romanze complete import/export | passed | passed |
| Corrected Romanze cold engraving | 20054.9276 ms | 20160.7309 ms |
| Corrected Romanze SVG pages / tracks / bars | 4 / 3 / 37 | 4 / 3 / 37 |
| Deliberately inverted Guile timestamps repaired | all 374 pairs | all 374 pairs |

The unchanged original remains an explicit negative-MIDI test. The separately named corrected score changes bass octaves only; it is not presented as the unchanged original. Both successful native tests verify its document import and byte-preserving source/MIDI export.

Published release: https://github.com/wibem1/Composition-Lab-Native/releases/tag/v4.2.10

Release target: 967667213c9cbdddf020f54ac7f7b5ce1649afc4.

Windows ZIP SHA256: 22b01760cbbf8a2f5f201ec9065f25bc8f1782b261c76fe13cc6ab03426a7b1c.

The same release includes Romanze-Bassoktaven-korrigiert.ly and Romanze-Bassoktaven-korrigiert.mid, copied from the successfully tested extracted package's exports. No new paid composition or manual application tests were needed.

