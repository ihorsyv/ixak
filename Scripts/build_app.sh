#!/bin/bash
# Builds IXAK.app — a proper macOS app bundle with icon and Info.plist —
# wrapping the SwiftPM executable. Fully offline, no external tools needed
# beyond the Xcode command line tools already installed.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
swift build -c "$CONFIG"

BIN_PATH=$(swift build -c "$CONFIG" --show-bin-path)
APP_DIR="build/IXAK.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH/IXAK" "$APP_DIR/Contents/MacOS/IXAK"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "Built $APP_DIR"
