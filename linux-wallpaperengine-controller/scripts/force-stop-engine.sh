#!/bin/bash

# Stop any running linux-wallpaperengine processes started by this plugin.

set -eu

if command -v pkill >/dev/null 2>&1; then
  pkill -x linux-wallpaper >/dev/null 2>&1 || true
  pkill -f '(^|/)linux-wallpaperengine([[:space:]]|$)' >/dev/null 2>&1 || true
fi
