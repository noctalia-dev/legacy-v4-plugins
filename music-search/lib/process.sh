#!/usr/bin/env bash
# process.sh — process management, hashing, cleanup

library_entry_exists() {
  local entry_id="$1"
  jq -e --arg id "$entry_id" 'any(.[]?; .id == $id)' "$LIBRARY_FILE" >/dev/null
}

playlist_exists() {
  local playlist_id="$1"
  jq -e --arg id "$playlist_id" 'any(.[]?; .id == $id)' "$PLAYLISTS_FILE" >/dev/null
}

playlist_name_exists() {
  local playlist_name="$1"
  local normalized_target="${playlist_name,,}"
  local existing_name=""

  while IFS= read -r existing_name; do
    if [[ "${existing_name,,}" == "$normalized_target" ]]; then
      return 0
    fi
  done < <(jq -r '.[]?.name // empty' "$PLAYLISTS_FILE")

  return 1
}

playlist_contains_entry() {
  local playlist_id="$1"
  local entry_id="$2"
  jq -e \
    --arg pid "$playlist_id" \
    --arg eid "$entry_id" \
    'any(.[]?; .id == $pid and any((.entryIds // [])[]?; . == $eid))' \
    "$PLAYLISTS_FILE" >/dev/null
}

playlist_name_exists_except() {
  local playlist_id="$1"
  local playlist_name="$2"
  local normalized_target="${playlist_name,,}"
  local existing_id=""
  local existing_name=""

  while IFS=$'\t' read -r existing_id existing_name; do
    if [[ "$existing_id" == "$playlist_id" ]]; then
      continue
    fi
    if [[ "${existing_name,,}" == "$normalized_target" ]]; then
      return 0
    fi
  done < <(jq -r '.[]? | [.id // "", .name // ""] | @tsv' "$PLAYLISTS_FILE")

  return 1
}

read_pid() {
  if [[ -f "$PID_FILE" ]]; then
    tr -d '\n' < "$PID_FILE" 2>/dev/null || true
  fi
}

is_running_pid() {
  local pid="${1-}"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

terminate_pid() {
  local pid="${1-}"
  local pgid=""

  if [[ -z "$pid" ]]; then
    return 0
  fi

  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
  if [[ -n "$pgid" && "$pgid" == "$pid" ]]; then
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  else
    kill "$pid" 2>/dev/null || true
  fi
}

force_terminate_pid() {
  local pid="${1-}"
  local pgid=""

  if [[ -z "$pid" ]]; then
    return 0
  fi

  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
  if [[ -n "$pgid" && "$pgid" == "$pid" ]]; then
    kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
  else
    kill -9 "$pid" 2>/dev/null || true
  fi
}

cleanup_runtime_cache() {
  rm -f "${DOWNLOAD_BASENAME}".* "$LOG_FILE" "$SOCKET_FILE"
}

hash_value() {
  local value="$1"
  printf '%s' "$value" | sha256sum | cut -c1-16
}

_stop_existing_unlocked() {
  safe_read_json "$STATE_FILE"

  local pid
  pid="$(read_pid)"

  if is_running_pid "$pid"; then
    terminate_pid "$pid"

    for _ in $(seq 1 20); do
      if ! is_running_pid "$pid"; then
        break
      fi
      sleep 0.1
    done

    if is_running_pid "$pid"; then
      force_terminate_pid "$pid"
    fi
  fi

  rm -f "$PID_FILE"
  cleanup_runtime_cache

  _write_state_unlocked \
    false \
    "$(state_field '.id')" \
    "$(state_field '.title')" \
    "$(state_field '.url')" \
    "$(state_field '.uploader')" \
    "$(state_field '.duration')" \
    1 \
    0 \
    "" \
    "stopped"
}

_stop_existing_and_emit_unlocked() {
  _stop_existing_unlocked "$@"
  _emit_state_unlocked
}

stop_existing() {
  _stop_existing_and_emit_unlocked "$@"
}
