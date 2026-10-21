$ErrorActionPreference = 'Stop'
$encodedManifest = '@@MANIFEST@@'
$bytes = [Convert]::FromBase64String($encodedManifest)
$inputStream = New-Object IO.MemoryStream(,$bytes)
$gzip = New-Object IO.Compression.GZipStream($inputStream, [IO.Compression.CompressionMode]::Decompress)
$reader = New-Object IO.StreamReader($gzip, [Text.Encoding]::UTF8)
$manifest = $reader.ReadToEnd() | ConvertFrom-Json
$reader.Dispose()
$base = Split-Path -Parent $env:CLAB_REPAIR_SELF
$candidates = @($env:CLAB_REPAIR_TARGET, $base, (Join-Path $base 'Composition Lab 4.2.7'), (Join-Path $base 'Composition-Lab-4.2.7-Windows-x64/Composition Lab 4.2.7'), (Join-Path $env:USERPROFILE 'Downloads/Composition-Lab-4.2.7-Windows-x64/Composition Lab 4.2.7'))
$target = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'LilyPond/bin/lilypond.exe')) } | Select-Object -First 1
if (-not $target) { throw 'Ordner nicht gefunden. Diese CMD-Datei neben Composition Lab 4.2.7.exe legen und erneut starten.' }
$runtime = Join-Path $target 'LilyPond'
$report = [ordered]@{format='composition-lab-runtime-repair';version=1;recordedAt=[DateTimeOffset]::UtcNow.ToString('O');target=$target;verifiedPairs=0;repairedPairs=0;examples=@();passed=$false}
$work = $null
try {
    Write-Host 'Pruefe die Originaldateien von LilyPond und Guile ...'
    # Validate every byte first. Never make modified source look compatible with old bytecode.
    foreach ($pair in $manifest.pairs) {
        foreach ($entry in @(@($pair.source,$pair.sourceSHA256), @($pair.compiled,$pair.compiledSHA256))) {
            $path = Join-Path $runtime $entry[0]
            if (-not (Test-Path -LiteralPath $path)) { throw ('Mitgelieferte Datei fehlt: ' + $entry[0]) }
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry[1]) { throw ('Dateiinhalt weicht vom geprueften Original ab: ' + $entry[0]) }
        }
        $report.verifiedPairs++
    }
    foreach ($pair in $manifest.pairs) {
        $source = Get-Item -LiteralPath (Join-Path $runtime $pair.source)
        $compiled = Get-Item -LiteralPath (Join-Path $runtime $pair.compiled)
        if ($compiled.LastWriteTimeUtc -le $source.LastWriteTimeUtc.AddSeconds(2)) {
            if ($report.examples.Count -lt 20) { $report.examples += [ordered]@{source=$pair.source;compiled=$pair.compiled;sourceUtc=$source.LastWriteTimeUtc.ToString('O');compiledBeforeUtc=$compiled.LastWriteTimeUtc.ToString('O')} }
            # Four seconds also survives the two-second DOS ZIP timestamp resolution.
            $compiled.LastWriteTimeUtc = $source.LastWriteTimeUtc.AddSeconds(4)
            if ((Get-Item -LiteralPath $compiled.FullName).LastWriteTimeUtc -le $source.LastWriteTimeUtc) { throw ('Zeitstempel nicht korrigierbar: ' + $pair.compiled) }
            $report.repairedPairs++
        }
    }
    Write-Host ('Geprueft: ' + $report.verifiedPairs + ' Dateipaare; Zeitstempel korrigiert: ' + $report.repairedPairs)
    Write-Host 'Pruefe lokalen Notensatz mit vier Testnoten (maximal 25 Sekunden) ...'
    $work = Join-Path ([IO.Path]::GetTempPath()) ('clab-runtime-repair-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($work) | Out-Null
    $source = '\version "2.24.0" \score { { c\singleQuote4 d\singleQuote e\singleQuote f\singleQuote } \layout {} \midi {} }'
    [IO.File]::WriteAllText((Join-Path $work 'probe.ly'), $source.Replace('\singleQuote', "'"), (New-Object Text.UTF8Encoding($false)))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = Join-Path $runtime 'bin/lilypond.exe'
    $start.Arguments = '--svg -dpoint-and-click --loglevel=INFO --output=probe probe.ly'
    $start.WorkingDirectory = $work; $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $start.EnvironmentVariables['FONTCONFIG_FILE'] = Join-Path $runtime 'etc/fonts/fonts.conf'
    $start.EnvironmentVariables['FONTCONFIG_PATH'] = Join-Path $runtime 'etc/fonts'
    $p = New-Object Diagnostics.Process; $p.StartInfo=$start
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        [void]$p.Start()
        $stdout=$p.StandardOutput.ReadToEndAsync(); $stderr=$p.StandardError.ReadToEndAsync()
        $finished=$p.WaitForExit(25000)
        if (-not $finished) { & "$env:SystemRoot/System32/taskkill.exe" /PID $p.Id /T /F 2>&1 | Out-Null; [void]$p.WaitForExit(3000) }
        $watch.Stop(); $report.milliseconds=$watch.Elapsed.TotalMilliseconds; $report.timedOut=(-not $finished)
        if ($p.HasExited) { $report.exitCode=$p.ExitCode }
        if ($stderr.Wait(2000) -and $stdout.Wait(2000)) { $report.log=$stderr.GetAwaiter().GetResult()+$stdout.GetAwaiter().GetResult() }
        $midis=@(Get-ChildItem -LiteralPath $work -Filter 'probe.mid*' | Where-Object { $_.Extension -in @('.mid','.midi') })
        $pages=@(Get-ChildItem -LiteralPath $work -Filter 'probe*.svg')
        $report.passed=$finished -and $p.ExitCode -eq 0 -and $midis.Count -eq 1 -and $pages.Count -gt 0 -and $report.log -notmatch 'newer than compiled'
        if ($report.passed) { $data=[IO.File]::ReadAllBytes($midis[0].FullName); $report.passed=$data.Length -gt 14 -and [Text.Encoding]::ASCII.GetString($data,0,4) -eq 'MThd' }
    } finally { $p.Dispose() }
} catch { $report.error=$_.Exception.ToString() }
finally {
    $output=$env:CLAB_REPAIR_REPORT
    if (-not $output) { $output=Join-Path $target ('LilyPond-Reparatur-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json') }
    [IO.File]::WriteAllText($output, ($report | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    if ($work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ('Protokoll: ' + $output)
}
if ($report.passed) { Write-Host 'Lokaler Notensatz funktioniert. Composition Lab jetzt erneut starten.'; exit 0 }
Write-Host 'Pruefung fehlgeschlagen. Bitte die neue Reparatur-JSON-Datei anhaengen.'
exit 1
