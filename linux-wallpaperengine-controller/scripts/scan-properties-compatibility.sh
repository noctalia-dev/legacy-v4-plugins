#!/bin/bash

# Scan wallpaper folders and mark `--list-properties` compatibility.
# Args:
#   1: Wallpaper Engine workshop directory (contains wallpaper subdirectories)
# Output:
#   Tab-separated rows: <wallpaper_dir>\t<status>
#   status:
#     0 = compatible
#     1 = failed
#     2 = limited editor support

set -eu

dir="$1"
[ -d "$dir" ] || exit 10

find "$dir" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r wallpaper_dir; do
  if ! output="$(linux-wallpaperengine "$wallpaper_dir" --list-properties 2>/dev/null)"; then
    status=1
    printf '%s\t%s\n' "$wallpaper_dir" "$status"
    continue
  fi

  if printf '%s\n' "$output" | grep -Eiq '^[^[:space:]].*[[:space:]]-[[:space:]](slider|boolean|combo|textinput|color)[[:space:]]*$'; then
    status=0
  elif printf '%s\n' "$output" | grep -Eiq '^[^[:space:]].*[[:space:]]-[[:space:]](text|scene texture|[[:alpha:] _-]+)[[:space:]]*$'; then
    status=2
  else
    status=0
  fi

  printf '%s\t%s\n' "$wallpaper_dir" "$status"
done
