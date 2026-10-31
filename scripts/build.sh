#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="$PWD/dist/MDV.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MDV "$APP/Contents/MacOS/MDV"
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/icon.swift "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built: $APP"
