#!/usr/bin/env bash

# CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
# JSON_PATH=".screenRecord.savePath"

# CUSTOM_PATH=$(jq -r "$JSON_PATH" "$CONFIG_FILE" 2>/dev/null)

CUSTOM_PATH=""

# RECORDING_DIR=""

# if [[ -n "$CUSTOM_PATH" ]]; then
#     RECORDING_DIR="$CUSTOM_PATH"
# else
#     RECORDING_DIR="$HOME/Videos" # Use default path
# fi

RECORDING_DIR="$HOME/Videos"

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
    pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
}

# parse --region <value> without modifying $@ so other flags like --fullscreen still work
ARGS=("$@")
MANUAL_REGION=""
VIDEO_TARGET_SIZE=""
SOUND_FLAG=0
NOTIFY_FLAG=0
CUSTOM_DIR=""
NOTIFY_APP="Recorder"
NOTIFY_CANCELLED_TITLE="Recording cancelled"
NOTIFY_NO_REGION_BODY="No region specified. Use --region <geometry>"
NOTIFY_NO_DIR_BODY="No folder specified for --dir"
NOTIFY_STOPPED_TITLE="Recording Stopped"
NOTIFY_STOPPED_BODY="Stopped"
NOTIFY_STARTING_TITLE="Starting recording"

send_notify() {
    # Notifications are optional and only sent when --notify is provided.
    if [[ "$NOTIFY_FLAG" -eq 1 ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send "$1" "$2" -a "$NOTIFY_APP" & disown
    fi
}

for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            send_notify "$NOTIFY_CANCELLED_TITLE" "$NOTIFY_NO_REGION_BODY"
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--video-target-size" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            VIDEO_TARGET_SIZE="${ARGS[i+1]}"
        fi
    elif [[ "${ARGS[i]}" == "--dir" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            CUSTOM_DIR="${ARGS[i+1]}"
        else
            send_notify "$NOTIFY_CANCELLED_TITLE" "$NOTIFY_NO_DIR_BODY"
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    elif [[ "${ARGS[i]}" == "--notify" ]]; then
        # Keep notifications opt-in to avoid overlay/pop-up interference while recording.
        NOTIFY_FLAG=1
    elif [[ "${ARGS[i]}" == "--notify-app" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            NOTIFY_APP="${ARGS[i+1]}"
        fi
    elif [[ "${ARGS[i]}" == "--notify-cancelled-title" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            NOTIFY_CANCELLED_TITLE="${ARGS[i+1]}"
        fi
    elif [[ "${ARGS[i]}" == "--notify-no-region-body" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            NOTIFY_NO_REGION_BODY="${ARGS[i+1]}"
        fi
    elif [[ "${ARGS[i]}" == "--notify-no-dir-body" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            NOTIFY_NO_DIR_BODY="${ARGS[i+1]}"
        fi
    elif [[ "${ARGS[i]}" == "--notify-stopped-title" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            NOTIFY_STOPPED_TITLE="${ARGS[i+1]}"
        fi
    elif [[ "${ARGS[i]}" == "--notify-stopped-body" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            NOTIFY_STOPPED_BODY="${ARGS[i+1]}"
        fi
    elif [[ "${ARGS[i]}" == "--notify-starting-title" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            NOTIFY_STARTING_TITLE="${ARGS[i+1]}"
        fi
    fi
done

if [[ -n "$CUSTOM_DIR" ]]; then
    RECORDING_DIR="$CUSTOM_DIR"
fi

RECORDING_DIR="${RECORDING_DIR/#\~/$HOME}"

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

if pgrep wf-recorder > /dev/null; then
    send_notify "$NOTIFY_STOPPED_TITLE" "$NOTIFY_STOPPED_BODY"
    pkill wf-recorder &
else
    if [[ -z "$MANUAL_REGION" ]]; then
        send_notify "$NOTIFY_CANCELLED_TITLE" "$NOTIFY_NO_REGION_BODY"
        exit 1
    fi

    send_notify "$NOTIFY_STARTING_TITLE" 'recording_'"$(getdate)"'.mp4'
    FILTER_ARGS=()
    if [[ "$VIDEO_TARGET_SIZE" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        TARGET_W="${BASH_REMATCH[1]}"
        TARGET_H="${BASH_REMATCH[2]}"
        if [[ "$TARGET_W" -gt 0 && "$TARGET_H" -gt 0 ]]; then
            # H264 encoding prefers even dimensions.
            TARGET_W=$(( (TARGET_W / 2) * 2 ))
            TARGET_H=$(( (TARGET_H / 2) * 2 ))
            if [[ "$TARGET_W" -lt 2 ]]; then TARGET_W=2; fi
            if [[ "$TARGET_H" -lt 2 ]]; then TARGET_H=2; fi
            FILTER_ARGS=( -F "scale=${TARGET_W}:${TARGET_H}:flags=lanczos" )
        fi
    fi
    if [[ $SOUND_FLAG -eq 1 ]]; then
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$MANUAL_REGION" "${FILTER_ARGS[@]}" --audio="$(getaudiooutput)"
    else
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$MANUAL_REGION" "${FILTER_ARGS[@]}"
    fi
fi