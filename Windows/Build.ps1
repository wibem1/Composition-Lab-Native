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
Copy-Item 'LICENSE' (Join-Path $destination 'LICENSE-Swift-Core.txt')
Copy-Item 'Windows/README-Windows.md' (Join-Path $destination 'LIESMICH.md')
# A normal user must not need the Swift compiler/toolchain on PATH.
$oldPath = $env:Path
try {
    $env:Path = "$env:windir/System32;$env:windir"
    $version = & (Join-Path $core 'composition-lab-core.exe') --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '4.0.0-alpha.2') { throw 'Bundled core runtime is incomplete' }
} finally { $env:Path = $oldPath }
$tests = Join-Path $PWD 'Windows/TestResults'
New-Item $tests -ItemType Directory -Force | Out-Null
$start = New-Object System.Diagnostics.ProcessStartInfo
$start.FileName = Join-Path $destination 'Composition Lab 4.0.exe'
$start.Arguments = "--self-test --test-output `"$tests`""
$start.UseShellExecute = $false
$start.Environment['PATH'] = "$env:windir/System32;$env:windir"
$process = [System.Diagnostics.Process]::Start($start)
if (-not $process.WaitForExit(120000)) { $process.Kill(); throw 'Windows UI self-test timed out' }
if ($process.ExitCode -ne 0) {
    if (Test-Path (Join-Path $tests 'failure.txt')) { Get-Content (Join-Path $tests 'failure.txt') }
    throw 'Windows UI self-test failed'
}
$report = Get-Content (Join-Path $tests 'result.json') -Raw | ConvertFrom-Json
if (-not $report.passed) { throw 'Windows test result is not green' }
Get-Content (Join-Path $tests 'result.json')
$zip = Join-Path $PWD 'Composition-Lab-4.0-alpha.2-Windows-x64.zip'
Compress-Archive -Path $destination -DestinationPath $zip -Force
Write-Output "Windows test package: $zip"
