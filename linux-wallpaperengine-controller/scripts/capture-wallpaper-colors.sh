#!/bin/bash

# Generate a single screenshot for wallpaper color extraction.
# Args:
#   1: output screenshot path
#   2..n: linux-wallpaperengine command and arguments

set -eu

output_file="$1"
shift

output_dir=$(dirname "$output_file")
mkdir -p "$output_dir"
rm -f "$output_file"

"$@" >/dev/null 2>&1 &
wallpaper_pid=$!

cleanup() {
  kill "$wallpaper_pid" >/dev/null 2>&1 || true
  wait "$wallpaper_pid" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

for _ in $(seq 1 150); do
  if [ -s "$output_file" ]; then
    exit 0
  fi

  if ! kill -0 "$wallpaper_pid" >/dev/null 2>&1; then
    break
  fi

  sleep 0.2
done

[ -s "$output_file" ]
