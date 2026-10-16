$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$destination = Join-Path $PWD 'Windows/Bundle/Composition Lab 4.0'
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
# Keep the verified, unmodified portable engraver with the app: no user install
# and no network calls during MIDI conversion or notation rendering.
$lilyArchive = Join-Path $env:TEMP 'lilypond-2.26.0-mingw-x86_64.zip'
Invoke-WebRequest 'https://gitlab.com/lilypond/lilypond/-/releases/v2.26.0/downloads/lilypond-2.26.0-mingw-x86_64.zip' -OutFile $lilyArchive
if ((Get-FileHash $lilyArchive -Algorithm SHA256).Hash -ne '14DDDDC233B469EF60D4FFC1C7F35520F15AC6B58E38CAB458C60BDCC3AF650C') { throw 'LilyPond archive checksum mismatch' }
$lilyExtract = Join-Path $env:TEMP ('clab-lily-' + [guid]::NewGuid().ToString('N'))
Expand-Archive $lilyArchive $lilyExtract
Copy-Item (Join-Path $lilyExtract 'lilypond-2.26.0') (Join-Path $destination 'LilyPond') -Recurse
& (Join-Path $destination 'LilyPond/bin/lilypond.exe') --version
if ($LASTEXITCODE -ne 0) { throw 'Bundled LilyPond cannot start' }
Copy-Item 'Windows/README-Windows.md' (Join-Path $destination 'LIESMICH.md')
# A normal user must not need the Swift compiler/toolchain on PATH.
$oldPath = $env:Path
try {
    $env:Path = "$env:windir/System32;$env:windir"
    $version = & (Join-Path $core 'composition-lab-core.exe') --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '4.0.0-alpha.12') { throw 'Bundled core runtime is incomplete' }
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
$start.FileName = Join-Path $destination 'Composition Lab 4.0.exe'
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
$zip = Join-Path $PWD 'Composition-Lab-4.0-alpha.19-Windows-x64.zip'
Compress-Archive -Path $destination -DestinationPath $zip -Force
Write-Output "Windows test package: $zip"
