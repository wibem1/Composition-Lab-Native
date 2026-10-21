# Local Windows engraving investigation — 2026-10-21

Application corrections are on `v4-cross-platform`, commit
`93904ffab3d7aed747c0c71f73bf8f8644c5af7a`. No new product release was published.

- Bound the output-pipe wait as well as the process wait. A descendant retaining
  inherited pipe handles cannot silently bypass the engraving deadline.
- Capture partial startup output before a newline or process termination, and
  retain captured output when a pipe cannot be drained after cancellation.
- Keep library warnings in the log while presenting concise engraving progress.
- Native Windows regression tests cover an exited parent with inherited pipes,
  partial stderr at timeout, and explicit cancellation separately.
- Quality-gate run 39568404188 passed on Windows 2022, macOS 15 and Ubuntu 24.04.
  The extracted Windows package passed its full native self-test. The original
  Pastorale rendered in 8596 ms, with 2 pages; the repeat reused identical MIDI.

## Isolated runtime experiment

Branch `fix/local-lilypond-startup` builds GLib 2.72.4 from pinned source commit
`6ed6303e40d6eaf80f2acfbfbcadbb169d156e9c`, once with lazy application enumeration
and once as an otherwise identical control. These DLLs are NOT integrated into
the application. All rendering stays local; only synthetic test scores are used.

Run 39568896709 executed 18 engraving jobs: three runtime variants, with and
without 1000 registered synthetic file handlers, repeated three times. All 18
processes exited successfully, produced SVG with editor links and valid MIDI,
and produced byte-identical MIDI across all variants. There were no timeouts.
The original compiler took about 3.8–4.0 seconds after its first run; the patched
variant about 3.7–3.8 seconds. This does not reproduce the reported failure.

The initial result validator incorrectly searched only for `.midi`; this Windows
runtime emits `.mid`. The test now accepts both extensions. A separate validation
job checks the immutable outputs from the completed rendering run, including all
18 process exits, page links, MIDI headers, and identical MIDI hashes. It does not
claim another rendering run occurred or erase the original failed validator.

## Remaining blocker

The uploaded JSON diagnostics end at application version 4.2.5. The new screenshot
shows a GIO Windows application-manifest warning, but not the full 4.2.6 process
log or failure result. A freshly exported 4.2.6 failure diagnostic is needed to
investigate the current runtime. The warning alone does not establish causation.
No online renderer and no further speculative runtime change has been enabled.
