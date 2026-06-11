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
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TLang "$APP/Contents/MacOS/TLang"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> Code signing (ad-hoc)"
codesign --force --sign - "$APP"

echo ""
echo "Done: $APP"
echo "Install with:  cp -R $APP /Applications/"
