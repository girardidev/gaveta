#!/bin/zsh
# Assembles build/Gaveta.app from the SwiftPM products (development build, ad-hoc signed).
# Developer ID signing and notarization come with the release script.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG" --product GavetaApp
swift build -c "$CONFIG" --product gaveta
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Gaveta.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers"
cp "$BIN/GavetaApp" "$APP/Contents/MacOS/Gaveta"
cp "$BIN/gaveta" "$APP/Contents/Helpers/gaveta"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>app.gaveta.Gaveta</string>
    <key>CFBundleName</key><string>Gaveta</string>
    <key>CFBundleDisplayName</key><string>Gaveta</string>
    <key>CFBundleExecutable</key><string>Gaveta</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP/Contents/Helpers/gaveta"
codesign --force --sign - "$APP"
echo "Built: $APP"
