#!/usr/bin/env bash
# mirror-screenshot.sh — process and save a mirror screenshot
# Args: $1=src $2=destDir $3=destFile $4=filters (optional, comma-separated ffmpeg -vf string)
# Exit codes:
#   1 — invalid arguments or source not found
#   2 — failed to create destination directory
#   3 — ffmpeg processing failed
#   4 — file move failed
set -euo pipefail

SRC="${1:-}"
DEST_DIR="${2:-}"
DEST_FILE="${3:-}"
FILTERS="${4:-}"

[ -n "$SRC" ]       || exit 1
[ -n "$DEST_DIR" ]  || exit 1
[ -n "$DEST_FILE" ] || exit 1
[ -f "$SRC" ]       || exit 1

mkdir -p "$DEST_DIR" || exit 2

DEST="${DEST_DIR}/${DEST_FILE}"

if [ -n "$FILTERS" ]; then
    ffmpeg -y -i "$SRC" \
        -vf "$FILTERS" \
        -compression_level 0 -update 1 \
        "$DEST" 2>/dev/null || exit 3
    rm -f "$SRC"
else
    mv "$SRC" "$DEST" || exit 4
fi

printf '%s\n' "$DEST"

