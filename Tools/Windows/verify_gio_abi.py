"""Fail closed unless the minimal GIO replacement matches the bundled ABI."""
import hashlib
import json
from pathlib import Path
import sys
import pefile

bundle, candidate = map(Path, sys.argv[1:3])
expected = {
    'libgio-2.0-0.dll': '53a0ac6930b987c2d0b375f564b611aca658272b7439f2e74ea1074cad3e3c5c',
    'zlib1.dll': '93e9243a44c29200eeacaf9658efe2558581770e4b11ca4b500e18e424a6e3b5',
}
system = {'advapi32.dll','dnsapi.dll','iphlpapi.dll','kernel32.dll','msvcrt.dll','ole32.dll',
          'shell32.dll','shlwapi.dll','user32.dll','ws2_32.dll'}
def symbols(path):
    pe = pefile.PE(str(path))
    return {e.name for e in pe.DIRECTORY_ENTRY_EXPORT.symbols if e.name}
original = symbols(bundle / 'libgio-2.0-0.dll')
assert original == symbols(candidate / 'libgio-2.0-0.dll'), 'GIO export ABI differs'
for name, digest in expected.items():
    path = candidate / name
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, 'Unverified runtime DLL: ' + name
    pe = pefile.PE(str(path))
    assert pe.FILE_HEADER.Machine == 0x8664, 'Not an x64 runtime'
    for library in pe.DIRECTORY_ENTRY_IMPORT:
        imported_name = library.dll.decode()
        target = candidate / imported_name if imported_name.lower() == 'zlib1.dll' else bundle / imported_name
        if imported_name.lower() in system:
            continue
        assert target.is_file(), 'Unexpected dependency: ' + imported_name
        exports = symbols(target)
        missing = [s.name.decode() for s in library.imports if s.name and s.name not in exports]
        assert not missing, f'{name}: missing {imported_name} symbols: {missing}'
print(json.dumps({'profile':'local-gio-lazy-v1','gioExports':len(original),'hashes':expected,'passed':True}, indent=2))
