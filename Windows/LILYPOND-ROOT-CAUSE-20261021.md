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

## Verified CI evidence, continuation
Run https://github.com/wibem1/Composition-Lab-Native/actions/runs/39609860657
at `bc16c41f6945ee474dcd2ae5c627ef8e1b9b8beb`, Windows Server 2022:
- Exact original source SHA-256: `46B79C95EC582B1FF4143F9ADA97D2F3BF7B9DBED5CB9D6618C0459342768DE5`.
- Official LilyPond 2.24.4 / Guile 2.2: MIDI 1,099 ms; SVG without point-and-click 10,771 ms; SVG with point-and-click 10,796 ms. All three exited 0 and produced expected files; both SVG runs produced two pages and MIDI.
- The overall run failed because the newly added minimal control used doubled backslashes inside a literal PowerShell here-string. Its three cases exited 1, without timeout. This is a test-fixture defect, not reproduction of the user's hang.
- The direct test did not reproduce the application's explicit FONTCONFIG/XDG settings. Therefore these results do not clear that launch environment, nor the user's installed Windows environment.

Continuation corrects the control fixture, propagates native PowerShell exit codes explicitly, and compares inherited versus application font environment on Windows Server 2022 and 2025. Verbose logs retain startup phase evidence. Per-case output directories are reset before execution to prevent stale outputs passing the gate. No product runtime or version is changed without evidence.

Runtime versions are intentionally platform-specific: Windows/Build.ps1 and Windows/LilyPondCompiler.cs pin Windows to 2.24.4; Tools/bundle_lilypond.py pins macOS to 2.26.0. A blanket 2.26.0 statement does not describe the shipped Windows bundle.

Important comparison gap found in branch history: release/v4.2.8 (`2b4e696`) applies a replacement GLib/GIO runtime and Guile timestamp repair, whereas v4-cross-platform still builds 4.2.6 with the official unmodified runtime. Thus the existing standalone tests do **not** test the same runtime as the user's v4.2.8. The expanded matrix also downloads the exact v4.2.8 release ZIP, verifies its published SHA-256 `5702dd4f05c641bdaecf44fc46e3962a02d2378949a290120a6242f9b358d2d0`, and runs both original sources against it. Version-number equality alone cannot identify the runtime.

## Expanded matrix result
Run https://github.com/wibem1/Composition-Lab-Native/actions/runs/39611300503 at `f4690968c4de6715b074aeafecebbd272f0f3aa2`: both original and released-4.2.8 runtimes pass the exact Pastorale and corrected minimal control, with inherited and application font environments on Windows Server 2022 and 2025. The reported user-machine CPU stall is **not reproduced**. No timeout repair is proven.

`Windows/LilyPond-CPU-Diagnose.cmd` is a standalone, Windows PowerShell 5.1-compatible follow-up: place beside the installed application EXE and double-click. It tests version, minimal score and the embedded exact Pastorale, captures full verbose startup logs and CPU samples with bounded deadlines, and saves a single JSON on Desktop. It does not change the installation, registry, API settings or original composition and makes no network/AI calls. The actual CMD is tested against the released package by CI on both Windows runners. This is diagnostic work, not a product fix or new release.

## Verified continuation: repaired test infrastructure and full native path

Investigation of issue #7 on 2026-10-21; no product release.

### Changes

- `d5e7cd2`: repaired a syntactically corrupted isolation script (truncated regex literals and duplicated report tails). Added `app-exact` with the production CLI arguments; requires BOTH MIDI and SVG. Rerunning old run 39615507269 proved a PowerShell parser failure before LilyPond execution, not an engraving timeout.
- `6522072`: added exact Pastorale to the full native application path: prepare, compile, MIDI import, two instrument programs, final bar, slot acceptance, document validation and original .ly/.mid exports.
- `4d011ab`: fixed standalone CMD under a Windows PowerShell 5.1 process inheriting PowerShell 7 module paths; uses its own built-in modules.
- `30b83ad`: corrected the new test's line-ending comparison and freed its temporary slot before the independent existing score fixture. MIDI remains byte-exact. The first native run correctly blocked on the new test assertion; downloaded .ly artifact matched the original after line-ending normalization.

### Actual completed runs and artifacts

Isolation: https://github.com/wibem1/Composition-Lab-Native/actions/runs/39618748438 (commit `4d011ab2264151ba92d62142c3c18f761278ce0d`): **all eight jobs green**. Windows 2022/2025 × official/released-4.2.8 × inherited/application environments. Every minimal control and exact Pastorale case exited 0 with required output. Exact application case took 6280–10831 ms. Standalone CMD passed against released 4.2.8 on both runners.

Native: https://github.com/wibem1/Composition-Lab-Native/actions/runs/39619876034 (commit `30b83adc0d6daf0ffe8e86ecaa437da6975db7bc`): **Windows, macOS and Linux green**. Windows compiled and tested the application, compressed it, extracted it and tested the extracted package again. Release job skipped.

