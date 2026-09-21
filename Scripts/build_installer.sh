#!/bin/bash
# Builds a standard macOS .pkg installer for IXAK.app: a single file that
# survives Telegram/AirDrop transfer intact (no folder/zip round trip to
# lose permissions in), opens in the familiar Installer.app wizard, and
# installs to /Applications. The postinstall script (Scripts/pkg-scripts)
# clears quarantine, restores +x and re-signs ad-hoc, then adds a Desktop
# shortcut for the logged-in user — no Terminal needed on the other end.
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/build_app.sh release --universal

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
IDENTIFIER="com.ihorsyvash.ixak.installer"

PKGROOT="build/pkgroot"
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT/Applications"
cp -R "build/IXAK.app" "$PKGROOT/Applications/IXAK.app"

OUT="build/IXAK Installer.pkg"
rm -f "$OUT"

pkgbuild \
    --root "$PKGROOT" \
    --scripts Scripts/pkg-scripts \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    "$OUT"

rm -rf "$PKGROOT"

echo "Built '$OUT'"
echo "Send it as-is (Telegram, AirDrop, etc.) — it's one file, no zip needed."
