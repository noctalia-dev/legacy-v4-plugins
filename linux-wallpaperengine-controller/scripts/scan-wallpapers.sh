#!/bin/bash

# Scan wallpaper folders and extract metadata for panel listing.
# Arg 1: Wallpaper Engine workshop directory
# (Any further arguments are ignored, as the script no longer uses multi-mode)
# Output:
#   Tab-separated rows:
#   <path>\t<name>\t<thumb>\t<motion>\t<dynamic>\t<id>\t<type>\t<resolution>\t<embedded_audio>\t<audio_reactive>\t<bytes>:<mtime>\t<approved>\t<description>

set -eu
dir="${1:-}"
[ -n "$dir" ] || exit 10
[ -d "$dir" ] || exit 10

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/scan_wallpapers.py"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$PY_SCRIPT" "$dir"
fi

# Fallback: scan without metadata (when python3 is missing)
for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    id_val="$(basename "$d")"
    thumb=""
    for f in "preview.jpg" "preview.png" "preview.jpeg" "screenshot.jpg" "screenshot.png" "screenshot.jpeg"; do
        [ -f "$d/$f" ] && { thumb="$d/$f"; break; }
    done
    [ -z "$thumb" ] && continue
    printf '%s\t%s\t%s\t\t0\t%s\tunknown\tunknown\t0\t0\t0:0\t0\t\n' "$d" "$id_val" "$thumb" "$id_val"
done
