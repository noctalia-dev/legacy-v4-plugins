#!/usr/bin/env bash
# settings.sh — provider, search, tags, ratings, sort

get_provider() {
  with_lock "$SETTINGS_LOCK" _get_provider_unlocked
}

_get_provider_unlocked() {
  safe_read_json "$SETTINGS_FILE"
  if [[ -f "$SETTINGS_FILE" ]]; then
    local provider
    provider="$(jq -r '.activeProvider // "youtube"' "$SETTINGS_FILE" 2>/dev/null || true)"
    printf '%s\n' "${provider:-youtube}"
    return 0
  fi
  printf 'youtube\n'
}

_set_provider_unlocked() {
  local provider="${1-youtube}"
  case "$provider" in
    youtube|soundcloud|local) ;;
    *)
      die "Unknown provider: $provider. Valid: youtube, soundcloud, local"
      ;;
  esac

  safe_read_json "$SETTINGS_FILE"

  if [[ -f "$SETTINGS_FILE" ]]; then
    jq --arg p "$provider" '.activeProvider = $p' "$SETTINGS_FILE" \
      | json_write_raw "$SETTINGS_FILE"
  else
    jq -nc --arg p "$provider" '{activeProvider: $p}' \
      | json_write_raw "$SETTINGS_FILE"
  fi
  cat "$SETTINGS_FILE"
}

set_provider() {
  with_lock "$SETTINGS_LOCK" _set_provider_unlocked "$@"
}

