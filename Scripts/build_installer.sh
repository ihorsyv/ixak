#!/bin/bash
# Builds a double-clickable IXAK Installer.app: compiled from
# Installer.applescript via osacompile (ships with every Mac, nothing to
# install), with the universal IXAK.app embedded as a resource. On launch
# it asks the user where to install, copies the app there, adds a Desktop
# shortcut, and deletes itself. Fully offline.
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/build_app.sh release --universal

INSTALLER_DIR="build/IXAK Installer.app"
rm -rf "$INSTALLER_DIR"

osacompile -o "$INSTALLER_DIR" Scripts/Installer.applescript

cp -R "build/IXAK.app" "$INSTALLER_DIR/Contents/Resources/IXAK.app"
cp "Resources/AppIcon.icns" "$INSTALLER_DIR/Contents/Resources/applet.icns"

echo "Built '$INSTALLER_DIR'"
echo "Zip it for transfer: (cd build && zip -r -y 'IXAK Installer.zip' 'IXAK Installer.app')"
