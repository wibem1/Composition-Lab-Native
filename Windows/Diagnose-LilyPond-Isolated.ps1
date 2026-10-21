# Reproduces the original LilyPond failure without the GUI, Swift core or MIDI import.
# Usage: pwsh -File Windows/Diagnose-LilyPond-Isolated.ps1 -DiagnosticPath "Composition-Lab-Windows-Diagnose.json" -LilyPondExe "C:\\path\\to\\LilyPond\\bin\\lilypond.exe"
param(
  [Parameter(Mandatory=$true)][string]$DiagnosticPath,
  [Parameter(Mandatory=$true)][string]$LilyPondExe,
  [string]$OutputDirectory = (Join-Path $PWD "LilyPond-Isolation"),
  [ValidateSet("inherited", "application")][string]$EnvironmentProfile = "inherited",
  [int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
if ($TimeoutSeconds -lt 5) { throw "TimeoutSeconds must be at least 5" }
$diagnostic = Get-Content -LiteralPath $DiagnosticPath -Raw -Encoding UTF8 | ConvertFrom-Json
$composition = $diagnostic.composition
if (-not $composition -and $diagnostic.sourceDiagnostic) { $composition = $diagnostic.sourceDiagnostic.composition }
if (-not $composition) { throw "Diagnostic has no original composition" }
$composition = $composition.Trim()
if ($composition -match '(?s)^\x60\x60\x60(?:lilypond|ly)?\s*\r?\n(.*?)\r?\n?\x60\x60\x60\s*$') { $composition = $Matches[1] }
if (-not $composition.Contains('\score')) { throw "Expected original LilyPond with score block; no conversion attempted" }
$exe = (Resolve-Path -LiteralPath $LilyPondExe).Path
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$dir = (Resolve-Path -LiteralPath $OutputDirectory).Path
$sourcePath = Join-Path $dir 'original.ly'
[System.IO.File]::WriteAllText($sourcePath, $composition + "`n", (New-Object System.Text.UTF8Encoding($false)))
$sha = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$version = (& $exe --version 2>&1 | Select-Object -First 1 | Out-String).Trim()
$report = [ordered]@{ sourceSha256=$sha; executable=$exe; version=$version; timeoutSeconds=$TimeoutSeconds; environmentProfile=$EnvironmentProfile; operatingSystem=[Environment]::OSVersion.VersionString; cases=@() }
foreach ($case in @(
  @{name='midi'; arguments=@('--verbose','--output=midi','original.ly')},
  @{name='svg-no-click'; arguments=@('--svg','-dno-point-and-click','--verbose','--output=svg','original.ly')},
  @{name='svg-click'; arguments=@('--svg','-dpoint-and-click','--verbose','--output=svg','original.ly')}
)) {
  $work = Join-Path $dir $case.name
  # Never accept outputs left by an earlier failed run as proof of success.
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
  New-Item -ItemType Directory -Path $work -Force | Out-Null
  Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $work 'original.ly')
  $stdout = Join-Path $work 'stdout.txt'; $stderr = Join-Path $work 'stderr.txt'
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $exe
  $start.WorkingDirectory = $work
  $start.UseShellExecute = $false
  foreach($arg in $case.arguments) { [void]$start.ArgumentList.Add($arg) }
  if ($EnvironmentProfile -eq 'application') {
    # Match LilyPondCompiler.cs exactly; never alter the user's environment.
    $bundle = Split-Path (Split-Path $exe -Parent) -Parent
    $start.Environment['FONTCONFIG_FILE'] = Join-Path $bundle 'etc/fonts/fonts.conf'
    $start.Environment['FONTCONFIG_PATH'] = Join-Path $bundle 'etc/fonts'
    $fontCache = Join-Path $dir 'font-cache'
    New-Item -ItemType Directory -Path $fontCache -Force | Out-Null
    $start.Environment['XDG_CACHE_HOME'] = $fontCache
  }
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $start
  # Drain stdout and stderr concurrently to avoid process-pipe deadlocks.
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  [void]$process.Start()
  $outTask = $process.StandardOutput.ReadToEndAsync()
  $errTask = $process.StandardError.ReadToEndAsync()
  $finished = $process.WaitForExit($TimeoutSeconds * 1000)
  $cpuMs = $null; $memory = $null
  try { $cpuMs = [Math]::Round($process.TotalProcessorTime.TotalMilliseconds); $memory=$process.WorkingSet64 } catch {}
  if (-not $finished) { try { $process.Kill($true) } catch {}; try { $process.WaitForExit(3000) | Out-Null } catch {} }
  try { [System.Threading.Tasks.Task]::WaitAll(@($outTask,$errTask), 3000) | Out-Null } catch {}
  $stopwatch.Stop()
  [System.IO.File]::WriteAllText($stdout, $(if($outTask.IsCompletedSuccessfully){$outTask.Result}else{'<output incomplete>'}))
  [System.IO.File]::WriteAllText($stderr, $(if($errTask.IsCompletedSuccessfully){$errTask.Result}else{'<output incomplete>'}))
  $outputs = @(Get-ChildItem -Path $work -File | Where-Object { $_.Extension -in @('.midi','.mid','.svg') } | Select-Object -ExpandProperty Name)
  $expectedExtension = if ($case.name -eq "midi") { @(".midi",".mid") } else { @(".svg") }
  $hasExpectedOutput = @($outputs | Where-Object { $name = $_; @($expectedExtension | Where-Object { $name.EndsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 }).Count -gt 0
  $report.cases += [ordered]@{ name=$case.name; hasExpectedOutput=$hasExpectedOutput; timedOut=(-not $finished); exitCode=$(if($finished){$process.ExitCode}else{$null}); elapsedMilliseconds=[Math]::Round($stopwatch.Elapsed.TotalMilliseconds); cpuMilliseconds=$cpuMs; memoryBytes=$memory; outputs=$outputs; stdout=$stdout; stderr=$stderr }
  $process.Dispose()
}
$reportPath = Join-Path $dir 'report.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
Write-Output "Isolation report: $reportPath"
Get-Content -LiteralPath $reportPath
if (@($report.cases | Where-Object { $_.timedOut -or $_.exitCode -ne 0 -or -not $_.hasExpectedOutput }).Count) { exit 2 }
