#!/usr/bin/env bash
# media-utils.sh — filename sanitization, URL parsing, local file metadata

sanitize_filename() {
  local value="${1-}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//\//-}"
  value="$(printf '%s' "$value" | sed 's/[<>:\"\\|?*]/-/g; s/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  printf '%s' "${value:-track}"
}

strip_known_media_id_suffix() {
  local value="${1-}"
  local stripped
  stripped="$(printf '%s' "$value" | sed -E 's/ \[(yt-)?[A-Za-z0-9_-]{6,}\]$//')"
  printf '%s' "${stripped:-$value}"
}

extract_youtube_video_id() {
  local url="${1-}"
  local short_regex='youtu\.be/([A-Za-z0-9_-]{6,})'
  local watch_regex='[?&]v=([A-Za-z0-9_-]{6,})'
  local path_regex='youtube\.com/(shorts|embed|live)/([A-Za-z0-9_-]{6,})'

  if [[ "$url" =~ $short_regex ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$url" =~ $watch_regex ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$url" =~ $path_regex ]]; then
    printf '%s\n' "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

find_downloaded_youtube_file() {
  local video_id="${1-}"
  local filepath=""
  local target_dir
  target_dir="$(downloads_dir)"

  if [[ -z "$video_id" || ! -d "$target_dir" ]]; then
    return 1
  fi

  while IFS= read -r -d '' filepath; do
    printf '%s\n' "$filepath"
    return 0
  done < <(
    find "$target_dir" -maxdepth 1 -type f \
      \( \
        -iname "*\[yt-${video_id}\].mp3" -o \
        -iname "*\[yt-${video_id}\].m4a" -o \
        -iname "*\[yt-${video_id}\].opus" -o \
        -iname "*\[yt-${video_id}\].ogg" -o \
        -iname "*\[yt-${video_id}\].webm" -o \
        -iname "*\[${video_id}\].mp3" -o \
        -iname "*\[${video_id}\].m4a" -o \
        -iname "*\[${video_id}\].opus" -o \
        -iname "*\[${video_id}\].ogg" -o \
        -iname "*\[${video_id}\].webm" \
      \) \
      -print0 2>/dev/null
  )

  return 1
}

infer_provider_for_url() {
  local url="${1-}"
  if [[ -f "$url" ]]; then
    printf 'local\n'
  elif [[ "$url" =~ soundcloud\.com ]]; then
    printf 'soundcloud\n'
  elif [[ "$url" =~ youtube\.com|youtu\.be ]]; then
    printf 'youtube\n'
  else
    printf 'custom\n'
  fi
}

local_file_metadata_json() {
  local filepath="${1-}"
  require_cmd jq

  if [[ -z "$filepath" || ! -f "$filepath" ]]; then
    printf '{}\n'
    return 0
  fi

  local filename base_name display_name guessed_title guessed_artist album duration probe_json
  filename="$(basename "$filepath")"
  base_name="${filename%.*}"
  display_name="$(strip_known_media_id_suffix "$base_name")"
  guessed_title="$display_name"
  guessed_artist="Local file"
  album=""
  duration="0"

  if [[ "$display_name" == *" - "* ]]; then
    guessed_artist="${display_name%% - *}"
    guessed_title="${display_name#* - }"
  elif [[ "$display_name" == *" — "* ]]; then
    guessed_artist="${display_name%% — *}"
    guessed_title="${display_name#* — }"
  elif [[ "$display_name" == *" – "* ]]; then
    guessed_artist="${display_name%% – *}"
    guessed_title="${display_name#* – }"
  fi

  if command -v ffprobe >/dev/null 2>&1; then
    probe_json="$(ffprobe -v quiet -print_format json \
      -show_entries format=duration:format_tags=title,artist,album,album_artist \
      "$filepath" 2>/dev/null || true)"

    if [[ -n "$probe_json" ]]; then
      local probe_title probe_artist probe_album probe_duration
      probe_title="$(printf '%s' "$probe_json" | jq -r '.format.tags.title // empty' 2>/dev/null || true)"
      probe_artist="$(printf '%s' "$probe_json" | jq -r '.format.tags.artist // .format.tags.album_artist // empty' 2>/dev/null || true)"
      probe_album="$(printf '%s' "$probe_json" | jq -r '.format.tags.album // empty' 2>/dev/null || true)"
      probe_duration="$(printf '%s' "$probe_json" | jq -r '(.format.duration // 0 | tonumber? // 0 | floor)' 2>/dev/null || true)"

      if [[ -n "$probe_title" ]]; then
        guessed_title="$probe_title"
      fi
      if [[ -n "$probe_artist" ]]; then
        guessed_artist="$probe_artist"
      fi
      if [[ -n "$probe_album" ]]; then
        album="$probe_album"
      fi
      if [[ -n "$probe_duration" && "$probe_duration" != "null" ]]; then
        duration="$probe_duration"
      fi
    fi
  fi

  jq -nc \
    --arg id "local-$(printf '%s' "$filepath" | sha256sum | cut -c1-16)" \
    --arg title "${guessed_title:-$display_name}" \
    --arg url "$filepath" \
    --arg uploader "${guessed_artist:-Local file}" \
    --arg album "$album" \
    --arg localPath "$filepath" \
    --arg provider "local" \
    --argjson duration "${duration:-0}" \
    '{
      id: $id,
      title: $title,
      url: $url,
      uploader: $uploader,
      duration: $duration,
      album: $album,
      localPath: $localPath,
      provider: $provider
    }'
}

local_audio_candidates() {
  local query="${1-}"
  if command -v rg >/dev/null 2>&1; then
    local -a rg_args
    rg_args=(
      rg --files "$LOCAL_MUSIC_DIR"
      -g '*.mp3'
      -g '*.flac'
      -g '*.ogg'
      -g '*.opus'
      -g '*.m4a'
      -g '*.wav'
      -g '*.wma'
      -g '*.aac'
    )

    if [[ -n "$query" ]]; then
      "${rg_args[@]}" 2>/dev/null | rg -i -F -- "$query" 2>/dev/null || true
    else
      "${rg_args[@]}" 2>/dev/null || true
    fi
  else
    find "$LOCAL_MUSIC_DIR" -maxdepth 4 -type f \
      \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.wma' -o -iname '*.aac' \) \
      -print 2>/dev/null || true
  fi
}

folder_audio_candidates() {
  local folder="${1-}"
  if [[ -z "$folder" || ! -d "$folder" ]]; then
    return 0
  fi

  if command -v rg >/dev/null 2>&1; then
    rg --files "$folder" \
      -g '*.mp3' \
      -g '*.flac' \
      -g '*.ogg' \
      -g '*.opus' \
      -g '*.m4a' \
      -g '*.wav' \
      -g '*.wma' \
      -g '*.aac' 2>/dev/null || true
  else
    find "$folder" -type f \
      \( -iname '*.mp3' -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.wma' -o -iname '*.aac' \) \
      -print 2>/dev/null || true
  fi
}
