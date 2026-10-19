"""Bundle the unchanged official, pinned macOS engravers for both architectures."""
from pathlib import Path
import hashlib
import shutil
import sys
import tarfile
import urllib.request

RELEASE = "https://gitlab.com/lilypond/lilypond/-/releases/v2.26.0/downloads/"
DIGESTS = {
    "x86_64": "6dcbca34b13ad6d4ba3606a0b48edd02688284fcd52e9c00141242df1996a148",
    "arm64": "18ffc454fef3753c26a015d95a3c232f89b22f052b897c046e0198740a1221be",
}

def main():
    resources = Path(sys.argv[1])
    cache = Path(".build-lilypond")
    cache.mkdir(exist_ok=True)
    for architecture, digest in DIGESTS.items():
        name = f"lilypond-2.26.0-darwin-{architecture}.tar.gz"
        archive = cache / name
        if not archive.exists():
            temporary = cache / (name + ".part")
            urllib.request.urlretrieve(RELEASE + name, temporary)
            temporary.replace(archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
            raise RuntimeError("LilyPond archive checksum mismatch: " + name)
        destination = resources / ("LilyPond-" + architecture)
        if destination.exists():
            shutil.rmtree(destination)
        work = cache / ("extract-" + architecture)
        if work.exists():
            shutil.rmtree(work)
        work.mkdir()
        # Only fixed, checksum-verified release archives are extracted here.
        with tarfile.open(archive) as bundle:
            bundle.extractall(work, **({"filter": "data"} if hasattr(tarfile, "data_filter") else {}))
        source = work / "lilypond-2.26.0"
        if not (source / "bin/lilypond").is_file():
            raise RuntimeError("LilyPond archive has no executable: " + name)
        shutil.move(str(source), str(destination))
        shutil.rmtree(work)
        print("Bundled LilyPond 2.26.0 for " + architecture)

if __name__ == "__main__":
    main()
