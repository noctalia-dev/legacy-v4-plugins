#!/bin/bash

# Return success when the provided file path exists.
# Args:
#   1: file path to check

set -eu

file_path="$1"

[ -f "$file_path" ]
