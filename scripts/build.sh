#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release "$@"
BIN_DIR="$(swift build -c release "$@" --show-bin-path)"
APP="$PWD/dist/MDV.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MDV" "$APP/Contents/MacOS/MDV"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
swift scripts/icon.swift "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built: $APP"
