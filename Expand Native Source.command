#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

ARCHIVE="Composition_Lab_Native_V5_0_11_SOURCE.zip"
EXPECTED_SHA256="b8297348207b8d4dc51c0de16a05fe7bdb36f07c3136bc2f5adf83156dde2090"

if [ ! -f "$ARCHIVE" ]; then
  echo "FEHLER: $ARCHIVE fehlt."
  exit 1
fi

ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "FEHLER: Prüfsumme des Source-Archivs stimmt nicht."
  echo "Erwartet: $EXPECTED_SHA256"
  echo "Gefunden: $ACTUAL_SHA256"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$ARCHIVE" -d "$TMP"
mkdir -p Sources

# Vollständigen V5.0.11-Quellbaum herstellen. Bereits ausgerichtete Dateien
# bleiben unangetastet; alle übrigen Dateien kommen exakt aus dem Referenz-ZIP.
for f in "$TMP"/Sources/*.swift; do
  name="$(basename "$f")"
  case "$name" in
    MIDIParser.swift|MusicXMLParser.swift|APIClient.swift)
      if [ ! -f "Sources/$name" ]; then cp "$f" "Sources/$name"; fi
      ;;
    MusicXMLBuilder.swift)
      cp "$f" "Sources/$name"
      ;;
    *)
      cp "$f" "Sources/$name"
      ;;
  esac
done

cp "$TMP/Info.plist" Info.plist
cp "$TMP/README.txt" README.txt

# Getestete Tie-Export-Erweiterung integrieren, aber nie doppelt anwenden.
if ! grep -q 'explicitTieStart' Sources/MusicXMLBuilder.swift; then
  patch -p0 < patches/MusicXMLBuilder-tie-export.patch
fi

COUNT="$(find Sources -maxdepth 1 -name '*.swift' | wc -l | tr -d ' ')"
if [ "$COUNT" -ne 25 ]; then
  echo "FEHLER: Erwartet 25 Swift-Dateien, gefunden: $COUNT"
  exit 1
fi

for required in \
  Sources/MainViewController.swift \
  Sources/MIDIParser.swift \
  Sources/MusicXMLParser.swift \
  Sources/MusicXMLBuilder.swift \
  Sources/ReaperBridge.swift \
  Sources/Models.swift \
  Info.plist; do
  test -f "$required" || { echo "FEHLER: $required fehlt."; exit 1; }
done

echo "Native-Quellbaum vollständig entfaltet: $COUNT Swift-Dateien."
echo "V5.0.11 / Build 83 / Engine Build 14"
