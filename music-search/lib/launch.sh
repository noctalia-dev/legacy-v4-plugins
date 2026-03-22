#!/usr/bin/env bash
# launch.sh — mpv launch helpers

launch_youtube_stream() {
  local source_url="$1"
  local -a mpv_cmd=(
    mpv
    --no-video
    --force-window=no
    --audio-display=no
    --ytdl-format=bestaudio/best
    --demuxer-max-bytes=256K
    --log-file="$LOG_FILE"
    --input-ipc-server="$SOCKET_FILE"
    --title="Noctalia music-search"
  )
  local raw_opt
  raw_opt="$(yt_mpv_raw_option)"
  [[ -n "$raw_opt" ]] && mpv_cmd+=("$raw_opt")
  mpv_cmd+=("$source_url")

  nohup setsid "${mpv_cmd[@]}" >/dev/null 2>&1 &
}

launch_youtube_cached() {
  local source_url="$1"
  local extractor_arg
  extractor_arg="$(yt_extractor_args)"

  nohup setsid bash -lc '
    set -euo pipefail
    shopt -s nullglob
    rm -f "$2".*
    ytdlp_args=(yt-dlp --ignore-config --no-warnings -f bestaudio/best --no-part -o "$2.%(ext)s")
    [[ -n "$5" ]] && ytdlp_args+=("$5")
    "${ytdlp_args[@]}" -- "$1" >>"$4" 2>&1
    files=("$2".*)
    if [[ ${#files[@]} -eq 0 ]]; then
      exit 1
    fi
    exec mpv --no-video --force-window=no --audio-display=no --demuxer-max-bytes=256K --log-file="$4" --input-ipc-server="$3" --title="Noctalia music-search" "${files[0]}"
  ' _ "$source_url" "$DOWNLOAD_BASENAME" "$SOCKET_FILE" "$LOG_FILE" "$extractor_arg" >/dev/null 2>&1 &
}

wait_for_audio_start() {
  local pid="$1"
  local attempts="${2-24}"

  for _ in $(seq 1 "$attempts"); do
    if [[ -f "$LOG_FILE" ]] && grep -q "starting audio playback" "$LOG_FILE" 2>/dev/null; then
      return 0
    fi

    if ! is_running_pid "$pid"; then
      return 1
    fi

    sleep 0.25
  done

  return 2
}
