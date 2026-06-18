#!/bin/bash

# Update Noctalia's global wallpaper cache entry for a monitor.
# Args:
#   1: screen name
#   2: screenshot path

set -eu

screen_name="${1:-}"
screenshot_path="${2:-}"
cache_file="$HOME/.cache/noctalia/wallpapers.json"

if [ -z "$screen_name" ] || [ -z "$screenshot_path" ]; then
  exit 1
fi

mkdir -p "$(dirname "$cache_file")"

if [ ! -f "$cache_file" ]; then
  printf '%s\n' '{"defaultWallpaper":"","usedRandomWallpapers":{},"wallpapers":{}}' > "$cache_file"
fi

tmp_file="$(mktemp)"
cleanup() {
  rm -f "$tmp_file"
}
trap cleanup EXIT

jq --arg screen "$screen_name" --arg path "$screenshot_path" '
  .wallpapers = (.wallpapers // {}) |
  .usedRandomWallpapers = (.usedRandomWallpapers // {}) |
  .wallpapers[$screen] = {
    "dark": $path,
    "light": $path
  }
' "$cache_file" > "$tmp_file"

mv "$tmp_file" "$cache_file"
