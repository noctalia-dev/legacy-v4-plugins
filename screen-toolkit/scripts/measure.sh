#!/usr/bin/env bash
# measure.sh — capture a measurement overlay
# Args: sx sy rx ry rw rh lx1 ly1 lx2 ly2 lw lh color scale dest_dir full_path
set -euo pipefail
[ $# -lt 16 ] && { echo "Usage: measure.sh sx sy rx ry rw rh lx1 ly1 lx2 ly2 lw lh color scale dest_dir full_path" >&2; exit 1; }
SX=$1;  SY=$2
RX=$3;  RY=$4;  RW=$5;  RH=$6
LX1=$7; LY1=$8; LX2=$9; LY2=${10}
LW=${11}; LH=${12}
COL=${13}; SCALE=${14}
DEST_DIR=${15}; FULL_PATH=${16}
TMP_CROP="/tmp/measure-crop-$$.png"
TMP_OUT="/tmp/measure-out-$$.png"
TMP_VLABEL="/tmp/measure-vlabel-$$.png"
cleanup() { rm -f "$TMP_CROP" "$TMP_OUT" "$TMP_VLABEL"; }
trap cleanup EXIT
# Float-safe scale helpers
iscale() { printf '%.0f' "$(awk "BEGIN { print $1 * $SCALE }")"; }
idiv()   { printf '%.0f' "$(awk "BEGIN { print $1 / $SCALE }")"; }
BX1=$(( LX1 < LX2 ? LX1 : LX2 )); BX2=$(( LX1 > LX2 ? LX1 : LX2 ))
BY1=$(( LY1 < LY2 ? LY1 : LY2 )); BY2=$(( LY1 > LY2 ? LY1 : LY2 ))
MID_X=$(( (BX1 + BX2) / 2 ))
MID_Y=$(( (BY1 + BY2) / 2 ))
R3=$(iscale 3); (( R3 < 1 )) && R3=1
R5=$(iscale 5); (( R5 < 1 )) && R5=1
PS=$(iscale 13); (( PS < 8 )) && PS=8
T20=$(iscale 20)
mkdir -p "$DEST_DIR"
grim -g "$((SX + RX)),$((SY + RY)) ${RW}x${RH}" "$TMP_CROP"
magick "$TMP_CROP" \
    -strokewidth 1 -stroke 'rgba(255,255,255,0.25)' -fill none \
    -draw "rectangle ${BX1},${BY1} ${BX2},${BY2}" \
    -fill 'rgba(255,255,255,0.6)' -stroke none \
    -draw "circle ${LX1},${LY1} $((LX1 + R3)),${LY1}" \
    -draw "circle ${LX2},${LY2} $((LX2 + R3)),${LY2}" \
    -draw "circle ${LX1},${LY2} $((LX1 + R3)),${LY2}" \
    -draw "circle ${LX2},${LY1} $((LX2 + R3)),${LY1}" \
    -strokewidth 2 -stroke "$COL" -fill none \
    -draw "line ${LX1},${LY1} ${LX2},${LY2}" \
    -fill "$COL" -stroke none \
    -draw "circle ${LX1},${LY1} $((LX1 + R5)),${LY1}" \
    -draw "circle ${LX2},${LY2} $((LX2 + R5)),${LY2}" \
    "$TMP_OUT"
if (( LW > T20 )); then
    HTXT="$(idiv $LW)px"
    T6=$(iscale 6)
    GY=$(( BY1 - T20 ))
    (( GY < $(iscale 18) )) && GY=$(( BY2 + T20 ))
    TX=$(( MID_X - ${#HTXT} * T6 / 2 ))
    (( TX < T6 )) && TX=$T6
    TY=$(( GY < BY1 ? GY - T6 : GY + $(iscale 16) ))
    magick "$TMP_OUT" \
        -strokewidth 1 -stroke 'rgba(255,255,255,0.5)' -fill none \
        -draw "line ${BX1},${GY} ${BX2},${GY}" \
        -fill white -stroke none -pointsize "$PS" -font DejaVu-Sans \
        -draw "text ${TX},${TY} \"${HTXT}\"" \
        "$TMP_OUT"
fi
if (( LH > T20 )); then
    VTXT="$(idiv $LH)px"
    VPH=$(iscale 22)
    VPW=$(( ${#VTXT} * $(iscale 9) + $(iscale 16) ))
    if (( LX1 - VPH - $(iscale 14) < $(iscale 4) )); then
        COMP_X=$(( BX2 + $(iscale 10) ))
        (( COMP_X > RW - VPH - 2 )) && COMP_X=$(( RW - VPH - 2 ))
    else
        COMP_X=$(( BX1 - $(iscale 10) - VPH ))
        (( COMP_X < 2 )) && COMP_X=2
    fi
    COMP_Y=$(( MID_Y - VPW / 2 ))
    (( COMP_Y < 2 )) && COMP_Y=2
    (( COMP_Y > RH - VPW - 2 )) && COMP_Y=$(( RH - VPW - 2 ))
    TEXT_X=$(( VPW / 2 - ${#VTXT} * $(iscale 4) ))
    TEXT_Y=$(( VPH - $(iscale 6) ))
    magick -size "${VPW}x${VPH}" xc:'rgba(0,0,0,0)' \
        -fill white -stroke none -pointsize "$PS" -font DejaVu-Sans \
        -draw "text ${TEXT_X},${TEXT_Y} \"${VTXT}\"" \
        -rotate -90 "$TMP_VLABEL"
    magick "$TMP_OUT" "$TMP_VLABEL" \
        -geometry "+${COMP_X}+${COMP_Y}" -composite "$TMP_OUT"
fi
cp "$TMP_OUT" "$FULL_PATH"
wl-copy -t image/png < "$TMP_OUT" || true
echo "$FULL_PATH"
