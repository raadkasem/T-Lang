#!/bin/bash
# Builds TLang.app into ./build/
set -euo pipefail
cd "$(dirname "$0")"

APP=build/TLang.app

echo "==> Generating app icon"
if [ ! -f Resources/AppIcon.icns ]; then
    swift scripts/make_icon.swift Resources || echo "    (icon generation failed — continuing without icon)"
fi

echo "==> Compiling (release)"
swift build -c release

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/TLang "$APP/Contents/MacOS/TLang"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> Bundling Sparkle.framework"
SPARKLE_FW=$(find .build/artifacts -path "*macos-arm64*/Sparkle.framework" -type d 2>/dev/null | head -1)
if [ -z "$SPARKLE_FW" ]; then
    SPARKLE_FW=$(find .build -name "Sparkle.framework" -type d 2>/dev/null | head -1)
fi
[ -n "$SPARKLE_FW" ] || { echo "error: Sparkle.framework not found"; exit 1; }
# ditto preserves the framework's symlinks and existing (ad-hoc) code signatures.
ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"

echo "==> Code signing (ad-hoc, inside-out)"
# Sparkle ships already ad-hoc signed; sign only our own code, then seal the
# bundle without --deep so the framework's signatures stay intact.
codesign --force --options runtime --sign - "$APP/Contents/MacOS/TLang"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "    signature verified"

echo ""
echo "Done: $APP"
echo "Install with:  cp -R $APP /Applications/"
