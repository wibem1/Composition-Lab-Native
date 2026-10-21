# LilyPond-Isolation: Windows-Timeout (21.10.2026)

Status: **unresolved, no release approved**. The user reported eight unsuccessful fixes through v4.2.8. Do not call a CI green build proof of this reproduction succeeding.

## Verified evidence
- 4.2.5, 4.2.6 and 4.2.8 diagnostics repeatedly fail with engraving timeout ~120–122 seconds for the same 46-bar violin/cello *Pastorale*.
- v4.2.8: LilyPond CPU ~115,938 ms within ~122,367 ms elapsed; working set ~96,595,968 bytes. A CPU-bound process is evidenced, but **no root cause** proven.
- v4.2.6 emitted GLib/GIO Windows AppxManifest warnings. These are clues, not proof of the cause.
- The checked Windows bundle uses LilyPond **2.24.4**, while V4.2-AUDIT.md says **2.26.0**. Resolve configuration/documentation mismatch.
- The Swift interpreter does not recognize ABC notation. This is **a separate failure mode**, not the cause of the witnessed LilyPond timeout.

## Reproduction and decision procedure
Use `Windows/Diagnose-LilyPond-Isolated.ps1` against the user's existing JSON diagnostic, with the same executable as shipped in the Windows ZIP. It extracts the original composition and tests original LilyPond **directly**, outside WinForms, the Core CLI, the AI pipeline and MIDI parser. It separates MIDI-only and SVG point-and-click runs, with bounded process execution and logs.

Example:
```powershell
pwsh -File Windows/Diagnose-LilyPond-Isolated.ps1 -DiagnosticPath 'Composition-Lab-Windows-Diagnose(20261021-105643).json' -LilyPondExe 'C:\Apps\Composition Lab 4.2.8\LilyPond\bin\lilypond.exe'
```

Inspect `LilyPond-Isolation/report.json`, `midi/stderr.txt`, `svg/stderr.txt`, and generated outputs.

1. Both tests time out with shipped binary -> reproduce below the app layer. Repeat with a separately installed verified Windows LilyPond version. Compare exact source SHA-256, binary versions, elapsed/CPU and logs.
2. MIDI succeeds, SVG times out -> investigate SVG/point-and-click/Fontconfig/Guile render path; bisect `--svg` and `-dpoint-and-click`.
3. Both direct runs succeed but GUI times out -> compare the exact prepared `source.ly`, process arguments, environment, working directory, fonts and resource limits (source SHA comparison).
4. Compiler succeeds but application still fails -> isolate `import-midi`, SVG loading, slot commits. Do not issue another model request as a workaround.

## Release gate
Before calling anything 4.2.9 / 4.29:
- Attach independent Windows run reports and logs to the development issue or CI artifacts.
- The exact saved Pastorale must finish reliably in both isolated compiler and full application; assert valid MIDI and SVG, not just exit code.
- Test cold and warm runs and a second source; prevent regressions on macOS.
- Keep the existing 4.2.8 release untouched until the failure is verified as repaired.
