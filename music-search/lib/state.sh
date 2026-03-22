#!/usr/bin/env bash
# state.sh — state file read/write

_write_state_unlocked() {
  local is_playing="$1"
  local entry_id="$2"
  local title="$3"
  local url="$4"
  local uploader="$5"
  local duration="$6"
  local speed="${7-1}"
  local pid="$8"
  local error="${9-}"
  local end_reason="${10-}"
  local is_paused="${11:-false}"
  local updated_at
  updated_at="$(date +%s%3N)"

  jq -nc \
    --argjson isPlaying "$is_playing" \
    --argjson isPaused "$is_paused" \
    --arg id "$entry_id" \
    --arg title "$title" \
    --arg url "$url" \
    --arg uploader "$uploader" \
    --argjson duration "${duration:-0}" \
    --argjson speed "${speed:-1}" \
    --argjson pid "${pid:-0}" \
    --arg error "$error" \
    --arg endReason "$end_reason" \
    --arg updatedAt "$updated_at" \
    '{isPlaying:$isPlaying,isPaused:$isPaused,id:$id,title:$title,url:$url,uploader:$uploader,duration:$duration,speed:$speed,pid:$pid,error:$error,endReason:$endReason,updatedAt:$updatedAt}' \
    | json_write_raw "$STATE_FILE"
}

write_state() {
  _write_state_unlocked "$@"
}

_emit_state_unlocked() {
  safe_read_json "$STATE_FILE"
  cat "$STATE_FILE"
}

emit_state() {
  _emit_state_unlocked
}

state_field() {
  local field="$1"
  jq -r "$field" "$STATE_FILE"
}

_write_current_state_error_unlocked() {
  local error_message="$1"
  safe_read_json "$STATE_FILE"
  _write_state_unlocked \
    "$(state_field '.isPlaying')" \
    "$(state_field '.id')" \
    "$(state_field '.title')" \
    "$(state_field '.url')" \
    "$(state_field '.uploader')" \
    "$(state_field '.duration')" \
    "$(state_field '.speed // 1')" \
    "$(state_field '.pid')" \
    "$error_message" \
    "$(state_field '.endReason // ""')" \
    "$(state_field '.isPaused // false')"
}

_write_current_state_error_and_emit_unlocked() {
  _write_current_state_error_unlocked "$1"
  _emit_state_unlocked
}

write_current_state_error() {
  _write_current_state_error_unlocked "$@"
}

write_current_state_error_and_emit() {
  _write_current_state_error_and_emit_unlocked "$@"
}
