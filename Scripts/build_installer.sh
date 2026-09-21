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

# The project lives under ~/Desktop, which iCloud Drive syncs — its file
# provider daemon re-tags any bundle sitting there with FinderInfo/
# provenance xattrs, often within under a second of it landing on disk.
# codesign rejects a signed bundle carrying those ("resource fork, Finder
# information, or similar detritus not allowed"), and re-stripping in
# place here isn't enough: iCloud can win the race again before pkgbuild
# gets to read the tree. The only reliable fix is to stage, sign and
# package entirely outside the synced folder, in a plain /tmp directory,
# and only bring the finished single-file .pkg back into build/.
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
PKGROOT="$STAGING/pkgroot"
mkdir -p "$PKGROOT/Applications"
cp -R "build/IXAK.app" "$PKGROOT/Applications/IXAK.app"

xattr -cr "$PKGROOT/Applications/IXAK.app"
codesign --force --deep -s - "$PKGROOT/Applications/IXAK.app"
if ! codesign --verify --deep --strict "$PKGROOT/Applications/IXAK.app" 2>/dev/null; then
    echo "error: IXAK.app still fails codesign verification after stripping xattrs — installer would be broken. Not packaging." >&2
    exit 1
fi

OUT="build/IXAK Installer.pkg"
rm -f "$OUT"

pkgbuild \
    --root "$PKGROOT" \
    --scripts Scripts/pkg-scripts \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    "$STAGING/IXAK Installer.pkg"

cp "$STAGING/IXAK Installer.pkg" "$OUT"

echo "Built '$OUT'"
echo "Send it as-is (Telegram, AirDrop, etc.) — it's one file, no zip needed."
