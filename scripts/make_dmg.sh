#!/bin/bash
# Packages build/TLang.app into a drag-to-install DMG.
# Usage: ./scripts/make_dmg.sh   (run ./build.sh first)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/TLang.app"
[ -d "$APP" ] || { echo "error: $APP not found — run ./build.sh first"; exit 1; }

VERSION=$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString)
DMG="build/TLang-$VERSION.dmg"

# Stage: the app + an /Applications symlink for drag-to-install.
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "TLang $VERSION" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov "$DMG" >/dev/null
rm -rf "$STAGE"

echo "Created: $DMG"
shasum -a 256 "$DMG"
