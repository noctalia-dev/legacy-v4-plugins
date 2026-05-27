#!/bin/bash

# Clear cached color screenshots while preserving provided file paths.
# Args:
#   1: cache directory path
#   2..n: screenshot file paths to keep

set -eu

if [ "$#" -lt 1 ]; then
  exit 20
fi

cache_dir="${1:-}"
shift

normalized_cache_dir="$(realpath -m -- "$cache_dir")"

case "$normalized_cache_dir" in
  *"/../"*|".."|../*|*/..)
    exit 20
    ;;
esac

case "$normalized_cache_dir" in
  ""|"/")
    exit 20
    ;;
  */plugins/*)
    ;;
  *)
    exit 20
    ;;
esac

plugins_root="${normalized_cache_dir%/plugins/*}/plugins"
case "$normalized_cache_dir" in
  "$plugins_root"/*)
    ;;
  *)
    exit 20
    ;;
esac

mkdir -p "$normalized_cache_dir"

preserved_paths=()
for preserved in "$@"; do
  normalized_preserved="$(realpath -m -- "$preserved")"
  case "$normalized_preserved" in
    "$normalized_cache_dir"/*)
      preserved_paths+=("$normalized_preserved")
      ;;
  esac
done

for item in "$normalized_cache_dir"/*; do
  [ -e "$item" ] || continue

  normalized_item="$(realpath -m -- "$item")"
  case "$normalized_item" in
    "$normalized_cache_dir"/*)
      ;;
    *)
      continue
      ;;
  esac

  keep=0
  for preserved in "${preserved_paths[@]}"; do
    if [ "$normalized_item" = "$preserved" ]; then
      keep=1
      break
    fi
  done

  if [ "$keep" -eq 0 ]; then
    rm -rf "$normalized_item"
  fi
done
