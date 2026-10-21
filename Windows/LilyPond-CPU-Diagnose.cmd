@echo off
setlocal
set "CLAB_CPU_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -Command "$s=[IO.File]::ReadAllText($env:CLAB_CPU_SELF); & ([scriptblock]::Create($s.Substring($s.LastIndexOf('# CLAB_POWERSHELL_START'))))"
echo.
pause
exit /b
# CLAB_POWERSHELL_START
$ErrorActionPreference = 'Stop'
# PowerShell 7 callers can pass an incompatible PSModulePath to Windows
# PowerShell 5.1. Use its own built-in modules for a reproducible diagnostic.
$env:PSModulePath = Join-Path $PSHOME 'Modules'
$root = Split-Path -Parent $env:CLAB_CPU_SELF
$DiagnosticJson = ''
$ReportPath = ''
$exe = Join-Path $root 'LilyPond\bin\lilypond.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "No bundled LilyPond: $exe" }
if (-not $ReportPath) { $ReportPath = Join-Path ([Environment]::GetFolderPath('Desktop')) ("Composition-Lab-LilyPond-CPU-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json") }
$report = [ordered]@{ version=2; windows=[Environment]::OSVersion.VersionString; executableSHA256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash; recordedAt=[DateTimeOffset]::UtcNow.ToString('o'); appFolder=$root; lilyPond=$exe; diagnosticInput=([bool]$DiagnosticJson); experiments=@() }
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
        $item=[ordered]@{ name=$name; elapsedMs=[int]$clock.Elapsed.TotalMilliseconds; timedOut=$timedOut; exitCode=$(if($p.HasExited){$p.ExitCode}else{$null}); samples=$samples; stderr=$errText; stdout=$outText; outputs=$outputs }
        $report.experiments += $item
        Write-Host ("{0}: {1} ms; timeout={2}; outputs={3}" -f $name,$item.elapsedMs,$timedOut,($outputs -join ','))
    } finally { $p.Dispose() }
}
try {
    $minimal='\version "2.24.0" \score { { c\x274 d\x274 e\x274 f\x274 } \layout {} \midi {} }'
    $minimal=$minimal.Replace('\x27',"'")
    Run-Probe '01-version' '' @('--version') 12
    Run-Probe '02-minimal' $minimal @('--svg','-dpoint-and-click','--verbose','--output=probe','probe.ly') 25
    $original=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('XHZlcnNpb24gIjIuMjQuMCIKClxoZWFkZXIgewogIHRpdGxlID0gIlBhc3RvcmFsZSIKICBzdWJ0aXRsZSA9ICJmw7xyIFZpb2xpbmUgdW5kIFZpb2xvbmNlbGxvIgogIGNvbXBvc2VyID0gIktvbXBvc2l0aW9uIGltIGtsYXNzaXNjaGVuIFN0aWwiCiAgdGFnbGluZSA9ICMjZgp9CgpnbG9iYWwgPSB7CiAgXGtleSBmIFxtYWpvcgogIFx0aW1lIDYvOAogIFx0ZW1wbyAiQW5kYW50ZSBwYXN0b3JhbGUiIDQuID0gNTIKfQoKdmlvbGluTXVzaWMgPSBccmVsYXRpdmUgYycgewogIFxnbG9iYWwKICBcY2xlZiB0cmVibGUKCiAgJSAtLS0gVEVJTCBBOiBTYW5mdGUgSGlydGVubWVsb2RpZSAtLS0KICAlIFQuIDEtNDogVGhlbWEgMSAocCwgZG9sY2UpCiAgZjQoXHBeXG1hcmt1cCB7IFxpdGFsaWMgImRvbGNlIGUgY2FudGFiaWxlIiB9IGE4IGM0IGE4IHwKICBkNCBjOCBhNCBmOCB8CiAgZzQgYTggYmVzNCBnOCB8CiAgYTQufiBhNCkgcjggfAoKICAlIFQuIDUtODogV2VpdGVyZsO8aHJ1bmcgdW5kIEF1ZnNjaHd1bmcKICBmNCggYTggYzQgZjggfAogIGU0IGQ4IGM0IGE4IHwKICBiZXM0XDwgZDggZyw0IGJlczggfAogIGE0Llw+IGc0KSByOFwhIHwKCiAgJSBULiA5LTEyOiBUaGVtYSBpbiBow7ZoZXJlciBMYWdlCiAgYSc0KFxtZiBjOCBmNCBjOCB8CiAgZDQgYzggYTQgZjggfAogIGc0XD4gYTggYmVzOCBhIGcgfAogIGE0Ln4gYTQpXHAgcjggfAoKICAlIFQuIDEzLTE2OiBLYWRlbnppZXJ1bmcgenVyIERvbWluYW50ZQogIGI0KFw8IGM4IGQ0IGI4IHwKICBjNFwhIGE4IGY0IGQ4IHwKICBjNFw+IGY4IGU0IGQ4IHwKICBjNC5+IGM0KVxwIHI4IFxiYXIgInx8IgoKICAlIC0tLSBURUlMIEI6IFJvbGxlbnRhdXNjaCAoVmlvbGluZSBmaWd1cmllcnQsIENlbGxvIHNpbmd0KSAtLS0KICAlIFQuIDE3LTIwOiBGbGllw59lbmRlIEJlZ2xlaXR1bmcgaW4gRi1EdXIgLyBCLUR1cgogIHI4XlxtYXJrdXAgeyBcaXRhbGljICJsZWdnaWVybyIgfSBjKFxwIGYgYSBmIGMpIHwKICByOCBkKCBmIGJlcyBmIGQpIHwKICByOCBjKCBmIGEgZiBjKSB8CiAgcjggYyggZSBnIGUgYykgfAoKICAlIFQuIDIxLTI0OiBNb2R1bGF0aW9uIG5hY2ggZC1Nb2xsCiAgcjggZCggZiBhIGYgZCkgfAogIHI4IGQoXDwgZyBiZXMgZyBkKVwhIHwKICByOCBkKCBmIGEgZiBkKSB8CiAgcjggY2lzKFw+IGUgYSBlIGNpcylcISB8CgogICUgVC4gMjUtMjg6IFLDvGNrZsO8aHJ1bmcgdW5kIFZlcmRpY2h0dW5nCiAgcjggZChccCBmIGJlcyBmIGQpIHwKICByOCBjKCBmIGEgZiBjKSB8CiAgcjggYmVzKCBkIGcgZCBiZXMpIHwKICByOCBjKFw8IGUgYmVzJyBnIGUpXCEgfAoKICAlIFQuIDI5LTMyOiDDnGJlcmxlaXR1bmcgenVyIFJlcHJpc2UKICBjJzgoXG1mIGEgZiBjJyBhIGYpIHwKICBkJyggYmVzIGYgZCcgYmVzIGYpIHwKICBjJyhcPiBhIGYgZSBnIGJlcyB8CiAgYTggZyBmIGUgZCBjKVwhIFxiYXIgInx8IgoKICAlIC0tLSBURUlMIEEnOiBSZXByaXNlIC0tLQogICUgVC4gMzMtMzY6IEhhdXB0dGhlbWEKICBmNChccF5cbWFya3VwIHsgXGl0YWxpYyAidGVtcG8gcHJpbW8sIGRvbGNlIiB9IGE4IGM0IGE4IHwKICBkNCBjOCBhNCBmOCB8CiAgZzQgYTggYmVzNCBnOCB8CiAgYTQufiBhNCkgcjggfAoKICAlIFQuIDM3LTQwOiBMeXJpc2NoZSBTdGVpZ2VydW5nIHp1bSBIw7ZoZXB1bmt0CiAgYTQoXDwgYzggZjQgYTggfAogIGc0XCEgZjggZDQgYmVzOCB8CiAgYTQgYzggXGdyYWNlIHsgZDE2KCB9IGM4KVw+IGJlcyBnIHwKICBmNC5+IGY0XCEgcjggfAoKICAlIC0tLSBDT0RBOiBGcmllZGxpY2hlciBBdXNrbGFuZyAtLS0KICAlIFQuIDQxLTQ2CiAgZCc0KFxwcCBjOCBiZXM0IGQ4IHwKICBjNCBhOCBmNCkgcjggfAogIGc0KCBhOCBiZXM0IGc4IHwKICBhNCBmJzggYzQgYTggfAogIGY0Ln4gZjQpIHI4IHwKICA8YSwgZic+Mi5ccHBwXGZlcm1hdGEgXGJhciAifC4iCn0KCmNlbGxvTXVzaWMgPSBccmVsYXRpdmUgYyB7CiAgXGdsb2JhbAogIFxjbGVmIGJhc3MKCiAgJSAtLS0gVEVJTCBBOiBCb3JkdW4tUXVpbnRlbiB1bmQgd2llZ2VuZGUgQsOkc3NlIC0tLQogICUgVC4gMS00OiBLbGFzc2lzY2hlciBQYXN0b3JhbGUtQm9yZHVuCiAgPGYsIGMnPjIuXHBeXG1hcmt1cCB7IFxpdGFsaWMgImNvbiBtb3JiaWRlenphIiB9IH4gfAogIDxmIGMnPjIuIHwKICA8ZiBkJz40LiA8ZiBjJz40LiB8CiAgPGYgYyc+NCggYTggYzQgYTgpIHwKCiAgJSBULiA1LTgKICA8ZiBjJz4yLiB8CiAgPGEgZSc+NC4gZDQoIGM4KSB8CiAgYmVzNChcPCBhOCBnNClcISBmOCB8CiAgYyc0Ln4oXD4gYzQgYmVzOClcISB8CgogICUgVC4gOS0xMgogIDxmIGMnPjQuXG1wIDxmIGMnPjQuIHwKICA8ZiBkJz40LiA8ZiBjJz40LiB8CiAgPGUgYyc+NC5cPiA8YyBjJz40LiB8CiAgZjgoXHAgYycgYSBmNCkgcjggfAoKICAlIFQuIDEzLTE2OiBXZWcgenVyIERvbWluYW50ZSBDLUR1cgogIGc4KFw8IGQnIGcsIGYgZCcgZywpXCEgfAogIGU4KCBjJyBlLCBmNCkgYTggfAogIGc0Llw+IDxnLCBnJz40LiB8CiAgYzgoXHAgZycgZSBjNCkgcjggXGJhciAifHwiCgogICUgLS0tIFRFSUwgQjogQ2VsbG8gw7xiZXJuaW1tdCBkaWUgS2FudGlsZW5lIGluIGRlciBUZW5vcmxhZ2UgLS0tCiAgJSBULiAxNy0yMAogIFxjbGVmIHRlbm9yCiAgYScnNChcbWZeXG1hcmt1cCB7IFxpdGFsaWMgImVzcHJlc3Npdm8gZSBjYW50YWJpbGUiIH0gZzggZjQgYTggfAogIGJlczQgYTggZjQgZDggfAogIGM0IGY4IGE0IGMsOCB8CiAgZyc0Ln4gZzQpIHI4IHwKCiAgJSBULiAyMS0yNDogTW9sbC1FaW50csO8YnVuZwogIGY0KCBlOCBkNCBmOCB8CiAgZzRcPCBhOCBiZXM0XCEgZzggfAogIGE0IGY4IGQ0IGY4IHwKICBlNC5+IGU0KVw+IHI4XCEgfAoKICAlIFQuIDI1LTI4OiBTZXF1ZW56aWVydW5nCiAgZDQoXG1wIGY4IGJlczQgZCw4IHwKICBjNCBmOCBhNCBjLDggfAogIGJlczQgZDggZzQgYmVzLDggfAogIGM0XDwgZTggZzRcISBiZXM4KSB8CgogICUgVC4gMjktMzI6IEFic3RpZWcgenVyw7xjayBpbiBkaWUgQmFzc2xhZ2UKICBhNChcbWYgYzggZjQgYSw4IHwKICBiZXM0IGQ4IGY0KSByOCB8CiAgXGNsZWYgYmFzcwogIGMsNC4oXD4gYyw0LiB8CiAgZjQpIHI4IHI0IHI4XCEgXGJhciAifHwiCgogICUgLS0tIFRFSUwgQSc6IFJlcHJpc2UgLS0tCiAgJSBULiAzMy0zNjogUsO8Y2trZWhyIGRlcyBCb3JkdW5zCiAgPGYgYyc+Mi5ccCB+IHwKICA8ZiBjJz4yLiB8CiAgPGYgZCc+NC4gPGYgYyc+NC4gfAogIDxmIGMnPjgoIGMnIGEgZjQpIHI4IHwKCiAgJSBULiAzNy00MDogU2FuZnRlIEdlZ2Vuc3RpbW1lCiAgPGYgYyc+NC4oXDwgPGEsIGYnPjQuKVwhIHwKICBiZXM4KCBmJyBkIGJlczQpIGQ4IHwKICBjNC4oXD4gYyw0LikgfAogIGY4KFwhIGMnIGEgZjQpIHI4IHwKCiAgJSAtLS0gQ09EQTogVmVya2xpbmdlbiDDvGJlciBPcmdlbHB1bmt0IEYgLS0tCiAgJSBULiA0MS00NgogIDxmIGJlcz4yLlxwcCB8CiAgPGYgYT4yLiB8CiAgPGYgZCc+NC4gPGYgYmVzPjQuIHwKICA8ZiBjJz4yLiB+IHwKICA8ZiBjJz40KCBhOCBjNCBhOCkgfAogIDxmLCBjJyBmPjIuXHBwcFxmZXJtYXRhIFxiYXIgInwuIgp9Cgpcc2NvcmUgewogIFxuZXcgU3RhZmZHcm91cCA8PAogICAgXG5ldyBTdGFmZiBcd2l0aCB7CiAgICAgIGluc3RydW1lbnROYW1lID0gIlZpb2xpbmUiCiAgICAgIHNob3J0SW5zdHJ1bWVudE5hbWUgPSAiVmwuIgogICAgICBtaWRpSW5zdHJ1bWVudCA9ICJ2aW9saW4iCiAgICB9IFx2aW9saW5NdXNpYwoKICAgIFxuZXcgU3RhZmYgXHdpdGggewogICAgICBpbnN0cnVtZW50TmFtZSA9ICJWaW9sb25jZWxsbyIKICAgICAgc2hvcnRJbnN0cnVtZW50TmFtZSA9ICJWYy4iCiAgICAgIG1pZGlJbnN0cnVtZW50ID0gImNlbGxvIgogICAgfSBcY2VsbG9NdXNpYwogID4+CgogIFxsYXlvdXQgewogICAgXGNvbnRleHQgewogICAgICBcU2NvcmUKICAgICAgXG92ZXJyaWRlIFNwYWNpbmdTcGFubmVyLmJhc2Utc2hvcnRlc3QtZHVyYXRpb24gPSAjKGx5Om1ha2UtbW9tZW50IDEvMTYpCiAgICB9CiAgfQoKICBcbWlkaSB7CiAgICBcdGVtcG8gNC4gPSA1MgogIH0KfQo='))
    Run-Probe '03-original-pastorale' $original @('--svg','-dpoint-and-click','--verbose','--output=probe','probe.ly') 45
    if ($DiagnosticJson) {
        $diag=Get-Content -LiteralPath $DiagnosticJson -Raw | ConvertFrom-Json
        $music=[string]$diag.composition
        $music=[regex]::Replace($music,'^\s*```(?:lilypond|ly)\s*','',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $music=[regex]::Replace($music,'\s*```\s*$','')
        if ($music -notmatch '\\score\s*\{') { throw 'Diagnostic does not contain LilyPond score' }
        Run-Probe '03-original' $music @('--svg','-dpoint-and-click','--verbose','--output=probe','probe.ly') 35
    }
} catch { $report.error=$_.Exception.ToString() }
finally {
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host "Diagnostic saved: $ReportPath"
    try { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}
