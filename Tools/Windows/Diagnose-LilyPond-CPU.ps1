# Standalone Windows diagnosis; does not modify the installation or invoke AI.
param(
    [Parameter(Mandatory=$true)][string]$AppFolder,
    [string]$DiagnosticJson = '',
    [string]$ReportPath = ''
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $AppFolder).Path
$exe = Join-Path $root 'LilyPond\bin\lilypond.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "No bundled LilyPond: $exe" }
if (-not $ReportPath) { $ReportPath = Join-Path ([Environment]::GetFolderPath('Desktop')) ("Composition-Lab-LilyPond-CPU-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json") }
$report = [ordered]@{ version=1; recordedAt=[DateTimeOffset]::UtcNow.ToString('o'); appFolder=$root; lilyPond=$exe; diagnosticInput=([bool]$DiagnosticJson); experiments=@() }
$work = Join-Path ([IO.Path]::GetTempPath()) ('clab-phase-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null
function Run-Probe([string]$name,[string]$source,[string[]]$options,[int]$seconds) {
    $folder=Join-Path $work $name
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    if ($source) { [IO.File]::WriteAllText((Join-Path $folder 'probe.ly'),$source,(New-Object Text.UTF8Encoding($false))) }
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $exe
    $start.WorkingDirectory=$folder
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardError=$true; $start.RedirectStandardOutput=$true
    $start.EnvironmentVariables['FONTCONFIG_FILE']=Join-Path $root 'LilyPond\etc\fonts\fonts.conf'
    $start.EnvironmentVariables['FONTCONFIG_PATH']=Join-Path $root 'LilyPond\etc\fonts'
    $start.EnvironmentVariables['XDG_CACHE_HOME']=Join-Path $folder 'cache'
    [IO.Directory]::CreateDirectory((Join-Path $folder 'cache')) | Out-Null
    $start.Arguments=($options | ForEach-Object { $_ }) -join ' '
    $p=New-Object Diagnostics.Process
    $p.StartInfo=$start
    $samples=@()
    try {
        [void]$p.Start()
        # Stream drains begin before waiting, avoiding full pipes blocking the child.
        $stderr=$p.StandardError.ReadToEndAsync()
        $stdout=$p.StandardOutput.ReadToEndAsync()
        $clock=[Diagnostics.Stopwatch]::StartNew()
        while (-not $p.HasExited -and $clock.Elapsed.TotalSeconds -lt $seconds) {
            Start-Sleep -Milliseconds 500
            try { $p.Refresh(); $samples+= [ordered]@{ elapsedMs=[int]$clock.Elapsed.TotalMilliseconds; cpuMs=[int]$p.TotalProcessorTime.TotalMilliseconds; workingSetBytes=$p.WorkingSet64 } } catch { }
        }
        $timedOut=(-not $p.HasExited)
        if ($timedOut) {
            & "$env:SystemRoot\System32\taskkill.exe" /PID $p.Id /T /F 2>$null | Out-Null
        }
        try { [void]$p.WaitForExit(3000) } catch { }
        $clock.Stop()
        $errText='<output stream not drained>'; $outText='<output stream not drained>'
        try { if ($stderr.Wait(3000)) { $errText=$stderr.Result } } catch {}
        try { if ($stdout.Wait(3000)) { $outText=$stdout.Result } } catch {}
        $outputs = @(Get-ChildItem -LiteralPath $folder -File | Where-Object { $_.Extension -in @('.svg','.mid','.midi') } | ForEach-Object { $_.Name })
        $item=[ordered]@{ name=$name; elapsedMs=[int]$clock.Elapsed.TotalMilliseconds; timedOut=$timedOut; exitCode=$(if($p.HasExited){$p.ExitCode}else{$null}); samples=$samples; stderr=$errText.Substring(0,[Math]::Min(12000,$errText.Length)); stdout=$outText.Substring(0,[Math]::Min(3000,$outText.Length)); outputs=$outputs }
        $report.experiments += $item
        Write-Host ("{0}: {1} ms; timeout={2}; outputs={3}" -f $name,$item.elapsedMs,$timedOut,($outputs -join ','))
    } finally { $p.Dispose() }
}
try {
    $minimal='\version "2.24.0" \score { { c\x274 d\x274 e\x274 f\x274 } \layout {} \midi {} }'
    $minimal=$minimal.Replace('\x27',"'")
    Run-Probe '01-version' '' @('--version') 12
    Run-Probe '02-minimal' $minimal @('--svg','-dpoint-and-click','--loglevel=INFO','--output=probe','probe.ly') 25
    if ($DiagnosticJson) {
        $diag=Get-Content -LiteralPath $DiagnosticJson -Raw | ConvertFrom-Json
        $music=[string]$diag.composition
        $music=[regex]::Replace($music,'^\s*```(?:lilypond|ly)\s*','',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $music=[regex]::Replace($music,'\s*```\s*$','')
        if ($music -notmatch '\\score\s*\{') { throw 'Diagnostic does not contain LilyPond score' }
        Run-Probe '03-original' $music @('--svg','-dpoint-and-click','--loglevel=INFO','--output=probe','probe.ly') 35
    }
} catch { $report.error=$_.Exception.ToString() }
finally {
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host "Diagnostic saved: $ReportPath"
    try { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}
