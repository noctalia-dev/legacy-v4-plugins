#!/usr/bin/env bash
# queue.sh — persistent playback queue storage

_list_queue_unlocked() {
  safe_read_json "$QUEUE_FILE"
  cat "$QUEUE_FILE"
}

list_queue() {
  with_lock "$QUEUE_LOCK" _list_queue_unlocked
}

_queue_enqueue_unlocked() {
  local entry_id="${1-}"
  local title="${2-}"
  local url="${3-}"
  local uploader="${4-}"
  local duration="${5-0}"
  require_cmd jq

  if [[ -z "$url" ]]; then
    die "Missing queue URL."
  fi

  safe_read_json "$QUEUE_FILE"

  if [[ -z "$entry_id" ]]; then
    entry_id="queue-$(hash_value "$url")"
  fi

  if [[ -z "$title" ]]; then
    title="Untitled"
  fi

  jq \
    --arg id "$entry_id" \
    --arg title "$title" \
    --arg url "$url" \
    --arg uploader "$uploader" \
    --argjson duration "${duration:-0}" \
    --arg queuedAt "$(date -Iseconds)" \
    'map(select(.id != $id and .url != $url)) + [{
      id: $id,
      title: $title,
      url: $url,
      uploader: $uploader,
      duration: $duration,
      queuedAt: $queuedAt
    }]' "$QUEUE_FILE" | json_write_raw "$QUEUE_FILE"

  _list_queue_unlocked
}

queue_enqueue() {
  with_lock "$QUEUE_LOCK" _queue_enqueue_unlocked "$@"
}

_queue_remove_unlocked() {
  local entry_id="${1-}"
  require_cmd jq

  if [[ -z "$entry_id" ]]; then
    die "Missing queue entry id."
  fi

  safe_read_json "$QUEUE_FILE"
  jq --arg id "$entry_id" 'map(select(.id != $id))' "$QUEUE_FILE" | json_write_raw "$QUEUE_FILE"
  _list_queue_unlocked
}

queue_remove() {
  with_lock "$QUEUE_LOCK" _queue_remove_unlocked "$@"
}

_queue_clear_unlocked() {
  printf '[]\n' | json_write_raw "$QUEUE_FILE"
  _list_queue_unlocked
}

queue_clear() {
  with_lock "$QUEUE_LOCK" _queue_clear_unlocked
}

_queue_load_library_unlocked() {
  local library_file="${1-}"
  local mode="${2-ordered}"
  require_cmd jq

  if [[ -z "$library_file" ]]; then
    die "Missing library file path."
  fi

  if [[ ! -f "$library_file" ]]; then
    die "music-search library file not found."
  fi

  local lines_file
  lines_file="$(mktemp)"

  jq -c --arg queuedAt "$(date -Iseconds)" '
    if type != "array" then
      empty
    else
      .[]
      | select((.isSaved // true) != false)
      | select((.url // "") != "")
      | {
          id: (.id // .url // ""),
          title: (.title // "Untitled"),
          url: (.url // ""),
          uploader: (.uploader // ""),
          duration: (.duration // 0),
          queuedAt: (.queuedAt // $queuedAt)
        }
    end
  ' "$library_file" > "$lines_file"

  if [[ "$mode" == "shuffle" && -s "$lines_file" ]]; then
    require_cmd shuf
    shuf "$lines_file" | jq -s '.' | json_write_raw "$QUEUE_FILE"
  elif [[ -s "$lines_file" ]]; then
    jq -s '.' "$lines_file" | json_write_raw "$QUEUE_FILE"
  else
    printf '[]\n' | json_write_raw "$QUEUE_FILE"
  fi

  rm -f "$lines_file"
  _list_queue_unlocked
}

queue_load_library() {
  with_lock "$QUEUE_LOCK" _queue_load_library_unlocked "$@"
}

_queue_peek_unlocked() {
  safe_read_json "$QUEUE_FILE"
  jq -c '.[0] // {}' "$QUEUE_FILE"
}

queue_peek() {
  with_lock "$QUEUE_LOCK" _queue_peek_unlocked
}
