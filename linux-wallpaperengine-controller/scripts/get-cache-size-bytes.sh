#!/bin/bash

# Print the cache directory size in bytes.
# Args:
#   1: cache directory path

set -eu

cache_dir="$1"

if [ -d "$cache_dir" ]; then
  du -sb "$cache_dir" | cut -f1
else
  printf '0'
fi
