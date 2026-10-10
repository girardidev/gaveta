#!/bin/zsh
# Manual regression check for the menu bar popover height (needs a real click, so it is not part of
# `swift test`). It opens the popover of build/Gaveta.app, adds and removes temporary folders (aliases
# starting with "chk-"), and verifies the panel always matches its content.
#
# Requires: Scripts/make-app.sh run before; Accessibility permission for your terminal
# (System Settings > Privacy & Security > Accessibility). Takes control of the mouse for a moment.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Gaveta.app"
GAVETA="$APP/Contents/Helpers/gaveta"
[[ -x "$GAVETA" ]] || { echo "error: $APP not found; run Scripts/make-app.sh first." >&2; exit 1; }
TMP="$(mktemp -d)"
cleanup() {
    for alias in $("$GAVETA" list --json | grep -o '"alias" : "chk-[^"]*"' | cut -d'"' -f4); do "$GAVETA" remove "$alias" >/dev/null; done
    rm -rf "$TMP"; pkill -x Gaveta || true
}
trap cleanup EXIT

item_center() {
    osascript -e 'tell application "System Events" to tell process "Gaveta" to return (position of menu bar item 1 of menu bar 2) & (size of menu bar item 1 of menu bar 2)' \
        | awk -F', ' '{ printf "%d %d", $1 + $3 / 2, $2 + $4 / 2 }'
}
click() {
    read -r x y <<< "$(item_center)"
    osascript -l JavaScript -e "
        ObjC.import('CoreGraphics');
        for (const t of [\$.kCGEventLeftMouseDown, \$.kCGEventLeftMouseUp]) {
            \$.CGEventPost(\$.kCGHIDEventTap, \$.CGEventCreateMouseEvent(\$(), t, \$.CGPointMake($x, $y), \$.kCGMouseButtonLeft));
            delay(0.05);
        }" >/dev/null
}
# Height of the on-screen popover window, or empty when it is closed.
panel_height() {
    osascript -l JavaScript -e "
        ObjC.import('CoreGraphics');
        const list = ObjC.deepUnwrap(ObjC.castRefToObject(\$.CGWindowListCopyWindowInfo(\$.kCGWindowListOptionOnScreenOnly, 0)));
        const w = list.find(w => w.kCGWindowOwnerName === 'Gaveta' && w.kCGWindowLayer === 101);
        w ? String(Math.round(w.kCGWindowBounds.Height)) : '';"
}
add_folders() { for i in $(seq 1 $1); do mkdir -p "$TMP/$i"; "$GAVETA" add "$TMP/$i" --alias "chk-$i" >/dev/null; done; sleep 1.2; }
remove_folders() { for i in $(seq 1 $1); do "$GAVETA" remove "chk-$i" >/dev/null; done; sleep 1.2; }
reopen() { click; sleep 0.8; click; sleep 1; }

failures=0
expect_equal() { # name actual expected
    if [[ "$2" == "$3" ]]; then echo "ok    $1: $2"; else echo "FAIL  $1: got '$2', expected '$3'"; failures=$((failures + 1)); fi
}
expect_greater() { # name actual than
    if [[ -n "$2" && "$2" -gt "$3" ]]; then echo "ok    $1: $2 > $3"; else echo "FAIL  $1: got '$2', expected more than $3"; failures=$((failures + 1)); fi
}

pkill -x Gaveta 2>/dev/null || true; sleep 0.5
"$APP/Contents/MacOS/Gaveta" >/dev/null 2>&1 &
sleep 2

click; sleep 1.2
base="$(panel_height)"
if [[ -z "$base" ]]; then click; sleep 1.2; base="$(panel_height)"; fi # first click can land before the item is ready
[[ -n "$base" ]] || { echo "error: the popover did not open (is Accessibility allowed for this terminal?)" >&2; exit 1; }
echo "baseline panel height: $base"

add_folders 4
expect_greater "grows while open (+4 folders)" "$(panel_height)" "$base"
remove_folders 4
expect_equal "shrinks while open (-4 folders)" "$(panel_height)" "$base"

click; sleep 0.8
add_folders 8
click; sleep 1.2
expect_greater "reopens taller (+8 folders, scrolling list)" "$(panel_height)" "$base"
click; sleep 0.8
remove_folders 8
click; sleep 1.2
expect_equal "reopens at baseline after removing folders while closed" "$(panel_height)" "$base"
click

if (( failures > 0 )); then echo "$failures check(s) failed."; exit 1; fi
echo "All popover checks passed."
