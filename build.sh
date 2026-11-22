#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/PSVSwitcher.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/PSVSwitcher" "$APP/Contents/MacOS/PSVSwitcher"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# ad-hoc sign to stabilise TCC/Accessibility identity
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "Built: $(pwd)/$APP"