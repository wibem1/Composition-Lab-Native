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

# Getestete Tie-Export-Erweiterung direkt in den unveränderten V5.0.11-Builder
# integrieren. Die Ersetzung ist absichtlich exakt; falls sich der Referenzblock
# nicht wiederfindet, wird abgebrochen statt stillschweigend falsch weiterzubauen.
python3 - <<'PY'
from pathlib import Path
p = Path('Sources/MusicXMLBuilder.swift')
s = p.read_text()
if 'explicitTieStart' not in s:
    old = '''        if maxStaff > 1 { out += "        <staff>\\(staff)</staff>\\n" }
        out += "        <velocity>\\(f.velocity)</velocity>\\n"
        if grace == nil {
            if f.tieStop { out += "        <tie type=\\"stop\\"/>\\n" }
            if f.tieStart { out += "        <tie type=\\"start\\"/>\\n" }
        }

        var notations = ""
        if grace == nil {
            if f.tieStop { notations += "<tied type=\\"stop\\"/>" }
            if f.tieStart { notations += "<tied type=\\"start\\"/>" }
        }
'''
    new = '''        if maxStaff > 1 { out += "        <staff>\\(staff)</staff>\\n" }
        out += "        <velocity>\\(f.velocity)</velocity>\\n"

        // Neben den automatisch erzeugten Bindungen für in Teilnoten zerlegte lange
        // Noten werden auch explizite, aus MusicXML importierte tie-Ereignisse
        // berücksichtigt. Ein tie-Event beschreibt den Startbeat b und den Beat e
        // der gebundenen Folgenoten; Pitch/Staff begrenzen die Zuordnung.
        let explicitTieStart = events.contains { ev in
            guard ev.t.lowercased() == "tie", abs(ev.b - f.sourceStart) < 0.000_1 else { return false }
            if let st = ev.st, st != staff { return false }
            if let pitch = ev.p, pitch != f.pitch { return false }
            return ev.e != nil
        }
        let explicitTieStop = events.contains { ev in
            guard ev.t.lowercased() == "tie", let end = ev.e, abs(end - f.sourceStart) < 0.000_1 else { return false }
            if let st = ev.st, st != staff { return false }
            if let pitch = ev.p, pitch != f.pitch { return false }
            return true
        }
        let tieStop = f.tieStop || explicitTieStop
        let tieStart = f.tieStart || explicitTieStart

        if grace == nil {
            if tieStop { out += "        <tie type=\\"stop\\"/>\\n" }
            if tieStart { out += "        <tie type=\\"start\\"/>\\n" }
        }

        var notations = ""
        if grace == nil {
            if tieStop { notations += "<tied type=\\"stop\\"/>" }
            if tieStart { notations += "<tied type=\\"start\\"/>" }
        }
'''
    if old not in s:
        raise SystemExit('FEHLER: Erwarteter V5.0.11-Tie-Block in MusicXMLBuilder.swift nicht gefunden.')
    s = s.replace(old, new, 1)
    p.write_text(s)
PY

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

grep -q 'explicitTieStart' Sources/MusicXMLBuilder.swift || {
  echo "FEHLER: Tie-Export-Erweiterung wurde nicht integriert."
  exit 1
}

echo "Native-Quellbaum vollständig entfaltet: $COUNT Swift-Dateien."
echo "V5.0.11 / Build 83 / Engine Build 14"