search_youtube() {
  local query="${1-}"
  local -a yt_args=(yt-dlp --ignore-config --flat-playlist --dump-single-json)
  local extractor_arg
  extractor_arg="$(yt_extractor_args)"
  [[ -n "$extractor_arg" ]] && yt_args+=("$extractor_arg")
  yt_args+=("ytsearch15:${query}")
  "${yt_args[@]}" 2>/dev/null \
    | jq -c '[.entries[]? | {
        id: (.id // ""),
        title: (.title // "Untitled"),
        url: ("https://www.youtube.com/watch?v=" + (.id // "")),
        uploader: (.channel // .uploader // ""),
        duration: (.duration // 0)
      } | select(.id != "")]'
}

search_soundcloud() {
  local query="${1-}"
  yt-dlp --ignore-config --flat-playlist --dump-single-json "scsearch15:${query}" 2>/dev/null \
    | jq -c '[.entries[]? | {
        id: (.id // .display_id // ""),
        title: (.title // "Untitled"),
        url: (.url // .webpage_url // ""),
        uploader: (.uploader // .channel // ""),
        duration: (.duration // 0)
      } | select(.url != "")]'
}

search_local() {
  local query="${1-}"
  require_cmd jq

  if [[ ! -d "$LOCAL_MUSIC_DIR" ]]; then
    printf '[]\n'
    return 0
  fi

  local -a result_objects=()
  local match_count=0
  local query_lower
  query_lower="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"

  while IFS= read -r filepath; do
    local filename base_name display_name guessed_title guessed_artist searchable
    filename="$(basename "$filepath")"
    base_name="${filename%.*}"
    display_name="$(strip_known_media_id_suffix "$base_name")"
    guessed_title="$display_name"
    guessed_artist=""

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

    searchable="$(printf '%s %s %s %s' "$filename" "$display_name" "$guessed_artist" "$guessed_title" | tr '[:upper:]' '[:lower:]')"

    if [[ "$searchable" == *"$query_lower"* ]]; then
      result_objects+=("$(jq -nc \
        --arg id "local-$(printf '%s' "$filepath" | sha256sum | cut -c1-16)" \
        --arg title "${guessed_title:-$display_name}" \
        --arg url "$filepath" \
        --arg uploader "${guessed_artist:-Local file}" \
        --arg localPath "$filepath" \
        --arg provider "local" \
        '{
          id: $id,
          title: $title,
          url: $url,
          uploader: $uploader,
          duration: 0,
          localPath: $localPath,
          provider: $provider
        }')")
      ((match_count+=1))
    fi

    if [[ "$match_count" -ge 15 ]]; then
      break
    fi
  done < <(local_audio_candidates "$query")

  if [[ ${#result_objects[@]} -eq 0 ]]; then
    printf '[]\n'
  else
    printf '%s\n' "${result_objects[@]}" | jq -sc '.'
  fi
}

_tag_entry_unlocked() {
  local entry_id="${1-}"
  local tag="${2-}"
  require_cmd jq

  if [[ -z "$entry_id" ]]; then
    die "Missing entry id."
  fi
  if [[ -z "$tag" ]]; then
    die "Missing tag."
  fi

  safe_read_json "$LIBRARY_FILE"

  if ! library_entry_exists "$entry_id"; then
    die "Library entry not found: $entry_id"
  fi

  jq --arg id "$entry_id" --arg tag "$tag" \
    'map(if .id == $id then .tags = ((.tags // []) | if index($tag) then . else . + [$tag] end) else . end)' \
    "$LIBRARY_FILE" | json_write_raw "$LIBRARY_FILE"
  cat "$LIBRARY_FILE"
}

tag_entry() {
  with_lock "$DATA_LOCK" _tag_entry_unlocked "$@"
}

_untag_entry_unlocked() {
  local entry_id="${1-}"
  local tag="${2-}"
  require_cmd jq

  if [[ -z "$entry_id" ]]; then
    die "Missing entry id."
  fi
  if [[ -z "$tag" ]]; then
    die "Missing tag."
  fi

  safe_read_json "$LIBRARY_FILE"

  if ! library_entry_exists "$entry_id"; then
    die "Library entry not found: $entry_id"
  fi

  jq --arg id "$entry_id" --arg tag "$tag" \
    'map(if .id == $id then .tags = ((.tags // []) | map(select(. != $tag))) else . end)' \
    "$LIBRARY_FILE" | json_write_raw "$LIBRARY_FILE"
  cat "$LIBRARY_FILE"
}

untag_entry() {
  with_lock "$DATA_LOCK" _untag_entry_unlocked "$@"
}

_rate_entry_unlocked() {
  local entry_id="${1-}"
  local rating="${2-0}"
  require_cmd jq

  if [[ -z "$entry_id" ]]; then
    die "Missing entry id."
  fi

  safe_read_json "$LIBRARY_FILE"

  if ! library_entry_exists "$entry_id"; then
    die "Library entry not found: $entry_id"
  fi

  if [[ "$rating" -lt 0 ]] 2>/dev/null || [[ "$rating" -gt 5 ]] 2>/dev/null; then
    die "Rating must be 0-5."
  fi

  jq --arg id "$entry_id" --argjson rating "${rating:-0}" \
    'map(if .id == $id then .rating = $rating else . end)' \
    "$LIBRARY_FILE" | json_write_raw "$LIBRARY_FILE"
  cat "$LIBRARY_FILE"
}

rate_entry() {
  with_lock "$DATA_LOCK" _rate_entry_unlocked "$@"
}

_set_sort_unlocked() {
  local sort_by="${1-date}"
  case "$sort_by" in
    date|title|duration|rating) ;;
    *)
      die "Unknown sort: $sort_by. Valid: date, title, duration, rating"
      ;;
  esac

  safe_read_json "$SETTINGS_FILE"

  if [[ -f "$SETTINGS_FILE" ]]; then
    jq --arg s "$sort_by" '.sortBy = $s' "$SETTINGS_FILE" \
      | json_write_raw "$SETTINGS_FILE"
  else
    jq -nc --arg s "$sort_by" '{sortBy: $s}' \
      | json_write_raw "$SETTINGS_FILE"
  fi
  cat "$SETTINGS_FILE"
}

set_sort() {
  with_lock "$SETTINGS_LOCK" _set_sort_unlocked "$@"
}

_set_download_dir_unlocked() {
  local download_dir="${1-}"

  if [[ -z "$download_dir" ]]; then
    die "Missing download directory."
  fi

  mkdir -p "$download_dir" || die "Could not create download directory: $download_dir"
  safe_read_json "$SETTINGS_FILE"

  if [[ -f "$SETTINGS_FILE" ]]; then
    jq --arg path "$download_dir" '.downloadDirectory = $path' "$SETTINGS_FILE" \
      | json_write_raw "$SETTINGS_FILE"
  else
    jq -nc --arg path "$download_dir" '{downloadDirectory: $path}' \
      | json_write_raw "$SETTINGS_FILE"
  fi
  cat "$SETTINGS_FILE"
}

set_download_dir() {
  with_lock "$SETTINGS_LOCK" _set_download_dir_unlocked "$@"
}

_set_cache_size_unlocked() {
  local max_mb="${1-0}"

  if [[ ! "$max_mb" =~ ^[0-9]+$ ]]; then
    die "Cache size must be a non-negative number."
  fi

  safe_read_json "$SETTINGS_FILE"

  if [[ -f "$SETTINGS_FILE" ]]; then
    jq --argjson size "$max_mb" '.downloadCacheMaxMb = $size' "$SETTINGS_FILE" \
      | json_write_raw "$SETTINGS_FILE"
  else
    jq -nc --argjson size "$max_mb" '{downloadCacheMaxMb: $size}' \
      | json_write_raw "$SETTINGS_FILE"
  fi

  prune_download_cache
  cat "$SETTINGS_FILE"
}

set_cache_size() {
  with_lock "$SETTINGS_LOCK" _set_cache_size_unlocked "$@"
}

_set_yt_player_client_unlocked() {
  local client="${1-android}"
  case "$client" in
    android|web|default) ;;
    *)
      die "Unknown YouTube player client: $client. Valid: android, web, default"
      ;;
  esac

  safe_read_json "$SETTINGS_FILE"

  if [[ -f "$SETTINGS_FILE" ]]; then
    jq --arg c "$client" '.ytPlayerClient = $c' "$SETTINGS_FILE" \
      | json_write_raw "$SETTINGS_FILE"
  else
    jq -nc --arg c "$client" '{ytPlayerClient: $c}' \
      | json_write_raw "$SETTINGS_FILE"
  fi
  cat "$SETTINGS_FILE"
}

set_yt_player_client() {
  with_lock "$SETTINGS_LOCK" _set_yt_player_client_unlocked "$@"
}
