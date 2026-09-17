#!/bin/bash
# Builds IXAK.app — a proper macOS app bundle with icon and Info.plist —
# wrapping the SwiftPM executable. Fully offline, no external tools needed
# beyond the Xcode command line tools already installed.
#
# Usage: build_app.sh [debug|release] [--universal]
# --universal links arm64 + x86_64 into one binary via lipo, so the same
# .app runs on both Apple Silicon and Intel Macs without any tooling
# installed on the target machine.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="debug"
UNIVERSAL=0
for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=1 ;;
        debug|release) CONFIG="$arg" ;;
    esac
done

APP_DIR="build/IXAK.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

if [ "$UNIVERSAL" -eq 1 ]; then
    swift build -c "$CONFIG" --arch arm64 --arch x86_64
    BIN_PATH=$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)
    cp "$BIN_PATH/IXAK" "$APP_DIR/Contents/MacOS/IXAK"
    echo "Universal binary: $(lipo -archs "$APP_DIR/Contents/MacOS/IXAK")"
else
    swift build -c "$CONFIG"
    BIN_PATH=$(swift build -c "$CONFIG" --show-bin-path)
    cp "$BIN_PATH/IXAK" "$APP_DIR/Contents/MacOS/IXAK"
fi

cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    :
else
    GIT_COMMIT="${GIT_COMMIT}-dirty"
fi
/usr/libexec/PlistBuddy -c "Set :IXAKGitCommit $GIT_COMMIT" "$APP_DIR/Contents/Info.plist"

# Zip transfer (and Telegram's own sandboxing on the sending side) can strip
# the executable bit and always invalidates any prior signature, so both are
# reasserted here rather than left to whoever builds/repackages downstream.
chmod +x "$APP_DIR/Contents/MacOS/IXAK"
xattr -cr "$APP_DIR"
codesign --force --deep -s - "$APP_DIR"

echo "Built $APP_DIR (commit $GIT_COMMIT)"
