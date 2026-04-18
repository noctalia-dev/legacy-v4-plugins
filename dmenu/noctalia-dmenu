#!/usr/bin/env bash
#
# noctalia-dmenu — pipe-style dmenu interface for the noctalia dmenu plugin.
#
# Usage:
#   echo -e "opt1\nopt2\nopt3" | noctalia-dmenu [OPTIONS]
#   noctalia-dmenu -f /path/to/items.txt [OPTIONS]
#
# Options:
#   -p,  --prompt TEXT        Prompt text
#   -cb, --callback CMD       Command on selection ({} = result)
#   -c,  --custom             Allow custom text input
#   -s,  --separator SEP      Item separator (default: newline)
#   -t,  --timeout SECS       Wait timeout (default: 30, 0 = infinite)
#   -r,  --result-file PATH   Override result file path
#   -f,  --file PATH          Read items from file
#   -F,  --format FMT         Result format: plain, json, index
#   -no-close                 Keep panel open after selection
#   -h,  --help               Show this help
#
# Exit codes: 0 = selected, 1 = timeout/cancelled, 2 = error
#

set -euo pipefail

PROMPT=""
CALLBACK=""
ALLOW_CUSTOM=false
SEPARATOR=$'\n'
TIMEOUT=30
RESULT_FILE="/tmp/noctalia-dmenu-result"
ITEMS_FILE=""
RESULT_FORMAT="plain"
CLOSE_ON_SELECT=true
QS_CMD="noctalia-shell"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--prompt)      PROMPT="$2"; shift 2 ;;
        -cb|--callback)   CALLBACK="$2"; shift 2 ;;
        -c|--custom)      ALLOW_CUSTOM=true; shift ;;
        -s|--separator)   SEPARATOR="$2"; shift 2 ;;
        -t|--timeout)     TIMEOUT="$2"; shift 2 ;;
        -r|--result-file) RESULT_FILE="$2"; shift 2 ;;
        -f|--file)        ITEMS_FILE="$2"; shift 2 ;;
        -F|--format)      RESULT_FORMAT="$2"; shift 2 ;;
        -no-close)        CLOSE_ON_SELECT=false; shift ;;
        -h|--help)        sed -n '2,/^$/{ s/^# \?//; p }' "$0"; exit 0 ;;
        *)                echo "noctalia-dmenu: unknown option: $1" >&2; exit 2 ;;
    esac
done

rm -f "$RESULT_FILE" "${RESULT_FILE}.tmp"

# Build options JSON
build_options() {
    local opts="{" first=true
    add() { [[ "$first" == true ]] && first=false || opts+=","; opts+="$1"; }
    add "\"resultFile\":\"${RESULT_FILE}\""
    add "\"resultFormat\":\"${RESULT_FORMAT}\""
    [[ -n "$PROMPT" ]]                && add "\"prompt\":\"${PROMPT}\""
    [[ -n "$CALLBACK" ]]              && add "\"callbackCmd\":\"$(printf '%s' "$CALLBACK" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
    [[ "$ALLOW_CUSTOM" == true ]]     && add "\"allowCustomInput\":true"
    [[ "$CLOSE_ON_SELECT" == false ]] && add "\"closeOnSelect\":false"
    opts+="}"; echo "$opts"
}

OPTIONS=$(build_options)

if [[ -n "$ITEMS_FILE" ]]; then
    # File mode — pass through to showFromFile
    # Add separator to options if non-default
    if [[ "$SEPARATOR" != $'\n' ]]; then
        SEP_ESC=$(printf '%s' "$SEPARATOR" | sed 's/\\/\\\\/g; s/"/\\"/g')
        OPTIONS=$(echo "$OPTIONS" | sed "s/^{/{\"separator\":\"${SEP_ESC}\",/")
    fi
    "$QS_CMD" ipc call plugin:dmenu showFromFile "$ITEMS_FILE" "$OPTIONS"
else
    # Stdin mode — read input, use showItems
    if [[ -t 0 ]]; then
        echo "noctalia-dmenu: no input. Pipe items via stdin or use -f." >&2
        exit 2
    fi
    INPUT=$(cat)
    [[ -z "$INPUT" ]] && { echo "noctalia-dmenu: empty input" >&2; exit 2; }

    # Add separator to options
    SEP_ESC=$(printf '%s' "$SEPARATOR" | sed 's/\\/\\\\/g; s/"/\\"/g')
    OPTIONS=$(echo "$OPTIONS" | sed "s/^{/{\"separator\":\"${SEP_ESC}\",/")

    "$QS_CMD" ipc call plugin:dmenu showItems "$INPUT" "$OPTIONS"
fi

# Wait for result
wait_for_result() {
    local timeout="$1" file="$2"
    if command -v inotifywait &>/dev/null; then
        local dir base; dir=$(dirname "$file"); base=$(basename "$file")
        if [[ "$timeout" -gt 0 ]]; then
            inotifywait -qq -t "$timeout" -e moved_to "$dir" --include "^${base}$" 2>/dev/null
        else
            inotifywait -qq -e moved_to "$dir" --include "^${base}$" 2>/dev/null
        fi; return $?
    else
        local elapsed=0 timeout_ms=$((timeout * 1000))
        while true; do
            [[ -f "$file" ]] && return 0
            [[ "$timeout" -gt 0 && "$elapsed" -ge "$timeout_ms" ]] && return 2
            sleep 0.1; elapsed=$((elapsed + 100))
        done
    fi
}

if wait_for_result "$TIMEOUT" "$RESULT_FILE"; then
    if [[ -f "$RESULT_FILE" ]]; then
        cat "$RESULT_FILE"; rm -f "$RESULT_FILE"; exit 0
    fi
fi
rm -f "$RESULT_FILE" "${RESULT_FILE}.tmp"; exit 1
