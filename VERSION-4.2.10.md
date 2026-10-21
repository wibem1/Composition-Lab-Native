# Composition Lab Native 4.2.10 — Romanze A4 correction

The uploaded Windows 4.2.9 diagnostic from 21 October 2026 failed in the shared source policy before starting LilyPond. The original Romanze uses the normal literal paper-size constructor `#(set-paper-size "a4")`. Strings were masked before the policy allowed notation constructors, so this paper declaration was wrongly rejected. This is separate from the resolved Guile initialization timeout.

The shared policy now recognizes literal paper-name constructors (and optional literal landscape orientation) against the original source only when the call begins in actual notation. The source and its line offsets remain unchanged; nested expressions, extra arguments and unrelated executable calls remain rejected. No automatic paid model call is used for this repair.

The exact original Romanze source is stored as `Tests/CompositionCoreTests/Fixtures/romanze-violin-piano-a4.ly`. New shared regression tests cover this entire source, landscape, comments/strings and rejected executable arguments. Both native Windows bundle tests now compile it to MIDI/SVG, verify violin and piano through all 37 bars, import the document and check exact original source/MIDI exports. The release gate requires both Romanze test reports alongside Pastorale and all 374 Guile-pair repair checks.

All version/title/package metadata now identify 4.2.10, build 4210. The existing published 4.2.9 is preserved. Architecture check: PASS (23 Windows operations and package/version consistency).

Full cross-platform and native workflow verification: pending. No release is authorized by this document alone; the existing full test gate controls publication.
