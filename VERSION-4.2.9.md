# Composition Lab Native Windows v4.29 (4.2.9) — verification, 21 October 2026

## Corrected build blockers

- The existing release workflow failed before application tests because setup-swift rejected version 6.0.
- Architecture gates failed because Windows packaging was 4.2.9 while Mac metadata, core and Windows diagnostic/title version remained 4.2.6.
- Commit 11c8b416 aligns version/build metadata and uses the pinned Windows Swift 6.1.2 setup.
- Commit 1baaaab supplies Actions read permission for the reusable quality workflow.
- The additional Windows rebuild lacked the test fixture environment variable. Commit ff75faa uses the exact ZIP and evidence already produced by the same run's complete regression job rather than rebuilding a different package at publication.

## Required release chain

The release workflow waits for all Mac/Linux/Windows regression jobs. The Windows regression builds the actual self-contained desktop application, runs native tests with deliberately inverted Guile timestamps, creates the ZIP, extracts it and repeats the native tests and 374-pair repair checks with a toolchain-free PATH. Publication downloads that exact ZIP and matching test reports from the same workflow run and checks the reports before publishing. The release tag explicitly targets the tested workflow SHA.

## First full native evidence

Workflow: https://github.com/wibem1/Composition-Lab-Native/actions/runs/39663674103

Tested commit: 1baaaab987bd58309dda0959c7848d36500b3acb

All three regression jobs passed. Mac and Windows each passed 51 core tests. The Mac Universal application build and native self-test passed.

The Windows-Starttest artifact (12376917445) was downloaded and inspected:

| Check | Native bundle | Extracted ZIP |
| --- | --- | --- |
| result.json | passed, version 4.2.9, 39 test areas | passed, version 4.2.9, 39 test areas |
| Pastorale cold engraving | 9878.4356 ms | 9903.5303 ms |
| SVG pages | 2 | 2 |
| Repeat uses cache | true | true |
| Guile repair | passed, 374 pairs | passed, 374 pairs |
| Simulated broken extraction | true | true |

The native test validates both instruments (violin and cello), duration through all 46 bars, document import, preview data, original MIDI preservation and exports.

The original fixture, shared test fixture, native exported Pastorale.ly and extracted-ZIP exported Pastorale.ly all have SHA-256:

`46b79c95ec582b1ff4143f9ada97d2f3bf7b9dbed5cb9d6618c0459342768de5`

The first additional release-job rebuild failed in the test harness because its fixture path environment variable was absent. No release was published from that failed run. The application regression and package repair results above remained successful.

## Final release verification

Final workflow: https://github.com/wibem1/Composition-Lab-Native/actions/runs/39665569971 — SUCCESS.

Release commit: ff75faa9dd638b11c823855f051bba8d13eee354.

All three regression jobs passed again. The final publication job downloaded the Windows ZIP and both native report sets from that same run, passed the explicit Pastorale/374-pair evidence gate, and published v4.2.9 at 22:00:56 CEST on 21 October 2026. The extracted package processed Pastorale in 8181.3047 ms, produced two SVG pages and passed the repeated-cache check.

Published release: https://github.com/wibem1/Composition-Lab-Native/releases/tag/v4.2.9

Windows download: https://github.com/wibem1/Composition-Lab-Native/releases/download/v4.2.9/Composition-Lab-4.2.9-Windows-x64.zip

ZIP size: 141618646 bytes.

SHA-256: `0b273f143fc1ce73f4c1c0c4aa6b04478e96d226bec7bb08e2dbfbfd08228459`.

No manual application tests were requested. No new features were added. The user-facing release name is v4.29; its existing semantic package version remains 4.2.9.
