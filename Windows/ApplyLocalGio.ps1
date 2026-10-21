param([Parameter(Mandatory=$true)][string]$Bundle, [Parameter(Mandatory=$true)][string]$Candidate)
$ErrorActionPreference = 'Stop'
# The compile/test artifact is pinned in the workflow and each DLL is independently
# pinned by SHA-256. All other LilyPond/Guile/GLib files remain official originals.
python Tools/Windows/verify_gio_abi.py (Join-Path $Bundle 'bin') $Candidate
if ($LASTEXITCODE -ne 0) { throw 'GIO replacement is incompatible or unverified' }
Copy-Item (Join-Path $Candidate 'libgio-2.0-0.dll') (Join-Path $Bundle 'bin/libgio-2.0-0.dll') -Force
Copy-Item (Join-Path $Candidate 'zlib1.dll') (Join-Path $Bundle 'bin/zlib1.dll') -Force
$notice = Join-Path $Bundle 'licenses/Composition-Lab-GIO'
New-Item $notice -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $Candidate 'COPYING-GLib.txt') $notice
Copy-Item (Join-Path $Candidate 'lazy-appinfo.patch') $notice
Copy-Item 'Tools/Windows/build-lazy-gio.sh' $notice
Copy-Item 'Windows/Notices/Local-GIO.txt' $notice
Copy-Item 'Windows/Notices/zlib-1.3.2-README.txt' $notice
# Ship the exact source of the modified LGPL component with the patch/build script.
$source = Join-Path $env:TEMP ('clab-glib-source-' + [guid]::NewGuid().ToString('N'))
git clone --quiet --depth 1 --branch 2.72.4 https://github.com/GNOME/glib.git $source
if ($LASTEXITCODE -ne 0) { throw 'Cannot include GLib source' }
$revision = git -C $source rev-parse HEAD
if ($revision -ne '6ed6303e40d6eaf80f2acfbfbcadbb169d156e9c') { throw 'GLib source revision mismatch' }
$sourceArchive = Join-Path $notice 'glib-2.72.4-source.tar.gz'
git -C $source archive --format=tar.gz "--output=$sourceArchive" HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot archive GLib source' }
Remove-Item $source -Recurse -Force
