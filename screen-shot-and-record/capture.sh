#!/usr/bin/env bash

NOTIFY_FLAG=1
NOTIFY_APP="Screenshot"
COPIED_TITLE="Copied"
COPIED_BODY="Image copied to clipboard"
SAVED_TITLE="Saved"
OCR_DONE_TITLE="OCR complete"
OCR_COPIED_BODY="Recognized text copied to clipboard"
OCR_EMPTY_BODY="No text detected"
DEP_MISSING="A required dependency is not installed."
OCR_FAILED="OCR failed"

ACTION=""
GEOMETRY=""
CROP_GEOMETRY=""
MODE="copy"
EDITOR=""
OUTPUT_FILE=""
SOURCE_FILE=""
KEEP_SOURCE=false
FROZEN_SOURCE=""
PNG_COMPRESSION_LEVEL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --action) ACTION="$2"; shift 2 ;;
        --geometry) GEOMETRY="$2"; shift 2 ;;
        --crop-geometry) CROP_GEOMETRY="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --editor) EDITOR="$2"; shift 2 ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --source) SOURCE_FILE="$2"; shift 2 ;;
        --frozen-source) FROZEN_SOURCE="$2"; shift 2 ;;
        --keep-source) KEEP_SOURCE=true; shift ;;
        --no-notify) NOTIFY_FLAG=0; shift ;;
        --notify-app) NOTIFY_APP="$2"; shift 2 ;;
        --copied-title) COPIED_TITLE="$2"; shift 2 ;;
        --copied-body) COPIED_BODY="$2"; shift 2 ;;
        --saved-title) SAVED_TITLE="$2"; shift 2 ;;
        --ocr-done-title) OCR_DONE_TITLE="$2"; shift 2 ;;
        --ocr-copied-body) OCR_COPIED_BODY="$2"; shift 2 ;;
        --ocr-empty-body) OCR_EMPTY_BODY="$2"; shift 2 ;;
        --dep-missing) DEP_MISSING="$2"; shift 2 ;;
        --ocr-failed) OCR_FAILED="$2"; shift 2 ;;
        --png-compression-level) PNG_COMPRESSION_LEVEL="$2"; shift 2 ;;
        *) exit 1 ;;
    esac
done

success_notify() {
    if [[ "$NOTIFY_FLAG" -eq 1 ]] && command -v notify-send &>/dev/null; then
        notify-send -a "$NOTIFY_APP" "$1" "$2" & disown
    fi
}

require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        if command -v notify-send &>/dev/null; then
            notify-send -a "$NOTIFY_APP" "$OCR_FAILED" "$DEP_MISSING"
        fi
        exit 1
    fi
}

crop_or_grim() {
    local out="$1" stream="$2"

    local compress_args=()
    if [[ -n "$PNG_COMPRESSION_LEVEL" ]]; then
        compress_args=(-define "png:compression-level=$PNG_COMPRESSION_LEVEL")
    fi

    if [[ -n "$FROZEN_SOURCE" && -f "$FROZEN_SOURCE" ]]; then
        if command -v magick &>/dev/null; then
            if [[ "$stream" == "yes" ]]; then magick "$FROZEN_SOURCE" -crop "$CROP_GEOMETRY" +repage "${compress_args[@]}" png:-
            else magick "$FROZEN_SOURCE" -crop "$CROP_GEOMETRY" +repage "${compress_args[@]}" "$out"; fi
        elif command -v convert &>/dev/null; then
            if [[ "$stream" == "yes" ]]; then convert "$FROZEN_SOURCE" -crop "$CROP_GEOMETRY" +repage "${compress_args[@]}" png:-
            else convert "$FROZEN_SOURCE" -crop "$CROP_GEOMETRY" +repage "${compress_args[@]}" "$out"; fi
        else
            if [[ "$stream" == "yes" ]]; then grim -g "$GEOMETRY" -
            else grim -g "$GEOMETRY" "$out"; fi
        fi
        rm -f "$FROZEN_SOURCE"
    else
        if [[ "$stream" == "yes" ]]; then grim -g "$GEOMETRY" -
        else grim -g "$GEOMETRY" "$out"; fi
    fi
}

case "$ACTION" in
    screenshot)
        require_cmd grim
        require_cmd wl-copy

        if [[ "$MODE" == "copy" ]]; then
            crop_or_grim "" "yes" | wl-copy --type image/png
            success_notify "$COPIED_TITLE" "$COPIED_BODY"
        elif [[ "$MODE" == "edit" ]]; then
            mkdir -p "$(dirname "$SOURCE_FILE")"
            crop_or_grim "$SOURCE_FILE" ""

            if [[ "$EDITOR" == "satty" ]]; then
                satty --filename "$SOURCE_FILE" --output-filename "$OUTPUT_FILE"
            else
                "$EDITOR" -f "$SOURCE_FILE" -o "$OUTPUT_FILE"
            fi

            if [[ "$KEEP_SOURCE" != "true" ]]; then
                rm -f "$SOURCE_FILE"
            fi
            success_notify "$SAVED_TITLE" "$OUTPUT_FILE"
        fi
        ;;

    ocr)
        require_cmd grim
        require_cmd tesseract
        require_cmd wl-copy

        tmp="/tmp/screen-ocr-$$.png"
        crop_or_grim "$tmp" ""
        text=""
        if [[ -s "$tmp" ]]; then
            text=$(tesseract "$tmp" stdout 2>/dev/null) || true
        fi
        rm -f "$tmp"

        if [[ -n "$text" ]]; then
            printf "%s" "$text" | wl-copy
            success_notify "$OCR_DONE_TITLE" "$OCR_COPIED_BODY"
        else
            success_notify "$OCR_DONE_TITLE" "$OCR_EMPTY_BODY"
        fi
        ;;

    search)
        require_cmd grim

        tmp="/tmp/screen-search-$$.png"
        crop_or_grim "$tmp" ""

        if [[ -s "$tmp" ]]; then
            url=$(curl -sF "files[]=@$tmp" https://uguu.se/upload | jq -r '.files[0].url') || true
            if [[ -n "$url" ]]; then
                xdg-open "https://lens.google.com/uploadbyurl?url=$url"
            fi
        fi
        rm -f "$tmp"
        ;;
esac
