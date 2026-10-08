#!/bin/zsh
# Assembles build/Gaveta.app from the SwiftPM products.
#
# Usage: Scripts/make-app.sh [debug|release]
#
# Environment:
#   SIGN_IDENTITY  codesign identity; "-" (default) signs ad-hoc for local use.
#                  For distribution: "Developer ID Application: Your Name (TEAMID)".
#   BUNDLE_ID      bundle identifier (default: app.gaveta.Gaveta; set your own for releases).
#   UNIVERSAL      1 to build arm64 + x86_64 (release only).
#
# Notarization is done by Scripts/release.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUNDLE_ID="${BUNDLE_ID:-app.gaveta.Gaveta}"
UNIVERSAL="${UNIVERSAL:-0}"
VERSION="$(tr -d '[:space:]' < VERSION)"

BUILD_FLAGS=(-c "$CONFIG")
if [[ "$UNIVERSAL" == "1" ]]; then
    BUILD_FLAGS+=(--arch arm64 --arch x86_64)
fi

swift build "${BUILD_FLAGS[@]}" --product GavetaApp
swift build "${BUILD_FLAGS[@]}" --product gaveta
BIN="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

APP="build/Gaveta.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers"
cp "$BIN/GavetaApp" "$APP/Contents/MacOS/Gaveta"
cp "$BIN/gaveta" "$APP/Contents/Helpers/gaveta"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>Gaveta</string>
    <key>CFBundleDisplayName</key><string>Gaveta</string>
    <key>CFBundleExecutable</key><string>Gaveta</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    SIGN_FLAGS=(--force --sign -)
else
    # Hardened runtime + secure timestamp are required for notarization.
    SIGN_FLAGS=(--force --options runtime --timestamp --sign "$SIGN_IDENTITY")
fi

# Sign inside-out: the helper first, then the bundle (no --deep).
codesign "${SIGN_FLAGS[@]}" --identifier "${BUNDLE_ID}.cli" "$APP/Contents/Helpers/gaveta"
codesign "${SIGN_FLAGS[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "Built: $APP ($VERSION, $BUNDLE_ID, signed with: $SIGN_IDENTITY)"
