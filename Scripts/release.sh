#!/bin/zsh
# Builds, signs, notarizes and zips Gaveta.app for distribution outside the App Store.
#
# Usage: Scripts/release.sh [--check]
#   --check   only verify the signing identity and notarization profile, then stop.
#
# Required environment:
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   BUNDLE_ID       your reverse-DNS identifier, e.g. io.github.you.gaveta
#   NOTARY_PROFILE  name of a notarytool keychain profile, created once with:
#                   xcrun notarytool store-credentials "gaveta-notary" \
#                       --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
#
# Output: dist/Gaveta-<version>.zip (stapled and Gatekeeper-checked) and its SHA-256.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "error: $*" >&2; exit 1; }

for var in SIGN_IDENTITY BUNDLE_ID NOTARY_PROFILE; do
    [[ -n "${(P)var:-}" ]] || fail "$var is not set. See the header of Scripts/release.sh."
done
[[ "$SIGN_IDENTITY" == Developer\ ID\ Application:* ]] \
    || fail "SIGN_IDENTITY must start with \"Developer ID Application:\" (got \"$SIGN_IDENTITY\")."
[[ "$BUNDLE_ID" != "app.gaveta.Gaveta" ]] || fail "set your own BUNDLE_ID; the default is a placeholder."

security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY" \
    || fail "identity not found in your keychain: $SIGN_IDENTITY (list with: security find-identity -v -p codesigning)"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "notarytool profile \"$NOTARY_PROFILE\" not found or invalid (create it with: xcrun notarytool store-credentials)."

if [[ "${1:-}" == "--check" ]]; then
    echo "OK: identity and notarization profile are usable."
    exit 0
fi

VERSION="$(tr -d '[:space:]' < VERSION)"
APP="build/Gaveta.app"

SIGN_IDENTITY="$SIGN_IDENTITY" BUNDLE_ID="$BUNDLE_ID" UNIVERSAL=1 Scripts/make-app.sh release
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Submitting to Apple notary service (this can take a few minutes)..."
ditto -c -k --keepParent "$APP" build/Gaveta-notarize.zip
xcrun notarytool submit build/Gaveta-notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
rm -f build/Gaveta-notarize.zip

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

mkdir -p dist
ARCHIVE="dist/Gaveta-${VERSION}.zip"
rm -f "$ARCHIVE"
ditto -c -k --keepParent "$APP" "$ARCHIVE"
echo "Done: $ARCHIVE"
shasum -a 256 "$ARCHIVE"
