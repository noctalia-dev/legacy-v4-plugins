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

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

# parse --region <value> without modifying $@ so other flags like --fullscreen still work
ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    if [[ "${ARGS[i]}" == "--region" ]]; then
        if (( i+1 < ${#ARGS[@]} )); then
            MANUAL_REGION="${ARGS[i+1]}"
        else
            notify-send "Recording cancelled" "No region specified for --region" -a 'Recorder' & disown
            exit 1
        fi
    elif [[ "${ARGS[i]}" == "--sound" ]]; then
        SOUND_FLAG=1
    fi
done

if pgrep wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a 'Recorder' &
    pkill wf-recorder &
else
    if [[ -z "$MANUAL_REGION" ]]; then
        notify-send "Recording cancelled" "No region specified. Use --region <geometry>" -a 'Recorder' & disown
        exit 1
    fi

    notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'Recorder' & disown
    if [[ $SOUND_FLAG -eq 1 ]]; then
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$MANUAL_REGION" --audio="$(getaudiooutput)"
    else
        wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mp4' -t --geometry "$MANUAL_REGION"
    fi
fi