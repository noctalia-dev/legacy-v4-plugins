#!/bin/bash

# Detect the Steam workshop folder used by Wallpaper Engine.
# Output:
#   First matching workshop directory path, or empty output if not found

set -eu

for common in "$HOME/.steam/steam/steamapps/common" \
              "$HOME/.local/share/Steam/steamapps/common" \
              "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common" \
              "$HOME/snap/steam/common/.local/share/Steam/steamapps/common"; do
  if [ -d "$common" ]; then
    workshop="${common%/common}/workshop/content/431960"
    if [ -d "$workshop" ]; then
      printf '%s\n' "$workshop"
      exit 0
    fi
  fi
done
exit 0
