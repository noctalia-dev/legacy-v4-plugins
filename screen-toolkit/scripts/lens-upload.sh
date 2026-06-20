#!/usr/bin/env bash
set -euo pipefail
GX="$1"; GY="$2"; GW="$3"; GH="$4"
FILE="/tmp/screen-toolkit-lens.png"

# Exit 1 — missing dependency (dep name written to stdout for QML)
for dep in grim curl jq xdg-open; do
    command -v "$dep" >/dev/null 2>&1 || { echo "$dep"; exit 1; }
done

# Exit 2 — capture failed
grim -g "${GX},${GY} ${GW}x${GH}" "$FILE" 2>/dev/null || exit 2

# Exit 3 — upload failed
RESP=$(curl -sS -f -A 'Mozilla/5.0' --connect-timeout 20 --max-time 60 \
  -F "files[]=@$FILE" 'https://uguu.se/upload' 2>/dev/null) || \
RESP=$(curl -sS -A 'Mozilla/5.0' --connect-timeout 20 --max-time 60 \
  -F "files[]=@$FILE" 'https://uguu.se/upload.php' 2>/dev/null)

rm -f "$FILE"

URL=$(printf '%s' "$RESP" | jq -r '.files[0].url // empty' 2>/dev/null)
if [ -n "$URL" ] && [[ "$URL" == http* ]]; then
    xdg-open "https://lens.google.com/uploadbyurl?url=$URL" >/dev/null 2>&1 &
else
    exit 3
fi
