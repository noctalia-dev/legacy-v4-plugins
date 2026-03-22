#!/usr/bin/env bash
# library.sh — library CRUD, playback recording, search dispatch, details, download

_record_library_playback_unlocked() {
  local entry_id="${1-}"
  local title="${2-}"
  local url="${3-}"
  local uploader="${4-}"
  local duration="${5-0}"
  require_cmd jq

  if [[ -z "$entry_id" && -z "$url" ]]; then
    return 0
  fi

  safe_read_json "$LIBRARY_FILE"

  if ! jq -e --arg id "$entry_id" --arg url "$url" \
    'any(.[]?; (($id != "" and .id == $id) or ($url != "" and .url == $url)))' \
    "$LIBRARY_FILE" >/dev/null 2>&1; then
    return 0
  fi

  local played_at provider
  played_at="$(date -Iseconds)"
  provider="$(infer_provider_for_url "$url")"

  jq \
    --arg id "$entry_id" \
    --arg title "$title" \
    --arg url "$url" \
    --arg uploader "$uploader" \
    --argjson duration "${duration:-0}" \
    --arg playedAt "$played_at" \
    --arg provider "$provider" \
    'map(
      if (($id != "" and .id == $id) or ($url != "" and .url == $url)) then
        .title = (if ($title != "") then $title else (.title // "Untitled") end)
        | .url = (if ($url != "") then $url else (.url // "") end)
        | .uploader = (if ($uploader != "") then $uploader else (.uploader // "") end)
        | .duration = (if $duration > 0 then $duration else (.duration // 0) end)
        | .provider = (if (.provider // "") != "" then .provider else $provider end)
        | .playCount = ((.playCount // 0) + 1)
        | .lastPlayedAt = $playedAt
      else
        .
      end
    )' "$LIBRARY_FILE" | json_write_raw "$LIBRARY_FILE"
}

record_library_playback() {
  with_lock "$DATA_LOCK" _record_library_playback_unlocked "$@"
}

_play_track_state_phase() {
  local entry_id="$1"
  local title="$2"
  local url="$3"
  local uploader="$4"
  local duration="$5"

  local playback_source="$url"
  local youtube_video_id=""
  local downloaded_youtube_file=""
  local -a mpv_args
  local pid=""
  local stream_result=1

  if [[ -z "$title" || -z "$url" ]]; then
    _write_state_unlocked false "$entry_id" "$title" "$url" "$uploader" 0 1 0 "Missing playback parameters." "error"
    _emit_state_unlocked
    exit 1
  fi

  require_cmd mpv

  _stop_existing_unlocked >/dev/null 2>&1 || true

  : > "$LOG_FILE"

  if [[ "$url" =~ youtube\.com|youtu\.be ]]; then
    youtube_video_id="$(extract_youtube_video_id "$url" 2>/dev/null || true)"
    downloaded_youtube_file="$(find_downloaded_youtube_file "$youtube_video_id" 2>/dev/null || true)"

    if [[ -n "$downloaded_youtube_file" && -f "$downloaded_youtube_file" ]]; then
      playback_source="$downloaded_youtube_file"
      mpv_args=(
        mpv
        --no-video
        --force-window=no
        --audio-display=no
        --demuxer-max-bytes=256K
        --log-file="$LOG_FILE"
        --input-ipc-server="$SOCKET_FILE"
        --title="Noctalia music-search"
        "$playback_source"
      )

      nohup setsid "${mpv_args[@]}" >/dev/null 2>&1 &
    else
      if ! command -v yt-dlp >/dev/null 2>&1; then
        _write_state_unlocked false "$entry_id" "$title" "$url" "$uploader" "$duration" 1 0 "yt-dlp is required for YouTube playback." "error"
        _emit_state_unlocked
        exit 1
      fi

      launch_youtube_stream "$url"
      pid="$!"
      printf '%s\n' "$pid" > "$PID_FILE"

      if wait_for_audio_start "$pid" 24; then
        _write_state_unlocked true "$entry_id" "$title" "$url" "$uploader" "$duration" 1 "$pid" "" ""
        _emit_state_unlocked
        return 0
      fi

      stream_result=$?

      if is_running_pid "$pid"; then
        terminate_pid "$pid"
        sleep 0.3
        if is_running_pid "$pid"; then
          force_terminate_pid "$pid"
        fi
      fi

      rm -f "$PID_FILE"
      cleanup_runtime_cache
      : > "$LOG_FILE"

      launch_youtube_cached "$url"
    fi
  else
    mpv_args=(
      mpv
      --no-video
      --force-window=no
      --audio-display=no
      --ytdl-format="bestaudio/best"
      --demuxer-max-bytes=256K
      --log-file="$LOG_FILE"
      --input-ipc-server="$SOCKET_FILE"
      --title="Noctalia music-search"
      "$url"
    )

    nohup setsid "${mpv_args[@]}" >/dev/null 2>&1 &
  fi

  pid="$!"
  printf '%s\n' "$pid" > "$PID_FILE"
  sleep 1.5

  if is_running_pid "$pid"; then
    _write_state_unlocked true "$entry_id" "$title" "$url" "$uploader" "$duration" 1 "$pid" "" ""
    _emit_state_unlocked
    return 0
  fi

  local error=""
  if [[ -f "$LOG_FILE" ]]; then
    error="$(tail -n 1 "$LOG_FILE" 2>/dev/null || true)"
  fi

  rm -f "$PID_FILE"
  _write_state_unlocked false "$entry_id" "$title" "$url" "$uploader" "$duration" 1 0 "${error:-$([[ "$stream_result" -eq 2 ]] && printf 'Streaming did not start in time, and cached fallback failed.' || printf 'Track failed to start.')}" "error"
  _emit_state_unlocked
  exit 1
}

play_track() {
  local entry_id="${1-}"
  local title="${2-}"
  local url="${3-}"
  local uploader="${4-}"
  local duration="${5-0}"

  _play_track_state_phase "$entry_id" "$title" "$url" "$uploader" "$duration"

  record_library_playback "$entry_id" "$title" "$url" "$uploader" "$duration" || true
  exit 0
}

search_tracks() {
  local query="${1-}"
  local provider="${2-}"
  require_cmd jq

  if [[ -z "$query" ]]; then
    printf '[]\n'
    exit 0
  fi

  if [[ -z "$provider" ]]; then
    provider="$(get_provider)"
  fi

  case "$provider" in
    youtube)
      require_cmd yt-dlp
      search_youtube "$query"
      ;;
    soundcloud)
      require_cmd yt-dlp
      search_soundcloud "$query"
      ;;
    local)
      search_local "$query"
      ;;
    *)
      require_cmd yt-dlp
      search_youtube "$query"
      ;;
  esac
}

details_for_url() {
  local url="${1-}"
  require_cmd jq

  if [[ -z "$url" ]]; then
    die "Missing URL."
  fi

  if [[ -f "$url" ]]; then
    local local_metadata local_title local_uploader local_album local_duration
    local_metadata="$(local_file_metadata_json "$url")"
    local_title="$(printf '%s' "$local_metadata" | jq -r '.title // "Untitled"' 2>/dev/null || printf '%s' "$(basename "$url")")"
    local_uploader="$(printf '%s' "$local_metadata" | jq -r '.uploader // "Local file"' 2>/dev/null || printf 'Local file')"
    local_album="$(printf '%s' "$local_metadata" | jq -r '.album // ""' 2>/dev/null || true)"
    local_duration="$(printf '%s' "$local_metadata" | jq -r '.duration // 0' 2>/dev/null || printf '0')"

    jq -nc \
      --arg title "$local_title" \
      --arg fileUrl "$url" \
      --arg uploader "$local_uploader" \
      --arg album "$local_album" \
      --arg localPath "$url" \
      --argjson duration "${local_duration:-0}" \
      '{
        title: $title,
        url: $fileUrl,
        uploader: $uploader,
        channel: $uploader,
        album: $album,
        localPath: $localPath,
        duration: $duration,
        uploadDate: "",
        viewCount: 0,
        availability: "local",
        thumbnail: "",
        description: (if $album != "" then ("Local audio file • " + $album) else "Local audio file" end)
      }'
    exit 0
  fi

  require_cmd yt-dlp

  local -a ytdlp_args
  ytdlp_args=(yt-dlp --ignore-config --dump-single-json --no-warnings --playlist-items 1)
  if [[ "$url" =~ youtube\.com|youtu\.be ]]; then
    local extractor_arg
    extractor_arg="$(yt_extractor_args)"
    [[ -n "$extractor_arg" ]] && ytdlp_args+=("$extractor_arg")
  fi

  "${ytdlp_args[@]}" -- "$url" 2>/dev/null \
    | jq -c --arg fallbackUrl "$url" '{
        id: (.id // ""),
        title: (.title // "Untitled"),
        url: (.webpage_url // .url // $fallbackUrl),
        uploader: (.uploader // .channel // ""),
        channel: (.channel // .uploader // ""),
        duration: (.duration // 0),
        uploadDate: (.upload_date // ""),
        viewCount: (.view_count // 0),
        availability: (.availability // ""),
        thumbnail: (.thumbnail // ""),
        description: (.description // "")
      }'
}

download_mp3() {
  local title="${1-}"
  local url="${2-}"
  local target_dir

  if [[ -z "$url" ]]; then
    die "Missing URL."
  fi

  target_dir="$(downloads_dir)"
  mkdir -p "$target_dir"

  if [[ -f "$url" ]]; then
    require_cmd ffmpeg

    local base_name output_path
    base_name="$(sanitize_filename "${title:-$(basename "$url")}")"
    base_name="${base_name%.*}"
    output_path="${target_dir}/${base_name}.mp3"

    ffmpeg -y -i "$url" -vn -codec:a libmp3lame -q:a 2 "$output_path" >/dev/null 2>&1
    prune_download_cache
    printf '%s\n' "$output_path"
    exit 0
  fi

  require_cmd yt-dlp
  require_cmd ffmpeg

  local -a dl_args=(yt-dlp --ignore-config --no-warnings --no-part --no-playlist -x --audio-format mp3 --audio-quality 0)
  if [[ "$url" =~ youtube\.com|youtu\.be ]]; then
    local extractor_arg
    extractor_arg="$(yt_extractor_args)"
    [[ -n "$extractor_arg" ]] && dl_args+=("$extractor_arg")
    dl_args+=(-o "${target_dir}/%(title)s [yt-%(id)s].%(ext)s")
  else
    dl_args+=(-o "${target_dir}/%(title)s [%(id)s].%(ext)s")
  fi
  "${dl_args[@]}" --print after_move:filepath -- "$url"
  prune_download_cache
}

_save_entry_unlocked() {
  local entry_id="${1-}"
  local title="${2-}"
  local url="${3-}"
  local uploader="${4-}"
  local duration="${5-0}"
  local is_saved="${6-true}"
  local provider album local_path metadata

  require_cmd jq

  if [[ -z "$url" ]]; then
    die "Missing URL."
  fi

  if [[ -z "$entry_id" ]]; then
    entry_id="saved-$(hash_value "$url")"
  fi

  if [[ -z "$title" ]]; then
    title="Untitled"
  fi

  provider="$(infer_provider_for_url "$url")"
  album=""
  local_path=""

  if [[ -f "$url" ]]; then
    metadata="$(local_file_metadata_json "$url")"
    title="$(printf '%s' "$metadata" | jq -r --arg fallback "$title" '.title // $fallback' 2>/dev/null || printf '%s' "$title")"
    uploader="$(printf '%s' "$metadata" | jq -r --arg fallback "$uploader" '.uploader // $fallback' 2>/dev/null || printf '%s' "$uploader")"
    duration="$(printf '%s' "$metadata" | jq -r --argjson fallback "${duration:-0}" '.duration // $fallback' 2>/dev/null || printf '%s' "${duration:-0}")"
    album="$(printf '%s' "$metadata" | jq -r '.album // ""' 2>/dev/null || true)"
    local_path="$(printf '%s' "$metadata" | jq -r '.localPath // ""' 2>/dev/null || true)"
    provider="local"
  fi

  safe_read_json "$LIBRARY_FILE"

  jq \
    --arg id "$entry_id" \
    --arg title "$title" \
    --arg url "$url" \
    --arg uploader "$uploader" \
    --argjson duration "${duration:-0}" \
    --argjson isSaved "${is_saved:-true}" \
    --arg savedAt "$(date -Iseconds)" \
    --arg provider "$provider" \
    --arg album "$album" \
    --arg localPath "$local_path" \
    '(map(select(.id == $id or .url == $url)) | first // null) as $existing |
     map(select(.id != $id and .url != $url)) + [{
      id: $id,
      title: $title,
      url: $url,
      uploader: $uploader,
      duration: $duration,
      savedAt: $savedAt,
      provider: (if $provider != "" then $provider else ($existing.provider // "") end),
      album: (if $album != "" then $album else ($existing.album // "") end),
      localPath: (if $localPath != "" then $localPath else ($existing.localPath // "") end),
      isSaved: (if $isSaved == true then true else ($existing.isSaved // false) end),
      tags: ($existing.tags // []),
      rating: ($existing.rating // 0),
      playCount: ($existing.playCount // 0),
      lastPlayedAt: ($existing.lastPlayedAt // "")
    }]' "$LIBRARY_FILE" | json_write_raw "$LIBRARY_FILE"

  cat "$LIBRARY_FILE"
}

save_entry() {
  with_lock "$DATA_LOCK" _save_entry_unlocked "$@"
}

_edit_metadata_unlocked() {
  local entry_id="${1-}"
  local field="${2-}"
  local value="${3-}"
  require_cmd jq

  if [[ -z "$entry_id" ]]; then
    die "Missing entry id."
  fi

  if [[ -z "$field" ]]; then
    die "Missing metadata field."
  fi

  safe_read_json "$LIBRARY_FILE"

  if ! library_entry_exists "$entry_id"; then
    die "Library entry not found: $entry_id"
  fi

  case "$field" in
    title)
      if [[ -z "$value" ]]; then
        die "Title cannot be empty."
      fi
      jq --arg id "$entry_id" --arg value "$value" \
        'map(if .id == $id then .title = $value else . end)' "$LIBRARY_FILE" \
        | json_write_raw "$LIBRARY_FILE"
      ;;
    artist|uploader)
      jq --arg id "$entry_id" --arg value "$value" \
        'map(if .id == $id then .uploader = $value else . end)' "$LIBRARY_FILE" \
        | json_write_raw "$LIBRARY_FILE"
      ;;
    album)
      jq --arg id "$entry_id" --arg value "$value" \
        'map(if .id == $id then .album = $value else . end)' "$LIBRARY_FILE" \
        | json_write_raw "$LIBRARY_FILE"
      ;;
    *)
      die "Unsupported metadata field: $field"
      ;;
  esac

  cat "$LIBRARY_FILE"
}

edit_metadata() {
  with_lock "$DATA_LOCK" _edit_metadata_unlocked "$@"
}

save_url() {
  local url="${1-}"
  local fallback_id
  require_cmd yt-dlp
  require_cmd jq

  if [[ -z "$url" ]]; then
    die "Missing URL."
  fi

  fallback_id="saved-$(hash_value "$url")"
  local metadata
  local -a ytdlp_args
  ytdlp_args=(yt-dlp --ignore-config --dump-single-json --no-warnings --playlist-items 1)
  if [[ "$url" =~ youtube\.com|youtu\.be ]]; then
    local extractor_arg
    extractor_arg="$(yt_extractor_args)"
    [[ -n "$extractor_arg" ]] && ytdlp_args+=("$extractor_arg")
  fi

  metadata="$("${ytdlp_args[@]}" -- "$url" 2>/dev/null \
    | jq -c --arg fallbackUrl "$url" --arg fallbackId "$fallback_id" '{
        id: (.id // $fallbackId),
        title: (.title // "Saved Track"),
        url: (.webpage_url // .url // $fallbackUrl),
        uploader: (.channel // .uploader // ""),
        duration: (.duration // 0)
      }')"

  if [[ -z "$metadata" ]]; then
    die "Could not resolve metadata for URL."
  fi

  save_entry \
    "$(jq -r '.id' <<< "$metadata")" \
    "$(jq -r '.title' <<< "$metadata")" \
    "$(jq -r '.url' <<< "$metadata")" \
    "$(jq -r '.uploader' <<< "$metadata")" \
    "$(jq -r '.duration' <<< "$metadata")"
}

_remove_entry_unlocked() {
  local entry_id="${1-}"
  require_cmd jq

  if [[ -z "$entry_id" ]]; then
    die "Missing library entry id."
  fi

  safe_read_json "$LIBRARY_FILE"
  safe_read_json "$PLAYLISTS_FILE"

  if ! library_entry_exists "$entry_id"; then
    die "Library entry not found: $entry_id"
  fi

  jq --arg id "$entry_id" 'map(select(.id != $id))' "$LIBRARY_FILE" \
    | json_write_raw "$LIBRARY_FILE"

  jq --arg id "$entry_id" \
    'map(.entryIds = ((.entryIds // []) | map(select(. != $id))))' \
    "$PLAYLISTS_FILE" | json_write_raw "$PLAYLISTS_FILE"

  cat "$LIBRARY_FILE"
}

remove_entry() {
  with_lock "$DATA_LOCK" _remove_entry_unlocked "$@"
}
