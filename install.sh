#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="$HOME/Applications/PSVSwitcher.app"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R "build/PSVSwitcher.app" "$DEST"

PLIST="$HOME/Library/LaunchAgents/com.user.psvswitcher.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.user.psvswitcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DEST/Contents/MacOS/PSVSwitcher</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
    <key>StandardOutPath</key><string>/tmp/psvswitcher.out</string>
    <key>StandardErrorPath</key><string>/tmp/psvswitcher.err</string>
</dict>
</plist>
EOF

# unload if loaded
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "Installed to $DEST and registered LaunchAgent."
echo "Grant Accessibility in System Settings -> Privacy & Security -> Accessibility."