Downloaded and inspected `Windows-Starttest`, artifact `12353709536`:

| Check | Source bundle | Extracted package |
| --- | ---: | ---: |
| Pastorale cold engraving | 8500.1077 ms | 8423.2025 ms |
| SVG pages | 2 | 2 |
| Warm cache reused | true | true |
| Native result passed | true | true |
| Complete processing stage | completed | completed |
| Conversion AI calls | 0 | 0 |
| Violin program / note events / last beat | 40 / 184 / 138 | 40 / 184 / 138 |
| Cello program / note events / last beat | 42 / 151 / 138 | 42 / 151 / 138 |

Beat 138 is the end of all 46 bars in 6/8. Native assertions validate both tracks, preserved original MIDI, document acceptance and original source/MIDI exports. Independently parsed isolated MIDI and both SVG XML documents also pass. Original source SHA-256 remains `46b79c95ec582b1ff4143f9ada97d2f3bf7b9dbed5cb9d6618c0459342768de5`.

### Remaining blocker and release decision

The user's saved 4.2.8 diagnostic still proves a CPU-bound ~122-second stall, but contains no LilyPond phase output. None of these tests reproduces it. CI uses Windows Server, not the affected Windows installation. The branch application still identifies as 4.2.6; testing it does not silently turn it into released 4.2.8 or a new 4.2.9.

**Root cause on the affected machine remains unproven. No runtime timeout fix has been made, no 4.2.9/4.29 tag or release was created, and issue #7 remains open.** A failing-machine verbose phase trace (the now CI-tested `Windows/LilyPond-CPU-Diagnose.cmd`) is the next missing evidence. It must be collected beside the actually installed application; successful CI alone is not sufficient to claim repair.

## Nachweis der Ursache und Reparatur (Fortsetzung am 21.10.2026)

**Status der Ursache: kontrolliert reproduziert. Status der automatischen Produktkorrektur: noch ohne verifizierten vollständigen CI-Endnachweis.** Die ursprünglichen Abschnitte dieses Dokuments beschreiben die damaligen Zwischenstände; sie sind nicht mehr der neueste Erkenntnisstand.

- Das betroffene Windows-26200-Diagnoseprotokoll belegt übereinstimmende SHA-256-Dateiinhalte mit erfolgreichen CI-Paketen, aber eine vertauschte Reihenfolge der Dateizeitstempel: `boot-9.scm` / `eval.scm` neuer als ihre `.go`-Bytecodes (ungefähr 13 Sekunden).
- Die letzte vorhandene betroffene-Maschine-Datei `Composition-Lab-LilyPond-CPU-20261021-181142.json` bestätigt den CPU-gebundenen Timeout für Minimalfall (25,801 s) und vollständige Pastorale (45,292 s). Dies ist ein **Vor-Reparatur-Protokoll**, kein fehlgeschlagener Test der automatischen neuen Korrektur.
- [Kontrollierter GitHub-Workflow 39630260666](https://github.com/wibem1/Composition-Lab-Native/actions/runs/39630260666) reproduziert auf Windows 2022 und 2025: künstlich invertierte Zeitstempel → vier Minimalproben laufen in Timeout; bestehende hashverifizierte Reparatur → Minimalprobe und vollständige Pastorale bestehen, ebenso der native 4.2.8-Selbsttest.
- [Commit 9bb762c](https://github.com/wibem1/Composition-Lab-Native/commit/9bb762c780e7dce27b813ec3d96a07c28d35f48a) integriert automatische Vorabprüfung der 374 Quell-/Bytecodepaare samt vollständiger SHA-256-Verifikation vor Änderung eines Zeitstempels. Im Windows-Build wird die schadhafte Entpack-Reihenfolge vor Quell-Build- und ZIP-Selbsttest absichtlich erzeugt.
- [Commit bfb237d](https://github.com/wibem1/Composition-Lab-Native/commit/bfb237dbeec9fff537dbf533ac1067a069b2101b) behebt einen separat nachgewiesenen Fehler in `Windows/Build.ps1`: `Get-Content` des `result.json` benötigt `-Raw | ConvertFrom-Json`; `-Raw` darf nicht an `Assert-GuileFresh` durchgereicht werden.

**Release-Entscheidung:** Der kontrollierte Kausalnachweis ist grün. Die automatisierte Korrektur ist eingecheckt, aber die endgültigen CI-Ergebnisse **nach bfb237d** sind noch nicht nachgewiesen. GitHub-Connector-Zugriff bietet in dieser Sitzung keine allgemeine Auflistung der Workflow-Runs nach Branch; `fetch_commit_workflow_runs` liefert nur PR-ausgelöste Läufe. Keine behauptete Freigabe, kein neuer Release und kein Schließen von Issue #7 ohne belegten End-to-End-Erfolg.
