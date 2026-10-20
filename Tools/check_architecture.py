#!/usr/bin/env python3
"""Repository contracts independent of a desktop runtime or provider keys."""
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parents[1]

def require(condition, message):
    if not condition:
        raise SystemExit(message)

shared = list((root / 'Shared/CompositionCore').glob('*.swift'))
for path in shared:
    require(not re.search(r'^import (Cocoa|AppKit|WinForms|CoreMIDI|AVFoundation|WebKit)\b', path.read_text(), re.M), f'Platform UI/device dependency in shared core: {path.name}')
for path in (root / 'Sources').glob('*.swift'):
    require(not re.search(r'\b(ReaperBridge|StudioProBridge)\b', path.read_text()), f'Removed DAW bridge referenced by {path.name}')
bridge = (root / 'Tools/CoreCLI/BridgeService.swift').read_text()
operations = set()
for case in re.findall(r'case\s+([^:\n]+):', bridge):
    operations.update(re.findall(r'"([\w-]+)"', case))
requests = set()
for path in (root / 'Windows/CompositionLab').glob('*.cs'):
    values = set(re.findall(r'\["operation"\]\s*=\s*"([\w-]+)"', path.read_text()))
    if path.name == 'ScoreUndo.cs':
        values.discard('push')  # Nested ScoreRevisionStore operation, not a CLI operation.
    requests.update(values)
require(requests <= operations, f'Windows operations missing from the shared service: {sorted(requests - operations)}')
with (root / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
project = ET.parse(root / 'Windows/CompositionLab/CompositionLab.csproj').getroot()
version = project.findtext('./PropertyGroup/Version')
require(info['CFBundleShortVersionString'] == version, 'Mac/Windows version mismatch')
require(f'public static let version = "{version}"' in (root / 'Shared/CompositionCore/CoreServices.swift').read_text(), 'Core version mismatch')
require(f'const string Version = "{version}"' in (root / 'Windows/CompositionLab/MainForm.cs').read_text(), 'Windows title/diagnostic version mismatch')
workflow = (root / '.github/workflows/v4-core.yml').read_text()
packer = (root / 'Windows/Build.ps1').read_text()
archive = re.search(r"\$zip = Join-Path \$PWD '([^']+)'", packer).group(1)
require(f'path: {archive}' in workflow, 'Windows archive and CI upload disagree')
require(info['CFBundleExecutable'] in (root / 'Build Native App.command').read_text(), 'Mac executable and bundle metadata disagree')
print(f'Architecture, {len(requests)} Windows operation contracts, package paths and version {version}: PASS')
