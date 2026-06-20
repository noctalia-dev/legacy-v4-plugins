#!/usr/bin/env bash
# Args: $1=gx $2=gy $3=gw $4=gh $5=lang $6=upscale_flag $7=psm

GX="$1"; GY="$2"; GW="$3"; GH="$4"
RAW_LANG="${5:-eng}"
UPSCALE="$6"
USER_PSM="${7:-3}"
FILE="/tmp/screen-toolkit-ocr.png"
TMP_BASE="/tmp/screen-toolkit-ocr-work-$$"
TMP="${TMP_BASE}.pnm"
TMP_NOISE="${TMP_BASE}-nr.pnm"

cleanup() { rm -f "$TMP" "$TMP_NOISE"; }
trap cleanup EXIT

# Exit 1 — missing dependency (dep name written to stdout)
for dep in grim magick tesseract; do
    command -v "$dep" >/dev/null 2>&1 || { echo "$dep"; exit 1; }
done

# Exit 2 — bad/missing args
[ -z "$GX" ] || [ -z "$GY" ] || [ -z "$GW" ] || [ -z "$GH" ] && exit 2

LANG=$(echo "$RAW_LANG" | tr '+' '\n' \
    | grep -v '^osd$' \
    | grep -v '^$' \
    | tr '\n' '+' \
    | sed 's/+$//')
[ -z "$LANG" ] && LANG="eng"

AVAILABLE=$(tesseract --list-langs 2>/dev/null | tail -n +2)
VALID_LANGS=""
IFS='+' read -ra LANG_PARTS <<< "$LANG"
for l in "${LANG_PARTS[@]}"; do
    if echo "$AVAILABLE" | grep -qx "$l"; then
        VALID_LANGS="${VALID_LANGS}+${l}"
    fi
done
LANG="${VALID_LANGS#+}"
[ -z "$LANG" ] && LANG="eng"

# Exit 3 — capture failed
grim -g "${GX},${GY} ${GW}x${GH}" "$FILE" 2>/dev/null || exit 3

if [ -z "$UPSCALE" ] && [ "$GW" -lt 200 ] 2>/dev/null; then
    SCALE=$(awk "BEGIN{printf \"%.0f\", 300 / $GW}")
    UPSCALE="-scale ${SCALE}00%"
fi

# Exit 4 — image processing failed
magick "$FILE" $UPSCALE \
    -colorspace Gray \
    -normalize \
    -contrast-stretch 2%x1% \
    -sharpen 0x1.5 \
    +repage \
    "$TMP" 2>/dev/null || exit 4

MEAN=$(magick "$TMP" -format '%[fx:mean]' info: 2>/dev/null)
if awk "BEGIN{exit !($MEAN < 0.4)}"; then
    magick "$TMP" -negate "$TMP" 2>/dev/null
fi
magick "$TMP" -median 1 "$TMP_NOISE" 2>/dev/null

run_ocr() { tesseract "$1" stdout -l "$LANG" --psm "$2" --oem 1 2>/dev/null; }
count_chars() { printf '%s' "$1" | tr -d '[:space:]' | wc -c; }

TEXT=$(run_ocr "$TMP" "$USER_PSM")
BEST_LEN=$(count_chars "$TEXT")
BEST_TEXT="$TEXT"

if [ "$BEST_LEN" -lt 4 ] || [ "$USER_PSM" -ne 6 ]; then
    TEXT2=$(run_ocr "$TMP_NOISE" 6)
    LEN2=$(count_chars "$TEXT2")
    [ "$LEN2" -gt "$BEST_LEN" ] && { BEST_LEN=$LEN2; BEST_TEXT="$TEXT2"; }
fi
if [ "$BEST_LEN" -lt 4 ]; then
    TEXT3=$(run_ocr "$TMP_NOISE" 4)
    LEN3=$(count_chars "$TEXT3")
    [ "$LEN3" -gt "$BEST_LEN" ] && { BEST_LEN=$LEN3; BEST_TEXT="$TEXT3"; }
fi
if [ "$BEST_LEN" -lt 4 ]; then
    TEXT4=$(magick "$TMP" -threshold 85% stdout 2>/dev/null \
        | tesseract - stdout -l "$LANG" --psm 11 --oem 1 2>/dev/null)
    LEN4=$(count_chars "$TEXT4")
    [ "$LEN4" -gt "$BEST_LEN" ] && BEST_TEXT="$TEXT4"
fi

# Exit 0 with empty stdout = no text found (QML handles this case)
printf '%s' "$BEST_TEXT"
