@echo off
setlocal
set "CLAB_PROBE_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -Command "$s=[IO.File]::ReadAllText($env:CLAB_PROBE_SELF); & ([scriptblock]::Create($s.Substring($s.LastIndexOf('# CLAB_POWERSHELL_START'))))"
echo.
if not "%CLAB_PROBE_NO_PAUSE%"=="1" pause
exit /b
# CLAB_POWERSHELL_START
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $env:CLAB_PROBE_SELF
$exe = Join-Path $base 'LilyPond\bin\lilypond.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    Write-Host 'Bitte diese CMD-Datei in den Ordner neben Composition Lab 4.2.5.exe legen und dort starten.'
    exit 1
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('clab-starttest-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null
$report = [ordered]@{
    format = 'composition-lab-lilypond-starttest'; version = 2
    recordedAt = [DateTimeOffset]::UtcNow.ToString('O')
    windows = [Environment]::OSVersion.VersionString
    processArchitecture = $env:PROCESSOR_ARCHITECTURE
    nativeArchitecture = $env:PROCESSOR_ARCHITEW6432
    executableBytes = (Get-Item -LiteralPath $exe).Length
    executableSHA256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    probes = @()
}
function Probe([string]$name, [string]$arguments, [int]$seconds, [bool]$appEnvironment, [string]$variant) {
    Write-Host ($name + ' (maximal ' + $seconds + ' Sekunden) ...')
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $exe; $start.Arguments = $arguments
    $start.WorkingDirectory = $work
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $true
    if ($appEnvironment) {
        $start.EnvironmentVariables['FONTCONFIG_FILE'] = Join-Path $base 'LilyPond\etc\fonts\fonts.conf'
        $start.EnvironmentVariables['FONTCONFIG_PATH'] = Join-Path $base 'LilyPond\etc\fonts'
        $start.EnvironmentVariables['XDG_CACHE_HOME'] = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Klangwerke\Composition Lab 4.0\LilyPond-Cache\font-cache'
        [IO.Directory]::CreateDirectory($start.EnvironmentVariables['XDG_CACHE_HOME']) | Out-Null
    }
    if ($variant -eq 'no-jit') {
        $start.EnvironmentVariables['GUILE_JIT_THRESHOLD'] = '-1'
    }
    if ($variant -eq 'clean-environment') {
        foreach ($key in @('GUILE_LOAD_PATH','GUILE_LOAD_COMPILED_PATH','GUILE_EXTENSIONS_PATH','GUILE_AUTO_COMPILE','GUILE_JIT_THRESHOLD','GUILE_JIT_LOG','LILYPOND_DATADIR','LILYPOND_RELOCDIR','LILYPOND_LOCALEDIR')) {
            $start.EnvironmentVariables.Remove($key)
        }
        $start.EnvironmentVariables['PATH'] = "$env:SystemRoot\System32;$env:SystemRoot;$env:SystemRoot\System32\Wbem"
    }
    $p = New-Object Diagnostics.Process
    $p.StartInfo = $start
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = [ordered]@{ name=$name; arguments=$arguments; appEnvironment=$appEnvironment; variant=$variant }
    try {
        [void]$p.Start(); $p.StandardInput.Close()
        $stdout = $p.StandardOutput.ReadToEndAsync()
        $stderr = $p.StandardError.ReadToEndAsync()
        $finished = $p.WaitForExit($seconds * 1000)
        $result.timedOut = -not $finished
        if (-not $finished) {
            try { $result.cpuMilliseconds = $p.TotalProcessorTime.TotalMilliseconds } catch { }
            try { $result.loadedModules = @($p.Modules | ForEach-Object { $_.ModuleName }) } catch { $result.modulesError = $_.Exception.Message }
            & "$env:SystemRoot\System32\taskkill.exe" /PID $p.Id /T /F 2>&1 | Out-Null
            [void]$p.WaitForExit(3000)
        }
        if ($p.HasExited) { $result.exitCode = $p.ExitCode }
        foreach ($entry in @(@('stdout', $stdout), @('stderr', $stderr))) {
            $task = $entry[1]
            if ($task.Wait(3000)) {
                $text = $task.GetAwaiter().GetResult()
                if ($text.Length -gt 24000) { $text = $text.Substring(0,8000) + "`n[... gekuerzt ...]`n" + $text.Substring($text.Length-16000) }
                $result[$entry[0]] = $text
            } else { $result[$entry[0]] = '[Ausgabekanal nach Abbruch noch offen]' }
        }
    } catch { $result.error = $_.Exception.ToString() }
    finally { $watch.Stop(); $result.milliseconds=$watch.Elapsed.TotalMilliseconds; $p.Dispose() }
    Write-Host ($name + ': ' + [Math]::Round($watch.Elapsed.TotalSeconds,1) + ' Sekunden')
    return $result
}
try {
    $source = '\version "2.24.0" \score { { c\singleQuote4 d\singleQuote e\singleQuote f\singleQuote } \layout {} \midi {} }'
    $source = $source.Replace('\singleQuote', "'")
    [IO.File]::WriteAllText((Join-Path $work 'probe.ly'), $source, (New-Object Text.UTF8Encoding($false)))
    $report.probes += (Probe 'Notensatz ohne JIT' '--verbose --svg -dpoint-and-click --output=nojit probe.ly' 20 $true 'no-jit')
    $report.probes += (Probe 'Notensatz mit bereinigter Prozessumgebung' '--verbose --svg -dpoint-and-click --output=clean probe.ly' 20 $true 'clean-environment')
    $report.svgCount = @(Get-ChildItem -LiteralPath $work -Filter '*.svg').Count
    $report.midiCount = @(Get-ChildItem -LiteralPath $work -Filter '*.mid*').Count
} catch { $report.error = $_.Exception.ToString() }
finally {
    $target = Join-Path $base ('LilyPond-Starttest-2-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6) + '.json')
    [IO.File]::WriteAllText($target, ($report | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    Remove-Item -LiteralPath $work -Recurse -Force
    Write-Host ''
    Write-Host 'Fertig. Bitte diese neue JSON-Datei anhaengen:'
    Write-Host $target
}
