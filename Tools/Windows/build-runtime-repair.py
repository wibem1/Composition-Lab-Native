"""Build a single-file local repair; embedded compressed JSON is checksum data only."""
import base64
import gzip
import json
from pathlib import Path
root = Path(__file__).resolve().parents[2]
manifest = json.loads((root / 'Windows/LilyPond-Runtime-Manifest.json').read_text())
data = base64.b64encode(gzip.compress(json.dumps(manifest,separators=(',',':')).encode(),mtime=0)).decode()
body = (root / 'Tools/Windows/Repair-LilyPondTimestamps.template.ps1').read_text().replace('@@MANIFEST@@',data)
wrapper = '''@echo off
setlocal
set "CLAB_REPAIR_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -Command "$s=[IO.File]::ReadAllText($env:CLAB_REPAIR_SELF); & ([scriptblock]::Create($s.Substring($s.LastIndexOf('# CLAB_POWERSHELL_START'))))"
set "CLAB_REPAIR_RC=%ERRORLEVEL%"
if not "%CLAB_REPAIR_NO_PAUSE%"=="1" pause
exit /b %CLAB_REPAIR_RC%
# CLAB_POWERSHELL_START
'''
(root / 'Windows/LilyPond-Reparatur.cmd').write_text(wrapper+body,encoding='utf-8')
