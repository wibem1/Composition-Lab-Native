param([Parameter(Mandatory=$true)][string]$Bundle)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class GioLoadProbe {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr LoadLibraryEx(string file, IntPtr reserved, uint flags);
}
'@
$before = @([Diagnostics.Process]::GetCurrentProcess().Modules | ForEach-Object { $_.ModuleName.ToLowerInvariant() })
$path = Join-Path $Bundle 'bin/libgio-2.0-0.dll'
$handle = [GioLoadProbe]::LoadLibraryEx($path, [IntPtr]::Zero, 8)
if ($handle -eq [IntPtr]::Zero) { throw ('Cannot load GIO: Win32 error ' + [Runtime.InteropServices.Marshal]::GetLastWin32Error()) }
Start-Sleep -Milliseconds 1000
$after = @([Diagnostics.Process]::GetCurrentProcess().Modules | ForEach-Object { $_.ModuleName.ToLowerInvariant() })
$unexpected = @($after | Where-Object { $_ -notin $before -and ($_ -eq 'windows.applicationmodel.dll' -or $_ -eq 'appxdeploymentclient.dll' -or $_ -like 'windows.staterepository*') })
[ordered]@{profile='local-gio-lazy-v1';loaded=$true;newAppEnumerationModules=$unexpected;passed=($unexpected.Count -eq 0)} | ConvertTo-Json -Depth 3
if ($unexpected.Count -ne 0) { throw 'Loading headless GIO still initializes Windows app enumeration' }
