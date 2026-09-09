#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="Composition Lab.app"
BUILD=".build-native"

# Restore the previously stable workspace architecture before compilation:
# one neutral NSView container; workspaces switch only via isHidden.
# Also replaces the last hard-coded V5.0.12 window title with the version
# from Info.plist.
python3 ApplyWorkspaceLayoutFix.py

SRC=(Sources/*.swift)

echo "Baue Composition Lab Native V5.0.16 …"
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

# The repository cleanup intentionally contained only text source files and
# therefore lost AppIcon.png. Recover the original icon from an older local
# Composition Lab Native build/source folder when it is available.
RECOVERED_ICNS=""
if [ ! -f "AppIcon.png" ]; then
  OLD_PNG="$(find "$HOME/Downloads" -type f -name 'AppIcon.png' -path '*Composition_Lab_Native*' 2>/dev/null | head -n 1 || true)"
  if [ -n "$OLD_PNG" ]; then
    echo "Original-Icon gefunden: $OLD_PNG"
    cp "$OLD_PNG" AppIcon.png
  else
    RECOVERED_ICNS="$(find "$HOME/Downloads" "$HOME/Applications" /Applications -type f -path '*/Composition Lab.app/Contents/Resources/AppIcon.icns' 2>/dev/null | head -n 1 || true)"
    if [ -n "$RECOVERED_ICNS" ]; then
      echo "Original-Icon aus älterer Composition Lab.app gefunden."
    else
      echo "Hinweis: Kein älteres Composition-Lab-Icon auf diesem Mac gefunden."
    fi
  fi
fi

rm -rf "$BUILD" "$APP"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

if [ -f "Composition_Lab_Benutzerhandbuch_V3_0.pdf" ]; then
  cp "Composition_Lab_Benutzerhandbuch_V3_0.pdf" "$APP/Contents/Resources/"
fi

if [ -f "AppIcon.png" ]; then
  ICONSET="$BUILD/AppIcon.iconset"
  mkdir -p "$ICONSET"
  sips -z 16 16     AppIcon.png --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32     AppIcon.png --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     AppIcon.png --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64     AppIcon.png --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   AppIcon.png --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256   AppIcon.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   AppIcon.png --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512   AppIcon.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   AppIcon.png --out "$ICONSET/icon_512x512.png" >/dev/null
  cp AppIcon.png "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  cp AppIcon.png "$APP/Contents/Resources/AppIcon.png"
elif [ -n "$RECOVERED_ICNS" ]; then
  cp "$RECOVERED_ICNS" "$APP/Contents/Resources/AppIcon.icns"
fi

build_arch () {
  local arch="$1"
  local out="$BUILD/Composition Lab-$arch"
  echo "Kompiliere für $arch …"
  xcrun swiftc "${SRC[@]}" \
    -sdk "$SDK" \
    -target "${arch}-apple-macosx11.0" \
    -Onone \
    -framework Cocoa \
    -framework Security \
    -framework CryptoKit \
    -framework AVFoundation \
    -framework CoreMIDI \
    -framework AudioToolbox \
    -framework WebKit \
    -framework PDFKit \
    -o "$out"
}

build_arch x86_64

if build_arch arm64; then
  echo "Erzeuge Universal Binary (Intel + Apple Silicon) …"
  xcrun lipo -create \
    "$BUILD/Composition Lab-x86_64" \
    "$BUILD/Composition Lab-arm64" \
    -output "$APP/Contents/MacOS/Composition Lab"
else
  echo
  echo "Hinweis: arm64-Build nicht möglich; Intel-Fassung wird trotzdem erstellt."
  cp "$BUILD/Composition Lab-x86_64" "$APP/Contents/MacOS/Composition Lab"
fi

chmod +x "$APP/Contents/MacOS/Composition Lab"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo
echo "FERTIG:"
echo "  $PWD/$APP"
echo "  Version: 5.0.16 (Build 88) · Engine Build 14"
echo
echo "Die App ist nativ (AppKit), kein HTML/WebView."
echo "API-Schlüssel werden im normalen Betrieb nicht im macOS-Schlüsselbund gespeichert."
echo
open "$APP" || true
