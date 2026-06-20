#!/usr/bin/env bash
# capture.sh <action> [args...]
#
# Actions:
#   annotate-window          — capture the focused Hyprland window with grim
#                              output: /tmp/screen-toolkit-annotate.png
#                              stdout: "X,Y WxH" geometry string
#   pin       <geometry>     — capture a region at 2× scale with grim
#                              stdout: "/path/to/file.png|WxH"
#   palette   <geometry>     — extract 8 dominant hex colours from a captured region
#                              stdout: one "#RRGGBB" per line
#   qr        <geometry>     — capture a region and decode any QR / barcode found
#                              stdout: decoded text
#
# Exit codes:
#   1 — missing / invalid arguments
#   2 — capture or decode failed
#   3 — missing dependency (hyprctl, jq, grim, magick, zbarimg)
#
# Used by: Main.qml (annotateWinProc, pinGrimProc, paletteProc, qrProc)

set -euo pipefail

ACTION="${1:-}"

_require() {
    command -v "$1" >/dev/null 2>&1 \
        || { echo "ERROR: missing dependency: $1" >&2; exit 3; }
}

case "$ACTION" in

  annotate-window)
    _require hyprctl
    _require jq
    _require grim
    WIN=$(hyprctl activewindow -j 2>/dev/null) \
    || { echo "ERROR: hyprctl failed" >&2; exit 2; }
    GEOM=$(printf '%s' "$WIN" \
    | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)
    [ -n "$GEOM" ] \
    || { echo "ERROR: could not parse window geometry" >&2; exit 2; }
    grim -g "$GEOM" /tmp/screen-toolkit-annotate.png 2>/dev/null \
    || { echo "ERROR: grim capture failed" >&2; exit 2; }
    printf '%s\n' "$GEOM"
    ;;

  pin)
    GEOMETRY="${2:-}"
    [ -n "$GEOMETRY" ] || { echo "ERROR: pin: missing <geometry>" >&2; exit 1; }
    _require grim

    FILE="/tmp/screen-toolkit-pin-$(date +%s%3N).png"
    WH="${GEOMETRY##* }"   # "WxH" portion of "X,Y WxH"

    grim -s 2 -g "$GEOMETRY" "$FILE" 2>/dev/null \
        || { echo "ERROR: pin: grim capture failed" >&2; exit 2; }

    printf '%s|%s\n' "$FILE" "$WH"
    ;;

  palette)
    GEOMETRY="${2:-}"
    [ -n "$GEOMETRY" ] || { echo "ERROR: palette: missing <geometry>" >&2; exit 1; }
    _require grim
    _require magick

    FILE="/tmp/screen-toolkit-palette.png"

    grim -g "$GEOMETRY" "$FILE" 2>/dev/null \
        || { echo "ERROR: palette: grim capture failed" >&2; exit 2; }

    magick "$FILE" -alpha off +dither -colors 8 -unique-colors txt:- 2>/dev/null \
        | grep -v '^#' \
        | grep -oP '#[0-9a-fA-F]{6}' \
        | head -8
    ;;

  qr)
    GEOMETRY="${2:-}"
    [ -n "$GEOMETRY" ] || { echo "ERROR: qr: missing <geometry>" >&2; exit 1; }
    _require grim
    _require zbarimg

    grim -g "$GEOMETRY" /tmp/screen-toolkit-qr.png 2>/dev/null \
        || { echo "ERROR: qr: grim capture failed" >&2; exit 2; }

    zbarimg -q --raw /tmp/screen-toolkit-qr.png 2>/dev/null
    ;;

  *)
    echo "ERROR: unknown action '${ACTION}'. Expected: annotate-window | pin | palette | qr" >&2
    exit 1
    ;;

esac
