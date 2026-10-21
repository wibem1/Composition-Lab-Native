$ErrorActionPreference = 'Stop'
$root = $PWD.Path
$reportRoot = Join-Path $root 'RuntimeReports'
New-Item $reportRoot -ItemType Directory -Force | Out-Null
Invoke-WebRequest 'https://gitlab.com/lilypond/lilypond/-/releases/v2.24.4/downloads/lilypond-2.24.4-mingw-x86_64.zip' -OutFile runtime.zip
if ((Get-FileHash runtime.zip -Algorithm SHA256).Hash -ne 'E238F5A33EBDE7466FE03D0FBCAA155A44536CA582951972482E0B00CEB0FBF1') { throw 'Runtime checksum mismatch' }
Expand-Archive runtime.zip OriginalRuntime
Copy-Item OriginalRuntime/lilypond-2.24.4 CandidateRuntime -Recurse
Copy-Item RuntimeCandidate/*.dll CandidateRuntime/bin -Force
Copy-Item OriginalRuntime/lilypond-2.24.4 ControlRuntime -Recurse
Copy-Item RuntimeControl/*.dll ControlRuntime/bin -Force
$summary = [Collections.Generic.List[object]]::new()
# Stress keys belong only to this disposable runner and are removed in finally.
$stressRoot = 'HKCU:\Software\Classes'
$keys = [Collections.Generic.List[string]]::new()
try {
    foreach ($phase in @('clean','many-applications')) {
        if ($phase -eq 'many-applications') {
            for ($i=0; $i -lt 1000; $i++) {
                $key = "$stressRoot\CompositionLabStartupTest.$i"
                $keys.Add($key)
                New-Item "$key\shell\open\command" -Force | Out-Null
                Set-Item "$key\shell\open\command" '"C:\Program Files\Composition Lab Startup Test\test.exe" "%1"'
            }
        }
        foreach ($variant in @('original','rebuilt-control','lazy-appinfo')) {
            $bundle = if ($variant -eq 'original') { Join-Path $root 'OriginalRuntime/lilypond-2.24.4' } elseif ($variant -eq 'rebuilt-control') { Join-Path $root 'ControlRuntime' } else { Join-Path $root 'CandidateRuntime' }
            for ($run=0; $run -lt 3; $run++) {
                $work = Join-Path $reportRoot "$phase-$variant-$run-Noten Übung"
                New-Item $work -ItemType Directory -Force | Out-Null
                $source = '\version "2.24.0" \score { \new PianoStaff << \new Staff { \tempo 4 = 90 \repeat unfold 24 { c\singleQuote4 d\singleQuote e\singleQuote f\singleQuote } } \new Staff { \clef bass \repeat unfold 24 { c4 g c g } } >> \layout {} \midi {} }'
                [IO.File]::WriteAllText((Join-Path $work 'source.ly'), $source.Replace('\singleQuote', "'"), [Text.UTF8Encoding]::new($false))
                $start = [Diagnostics.ProcessStartInfo]::new((Join-Path $bundle 'bin/lilypond.exe'))
                $start.WorkingDirectory = $work
                $start.UseShellExecute = $false; $start.CreateNoWindow = $true
                $start.RedirectStandardError = $true; $start.RedirectStandardOutput = $true
                foreach ($arg in @('--verbose','--svg','-dpoint-and-click','--output=score','source.ly')) { $start.ArgumentList.Add($arg) }
                $start.Environment['FONTCONFIG_FILE'] = Join-Path $bundle 'etc/fonts/fonts.conf'
                $start.Environment['FONTCONFIG_PATH'] = Join-Path $bundle 'etc/fonts'
                $start.Environment['XDG_CACHE_HOME'] = Join-Path $work 'font-cache'
                $start.Environment['PATH'] = "$env:windir\System32;$env:windir"
                $p = [Diagnostics.Process]::new(); $p.StartInfo = $start
                $watch = [Diagnostics.Stopwatch]::StartNew()
                [void]$p.Start()
                $stdout = $p.StandardOutput.ReadToEndAsync(); $stderr = $p.StandardError.ReadToEndAsync()
                $finished = $p.WaitForExit(45000)
                if (-not $finished) { $p.Kill($true); [void]$p.WaitForExit(3000) }
                $watch.Stop()
                $log = $stderr.GetAwaiter().GetResult() + $stdout.GetAwaiter().GetResult()
                [IO.File]::WriteAllText((Join-Path $work 'compile.log'), $log)
                $pages = @(Get-ChildItem $work -Filter 'score*.svg')
                $midi = @(Get-ChildItem $work -Filter 'score*.midi')
                $valid = $finished -and $p.ExitCode -eq 0 -and $pages.Count -gt 0 -and $midi.Count -eq 1
                if ($valid) {
                    $bytes = [IO.File]::ReadAllBytes($midi[0].FullName)
                    $valid = $bytes.Length -gt 14 -and [Text.Encoding]::ASCII.GetString($bytes,0,4) -eq 'MThd'
                    foreach ($page in $pages) { $valid = $valid -and ([IO.File]::ReadAllText($page.FullName).Contains('textedit:')) }
                }
                $entry = [ordered]@{phase=$phase;variant=$variant;run=$run;passed=$valid;timedOut=(-not $finished);milliseconds=$watch.Elapsed.TotalMilliseconds;exitCode=$p.ExitCode;pages=$pages.Count;cpuMilliseconds=$p.TotalProcessorTime.TotalMilliseconds}
                $summary.Add($entry); $entry | ConvertTo-Json -Compress | Write-Output
                $summary | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $reportRoot 'comparison.json')
                $p.Dispose()
            }
        }
    }
} finally { foreach ($key in $keys) { Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue } }
if (@($summary | Where-Object { $_.variant -eq 'lazy-appinfo' -and -not $_.passed }).Count -gt 0) { throw 'Candidate runtime failed; do not integrate or release' }
# Passing this experiment is deliberately insufficient to trigger a product release.
