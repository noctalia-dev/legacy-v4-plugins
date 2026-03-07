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
SOUND_FLAG=0
NOTIFY_FLAG=0
CUSTOM_DIR=""

send_notify() {
    # Notifications are optional and only sent when --notify is provided.
    if [[ "$NOTIFY_FLAG" -eq 1 ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send "$1" "$2" -a 'Recorder' & disown
    fi
}

for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            send_notify "Recording cancelled" "No region specified for --region"
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--dir" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            CUSTOM_DIR="${ARGS[i+1]}"
        else
            send_notify "Recording cancelled" "No folder specified for --dir"
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    elif [[ "${ARGS[i]}" == "--notify" ]]; then
        # Keep notifications opt-in to avoid overlay/pop-up interference while recording.
        NOTIFY_FLAG=1
    fi
done

if [[ -n "$CUSTOM_DIR" ]]; then
    RECORDING_DIR="$CUSTOM_DIR"
fi

RECORDING_DIR="${RECORDING_DIR/#\~/$HOME}"

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

if pgrep wf-recorder > /dev/null; then
    send_notify "Recording Stopped" "Stopped"
    pkill wf-recorder &
else
    if [[ -z "$MANUAL_REGION" ]]; then
        send_notify "Recording cancelled" "No region specified. Use --region <geometry>"
        exit 1
    fi

    send_notify "Starting recording" 'recording_'"$(getdate)"'.mp4'
    if [[ $SOUND_FLAG -eq 1 ]]; then
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$MANUAL_REGION" --audio="$(getaudiooutput)"
    else
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$MANUAL_REGION"
    fi
fi