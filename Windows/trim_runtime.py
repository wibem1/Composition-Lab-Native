"""Keep the recursive PE import closure of the core, not the Swift compiler DLLs."""
from pathlib import Path
import sys
import pefile

root = Path(sys.argv[1])
candidates = {p.name.lower(): p for p in root.glob("*.dll")}
pending = [root / "composition-lab-core.exe"]
retained = set()
while pending:
    file = pending.pop()
    with pefile.PE(str(file), fast_load=True) as pe:
        pe.parse_data_directories(directories=[
            pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IMPORT"],
            pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT"],
        ])
        for entry in list(getattr(pe, "DIRECTORY_ENTRY_IMPORT", [])) + list(getattr(pe, "DIRECTORY_ENTRY_DELAY_IMPORT", [])):
            name = entry.dll.decode("ascii").lower()
            if name in candidates and name not in retained:
                retained.add(name)
                pending.append(candidates[name])
removed = 0
for name, file in candidates.items():
    if name not in retained:
        removed += file.stat().st_size
        file.unlink()
print(f"Kept {len(retained)} runtime DLLs; removed {removed / 1024**2:.1f} MiB of unused build tooling.")
