#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="Composition Lab.app"
BUILD=".build-native"

python3 ApplyWorkspaceLayoutFix.py
python3 ApplyCompositionLab2.py
python3 ApplyV6SlotsState.py
python3 ApplyV6MainLayout.py
python3 ApplyV6MainLayoutFix.py
python3 ApplyV6CompileFixes.py

python3 - <<'PY'
from pathlib import Path
p = Path('ApplyV63MainLayout.py')
s = p.read_text(encoding='utf-8')
start = s.find('# Richer labels for the large V6.3 cards.')
end = s.find("p.write_text(s, encoding='utf-8')", start)
if start < 0 or end < 0:
    raise SystemExit('V3.0 build preparation: V6.3 label-check block not found')
s = s[:start] + "# Card labels are patched separately.\n\n" + s[end:]
p.write_text(s, encoding='utf-8')
PY
python3 ApplyV63MainLayout.py
python3 ApplyV63CardLabels.py
python3 ApplyV64Layout.py
python3 ApplyV63TechnicalWorkspace.py
python3 ApplyV65Polish.py
python3 ApplyV65PlayerSync.py
python3 ApplyV651Fix.py
python3 ApplyV652Volume.py
python3 ApplyV662BottomAndSlotMenu.py
python3 ApplyV663Workflow.py
python3 ApplyFastScrollFix.py
python3 ApplyV664Performance.py
python3 ApplyV667AsyncBridge.py
python3 ApplyV668PianoSplitAndMeasures.py
python3 ApplyV669ConceptAndDiagnostic.py
python3 ApplyV6610DiagnosticPipeline.py
python3 ApplyV6611UnifiedMusicChat.py
python3 ApplyV670ContextMusicChat.py
python3 ApplyV671DialogFirst.py
python3 ApplyV672DiagnosticSaveFix.py
python3 ApplyV673ActorFix.py
python3 ApplyV674DialogAndDiagnosticUX.py
python3 ApplyV675DiagnosticModalAndPreparedState.py
python3 ApplyV300MusicChatCore.py
python3 ApplyV301Corrections.py

SRC=(Sources/*.swift)
echo "Baue Composition Lab Native 3.0.1 …"
echo

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "FEHLER: Apples Command Line Tools fehlen."
  echo "Installiere sie mit: xcode-select --install"
  read -r -p "Return zum Beenden …"
  exit 1
fi
SDK="$(xcrun --sdk macosx --show-sdk-path)"
pkill -x "Composition Lab" >/dev/null 2>&1 || true
sleep 1
RECOVERED_ICNS=""
if [ ! -f "AppIcon.png" ]; then
  OLD_PNG="$(find "$HOME/Downloads" -type f -name 'AppIcon.png' -path '*Composition_Lab_Native*' 2>/dev/null | head -n 1 || true)"
  if [ -n "$OLD_PNG" ]; then cp "$OLD_PNG" AppIcon.png; else RECOVERED_ICNS="$(find "$HOME/Downloads" "$HOME/Applications" /Applications -type f -path '*/Composition Lab.app/Contents/Resources/AppIcon.icns' 2>/dev/null | head -n 1 || true)"; fi
fi
rm -rf "$BUILD" "$APP"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
if [ -f "Composition_Lab_Benutzerhandbuch_V3_0.pdf" ]; then cp "Composition_Lab_Benutzerhandbuch_V3_0.pdf" "$APP/Contents/Resources/"; fi
if [ -f "AppIcon.png" ]; then
  ICONSET="$BUILD/AppIcon.iconset"; mkdir -p "$ICONSET"
  sips -z 16 16 AppIcon.png --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 AppIcon.png --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 AppIcon.png --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 AppIcon.png --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 AppIcon.png --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 AppIcon.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 AppIcon.png --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 AppIcon.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 AppIcon.png --out "$ICONSET/icon_512x512.png" >/dev/null
  cp AppIcon.png "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  cp AppIcon.png "$APP/Contents/Resources/AppIcon.png"
elif [ -n "$RECOVERED_ICNS" ]; then cp "$RECOVERED_ICNS" "$APP/Contents/Resources/AppIcon.icns"; fi

build_arch () {
  local arch="$1"; local out="$BUILD/Composition Lab-$arch"
  echo "Kompiliere für $arch …"
  xcrun swiftc "${SRC[@]}" -sdk "$SDK" -target "${arch}-apple-macosx11.0" -O -framework Cocoa -framework Security -framework CryptoKit -framework AVFoundation -framework CoreMIDI -framework AudioToolbox -framework WebKit -framework PDFKit -o "$out"
}
build_arch x86_64
if build_arch arm64; then
  echo "Erzeuge Universal Binary (Intel + Apple Silicon) …"
  xcrun lipo -create "$BUILD/Composition Lab-x86_64" "$BUILD/Composition Lab-arm64" -output "$APP/Contents/MacOS/Composition Lab"
else
  cp "$BUILD/Composition Lab-x86_64" "$APP/Contents/MacOS/Composition Lab"
fi
chmod +x "$APP/Contents/MacOS/Composition Lab"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo
echo "FERTIG: $PWD/$APP"
echo "Version: 3.0.1 (Build 301) · Engine Build 14"
echo "3.0.1: musikalisch vollständigere editierbare Idee, redundante Impulsanzeige entfernt, Diagnose direkt in Downloads."
open "$APP" || true
