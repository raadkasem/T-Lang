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

VOLNAME="TLang $VERSION"
# Detach any stale mount of this volume (avoids "Resource busy").
hdiutil detach "/Volumes/$VOLNAME" -force >/dev/null 2>&1 || true

rm -f "$DMG"
# hdiutil intermittently reports "Resource busy" on CI — retry a few times.
attempt=1
until hdiutil create \
        -volname "$VOLNAME" \
        -srcfolder "$STAGE" \
        -fs HFS+ \
        -format UDZO \
        -ov "$DMG" >/dev/null 2>/tmp/hdiutil_err; do
    if [ "$attempt" -ge 4 ]; then
        echo "error: hdiutil create failed after $attempt attempts"; cat /tmp/hdiutil_err
        rm -rf "$STAGE"; exit 1
    fi
    echo "hdiutil busy (attempt $attempt) — retrying…"; cat /tmp/hdiutil_err || true
    attempt=$((attempt + 1))
    sleep 5
done
rm -rf "$STAGE"

echo "Created: $DMG"
shasum -a 256 "$DMG"
