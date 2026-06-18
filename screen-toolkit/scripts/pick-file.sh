#!/usr/bin/env bash
# XDG-portal-aware file picker with GUI fallbacks.
# Portal logic lives in pick-file-portal.py (same directory).

FILTER_GLOB="*.png *.jpg *.jpeg *.webp *.gif *.bmp *.mp4 *.webm *.mkv *.mov"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try portal first (requires python3-gi)
if python3 -c "import gi" 2>/dev/null && python3 "$SCRIPT_DIR/pick-file.py"; then
    exit 0
fi

# GUI fallbacks
if command -v zenity >/dev/null 2>&1; then
    zenity --file-selection --title="Pin image" \
        --file-filter="Images & Videos | $FILTER_GLOB" 2>/dev/null
elif command -v kdialog >/dev/null 2>&1; then
    kdialog --getopenfilename '' "Images & Videos ($FILTER_GLOB)" 2>/dev/null
else
    exit 2
fi

