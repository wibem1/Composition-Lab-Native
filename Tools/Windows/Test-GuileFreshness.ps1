$ErrorActionPreference='Stop'
$root=$PWD.Path
New-Item FreshnessResults -ItemType Directory -Force | Out-Null
Invoke-WebRequest 'https://github.com/wibem1/Composition-Lab-Native/releases/download/v4.2.7/Composition-Lab-4.2.7-Windows-x64.zip' -OutFile Native.zip
if ((Get-FileHash Native.zip -Algorithm SHA256).Hash -ne 'C39B3A593DBBDA00FDAA80B4589807399AF42E796EE459286EE9F15F6578F0A3') { throw 'Released package checksum mismatch' }
Expand-Archive Native.zip Native
$app=Join-Path $root 'Native/Composition Lab 4.2.7'
$runtime=Join-Path $app 'LilyPond'
$manifest=Get-Content Windows/LilyPond-Runtime-Manifest.json -Raw | ConvertFrom-Json
# Keep every other cache fresh and reproduce exactly the twelve library paths
# reported by the user's diagnostic. No file contents are modified.
$staleSources=@(
    'share/guile/2.2/ice-9/eval.scm',
    'share/lilypond/2.24.4/scm/lily/lily.scm',
    'share/lilypond/2.24.4/scm/lily/clip-region.scm',
    'share/lilypond/2.24.4/scm/lily/curried-definitions.scm',
    'share/lilypond/2.24.4/scm/lily/lily-library.scm',
    'share/lilypond/2.24.4/scm/lily/output-lib.scm',
    'share/lilypond/2.24.4/scm/lily/markup-macros.scm',
    'share/lilypond/2.24.4/scm/lily/parser-ly-from-scheme.scm',
    'share/lilypond/2.24.4/scm/lily/file-cache.scm',
    'share/lilypond/2.24.4/scm/lily/define-event-classes.scm',
    'share/lilypond/2.24.4/scm/lily/define-music-callbacks.scm',
    'share/lilypond/2.24.4/scm/lily/define-music-types.scm'
)
$t=[datetime]::SpecifyKind([datetime]'2026-01-01T00:00:00',[DateTimeKind]::Utc)
$stalePairs=0
foreach ($pair in $manifest.pairs) {
    $source=Get-Item (Join-Path $runtime $pair.source)
    (Get-Item (Join-Path $runtime $pair.compiled)).LastWriteTimeUtc=$source.LastWriteTimeUtc.AddDays(1)
    if ($pair.source -in $staleSources) {
        $source.LastWriteTimeUtc=$t
        (Get-Item (Join-Path $runtime $pair.compiled)).LastWriteTimeUtc=$t.AddDays(-1)
        $stalePairs++
    }
}
if ($stalePairs -ne 12) { throw 'The exact reported stale library set is not represented' }
$work=Join-Path $root 'FreshnessResults/Baseline'
New-Item $work -ItemType Directory -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $work 'probe.ly'), '\version "2.24.0" \score { { c4 d e f } \layout {} \midi {} }')
$s=[Diagnostics.ProcessStartInfo]::new((Join-Path $runtime 'bin/lilypond.exe'))
$s.WorkingDirectory=$work; $s.UseShellExecute=$false; $s.CreateNoWindow=$true
$s.RedirectStandardOutput=$true; $s.RedirectStandardError=$true
$s.Arguments='--svg --loglevel=INFO --output=probe probe.ly'
$s.Environment['FONTCONFIG_FILE']=Join-Path $runtime 'etc/fonts/fonts.conf'
$s.Environment['FONTCONFIG_PATH']=Join-Path $runtime 'etc/fonts'
$p=[Diagnostics.Process]::new();$p.StartInfo=$s;$watch=[Diagnostics.Stopwatch]::StartNew()
[void]$p.Start();$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
$finished=$p.WaitForExit(25000)
$cpu=$p.TotalProcessorTime.TotalMilliseconds
if (-not $finished) { $p.Kill($true);[void]$p.WaitForExit(3000) }
$watch.Stop();$log=$stderr.GetAwaiter().GetResult()+$stdout.GetAwaiter().GetResult()
$baseline=[ordered]@{timedOut=(-not $finished);exitCode=$p.ExitCode;milliseconds=$watch.Elapsed.TotalMilliseconds;cpuMilliseconds=$cpu;stalePairs=$stalePairs;cacheWarning=($log -match 'newer than compiled');svgCount=@(Get-ChildItem $work -Filter '*.svg').Count}
$baseline | ConvertTo-Json | Set-Content FreshnessResults/baseline.json
$log | Set-Content FreshnessResults/baseline.log
$p.Dispose()
$baseline | ConvertTo-Json | Write-Output
if (($finished -and $baseline.exitCode -eq 0) -or $baseline.svgCount -gt 0) { throw 'Did not reproduce an unusable renderer; no repair release based on this test' }
# Run the very same single CMD that the user will run, using Windows PowerShell 5.1.
$env:CLAB_REPAIR_NO_PAUSE='1';$env:CLAB_REPAIR_TARGET=$app
$env:CLAB_REPAIR_REPORT=Join-Path $root 'FreshnessResults/repaired.json'
& $env:ComSpec /c Windows\LilyPond-Reparatur.cmd
if ($LASTEXITCODE -ne 0) { Get-Content $env:CLAB_REPAIR_REPORT; throw 'Repair CMD did not restore local notation' }
$repaired=Get-Content $env:CLAB_REPAIR_REPORT -Raw | ConvertFrom-Json
if (-not $repaired.passed -or $repaired.repairedPairs -ne $stalePairs) { throw 'Repair did not cover exactly the known bundled pairs' }
$env:CLAB_REPAIR_REPORT=Join-Path $root 'FreshnessResults/repeated.json'
& $env:ComSpec /c Windows\LilyPond-Reparatur.cmd
if ($LASTEXITCODE -ne 0) { throw 'Repaired runtime not stable on repeat' }
$repeated=Get-Content $env:CLAB_REPAIR_REPORT -Raw | ConvertFrom-Json
if ($repeated.repairedPairs -ne 0) { throw 'Repair is not idempotent' }
# Refuse edited source without making any metadata changes.
$first=$manifest.pairs[0];$last=$manifest.pairs[-1]
(Get-Item (Join-Path $runtime $first.compiled)).LastWriteTimeUtc=$t.AddDays(-1)
$oldDate=(Get-Item (Join-Path $runtime $first.compiled)).LastWriteTimeUtc
Add-Content (Join-Path $runtime $last.source) '; changed test source'
$env:CLAB_REPAIR_REPORT=Join-Path $root 'FreshnessResults/modified-source-rejected.json'
& $env:ComSpec /c Windows\LilyPond-Reparatur.cmd
if ($LASTEXITCODE -eq 0 -or (Get-Item (Join-Path $runtime $first.compiled)).LastWriteTimeUtc -ne $oldDate) { throw 'Edited library accepted or metadata partially changed before full validation' }
[ordered]@{passed=$true;baseline=$baseline;repairedMilliseconds=$repaired.milliseconds;repeatMilliseconds=$repeated.milliseconds;verifiedPairs=$repaired.verifiedPairs;repairedPairs=$repaired.repairedPairs;modifiedSourceRejected=$true} | ConvertTo-Json -Depth 4 | Tee-Object -FilePath FreshnessResults/result.json
