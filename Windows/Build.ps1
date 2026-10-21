$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$destination = Join-Path $PWD 'Windows/Bundle/Composition Lab 4.2.7'
if (Test-Path $destination) { Remove-Item $destination -Recurse -Force }
New-Item $destination -ItemType Directory -Force | Out-Null
dotnet publish 'Windows/CompositionLab/CompositionLab.csproj' -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $destination
if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed' }
$core = Join-Path $destination 'Core'
New-Item $core -ItemType Directory | Out-Null
Copy-Item '.build/release/composition-lab-core.exe' $core
# Include Swift runtime DLLs rather than requiring a developer installation.
$swiftBin = Split-Path (Get-Command swift).Source -Parent
$runtimeDirectories = @($swiftBin) + @($env:Path.Split(';') | Where-Object { $_ -match 'Swift' -and (Test-Path $_ -PathType Container) })
foreach ($directory in ($runtimeDirectories | Select-Object -Unique)) {
    Get-ChildItem $directory -Filter '*.dll' -File | Copy-Item -Destination $core -Force
}
foreach ($name in @('vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll','concrt140.dll')) {
    $file = Join-Path $env:windir "System32/$name"
    if (Test-Path $file) { Copy-Item $file $core }
}
python -m pip install --quiet pefile==2024.8.26
if ($LASTEXITCODE -ne 0) { throw 'PE dependency inspector installation failed' }
python 'Windows/trim_runtime.py' $core
if ($LASTEXITCODE -ne 0) { throw 'Runtime dependency inspection failed' }
Copy-Item 'LICENSE' (Join-Path $destination 'LICENSE-Composition-Lab.txt')
Copy-Item 'Windows/Notices' (Join-Path $destination 'Notices') -Recurse
foreach ($package in @('microsoft.web.webview2','microsoft.netcore.app.runtime.win-x64','microsoft.windowsdesktop.app.runtime.win-x64')) {
    $directory = Join-Path $env:USERPROFILE ".nuget/packages/$package"
    if (Test-Path $directory) {
        $latest = Get-ChildItem $directory -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        foreach ($name in @('LICENSE.txt','LICENSE.TXT','LICENSE','THIRD-PARTY-NOTICES.TXT','NOTICE')) {
            $notice = Join-Path $latest.FullName $name
            if (Test-Path $notice) { Copy-Item $notice (Join-Path $destination "Notices/$package-$name") -Force }
        }
    }
}
# Keep the verified portable engraver with the app: no user install
# and no network calls during MIDI conversion or notation rendering.
$lilyArchive = Join-Path $env:TEMP 'lilypond-2.24.4-mingw-x86_64.zip'
Invoke-WebRequest 'https://gitlab.com/lilypond/lilypond/-/releases/v2.24.4/downloads/lilypond-2.24.4-mingw-x86_64.zip' -OutFile $lilyArchive
if ((Get-FileHash $lilyArchive -Algorithm SHA256).Hash -ne 'E238F5A33EBDE7466FE03D0FBCAA155A44536CA582951972482E0B00CEB0FBF1') { throw 'LilyPond archive checksum mismatch' }
$lilyExtract = Join-Path $env:TEMP ('clab-lily-' + [guid]::NewGuid().ToString('N'))
Expand-Archive $lilyArchive $lilyExtract
Copy-Item (Join-Path $lilyExtract 'lilypond-2.24.4') (Join-Path $destination 'LilyPond') -Recurse
if (-not $env:COMPOSITION_LAB_GIO_SOURCE) {
    $runtimeZip = Join-Path $env:TEMP 'Composition-Lab-Local-GIO-v1.zip'
    $runtimeRoot = Join-Path $env:TEMP ('clab-gio-' + [guid]::NewGuid().ToString('N'))
    Invoke-WebRequest 'https://github.com/wibem1/Composition-Lab-Native/releases/download/v4.2.7/Local-GIO-Runtime-v1.zip' -OutFile $runtimeZip
    Expand-Archive $runtimeZip $runtimeRoot
    $env:COMPOSITION_LAB_GIO_SOURCE = Join-Path $runtimeRoot 'RuntimeCandidate'
}
& ./Windows/ApplyLocalGio.ps1 -Bundle (Join-Path $destination 'LilyPond') -Candidate $env:COMPOSITION_LAB_GIO_SOURCE
if ($LASTEXITCODE -ne 0) { throw 'Local GIO runtime validation failed' }
& (Get-Command pwsh).Source -NoLogo -NoProfile -File Tools/Windows/Test-GioLoad.ps1 -Bundle (Join-Path $destination 'LilyPond')
if ($LASTEXITCODE -ne 0) { throw 'Local GIO still loads Windows application enumeration' }
# Validate bundled Guile bytecode after ZIP extraction. Extracted archive timestamps
# can make .scm sources appear newer than their matching .go caches, causing
# long startup delays even when every bundled file has the correct contents.
# The repair checks pinned SHA-256 hashes before touching timestamps and
# performs a real offline MIDI/SVG compile; do not ship if it fails.
Copy-Item 'Windows/LilyPond-Reparatur.cmd' (Join-Path $destination 'LilyPond-Reparatur.cmd')
$oldRepairTarget = $env:CLAB_REPAIR_TARGET
$oldRepairNoPause = $env:CLAB_REPAIR_NO_PAUSE
$oldRepairReport = $env:CLAB_REPAIR_REPORT
$repairReport = Join-Path $env:TEMP ('clab-build-guile-' + [guid]::NewGuid().ToString('N') + '.json')
try {
    $env:CLAB_REPAIR_TARGET = $destination
    $env:CLAB_REPAIR_NO_PAUSE = '1'
    $env:CLAB_REPAIR_REPORT = $repairReport
    & (Join-Path $destination 'LilyPond-Reparatur.cmd')
    if ($LASTEXITCODE -ne 0) { throw 'Bundled Guile runtime repair or offline engraving smoke test failed' }
    if (-not (Test-Path -LiteralPath $repairReport)) { throw 'Guile runtime repair produced no report' }
    $repairResult = Get-Content -LiteralPath $repairReport -Raw | ConvertFrom-Json
    if (-not $repairResult.passed -or $repairResult.verifiedPairs -lt 1) {
        throw 'Guile runtime repair verification failed; refusing to publish Windows package'
    }
    Write-Output ('Guile cache verified: ' + $repairResult.verifiedPairs + ' pairs; fixed timestamps: ' + $repairResult.repairedPairs)
} finally {
    $env:CLAB_REPAIR_TARGET = $oldRepairTarget
    $env:CLAB_REPAIR_NO_PAUSE = $oldRepairNoPause
    $env:CLAB_REPAIR_REPORT = $oldRepairReport
}
& (Join-Path $destination 'LilyPond/bin/lilypond.exe') --version
if ($LASTEXITCODE -ne 0) { throw 'Bundled LilyPond cannot start' }
Copy-Item 'Windows/README-Windows.md' (Join-Path $destination 'LIESMICH.md')
# A normal user must not need the Swift compiler/toolchain on PATH.
$oldPath = $env:Path
try {
    $env:Path = "$env:windir/System32;$env:windir"
    $version = & (Join-Path $core 'composition-lab-core.exe') --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '4.2.7') { throw 'Bundled core runtime is incomplete' }
} finally { $env:Path = $oldPath }
# CI must exercise a real native browser, not only managed bitmap painting.
try { [void][Microsoft.Win32.Registry]::GetValue('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F1E7E558-F3C6-4A58-B13A-B17E7164CA09}', 'pv', $null) } catch { }
$bootstrap = Join-Path $env:TEMP 'MicrosoftEdgeWebview2Setup.exe'
Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $bootstrap
Start-Process $bootstrap -ArgumentList '/silent /install' -Wait
$tests = Join-Path $PWD 'Windows/TestResults'
New-Item $tests -ItemType Directory -Force | Out-Null
try { Set-DisplayResolution -Width 1600 -Height 1200 -Force -ErrorAction Stop | Out-Null } catch { Write-Output 'Default Windows display retained; GUI scroll reachability is tested.' }
$start = New-Object System.Diagnostics.ProcessStartInfo
$start.FileName = Join-Path $destination 'Composition Lab 4.2.7.exe'
$start.Arguments = "--self-test --test-output `"$tests`""
$start.UseShellExecute = $false
$start.Environment['PATH'] = "$env:windir/System32;$env:windir"
$process = [System.Diagnostics.Process]::Start($start)
if (-not $process.WaitForExit(180000)) { $process.Kill(); throw 'Windows UI self-test timed out' }
if ($process.ExitCode -ne 0) {
    if (Test-Path (Join-Path $tests 'failure.txt')) { Get-Content (Join-Path $tests 'failure.txt') }
    throw 'Windows UI self-test failed'
}
$report = Get-Content (Join-Path $tests 'result.json') -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'Windows test result is not green' }
Get-Content (Join-Path $tests 'result.json')
$zip = Join-Path $PWD 'Composition-Lab-4.2.7-Windows-x64.zip'
Compress-Archive -Path $destination -DestinationPath $zip -Force
Write-Output "Windows test package: $zip"

# The released ZIP, not only the source bundle, must pass the native tests.
$roundtrip = Join-Path $env:TEMP ('clab-packaged-' + [guid]::NewGuid().ToString('N'))
Expand-Archive $zip $roundtrip
$packagedTests = Join-Path $tests 'Packaged'
New-Item $packagedTests -ItemType Directory -Force | Out-Null
$start.FileName = Join-Path $roundtrip 'Composition Lab 4.2.7/Composition Lab 4.2.7.exe'
$start.Arguments = "--self-test --test-output `"$packagedTests`""
$packagedProcess = [System.Diagnostics.Process]::Start($start)
if (-not $packagedProcess.WaitForExit(180000)) { $packagedProcess.Kill(); throw 'Packaged Windows test timed out' }
if ($packagedProcess.ExitCode -ne 0) {
    if (Test-Path (Join-Path $packagedTests 'failure.txt')) { Get-Content (Join-Path $packagedTests 'failure.txt') }
    throw 'Packaged Windows self-test failed'
}
$packagedReport = Get-Content (Join-Path $packagedTests 'result.json') -Raw | ConvertFrom-Json
if (-not $packagedReport.passed) { throw 'Packaged Windows test report is not green' }
Get-Content (Join-Path $packagedTests 'Pastorale-Messung.json')
try { Remove-Item $roundtrip -Recurse -Force } catch { Write-Warning 'Temporary test bundle retained because a file is still in use.' }
