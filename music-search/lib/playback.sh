#!/usr/bin/env bash
# playback.sh — pause, resume, position, seek, speed

pause_playback() {
  local pid
  pid="$(read_pid)"

  if ! is_running_pid "$pid"; then
    emit_state
    return 0
  fi

  if ! mpv_ipc_command '{"command":["set_property","pause",true]}' "pause"; then
    exit 1
  fi

  current_status
}

resume_playback() {
  local pid
  pid="$(read_pid)"

  if ! is_running_pid "$pid"; then
    emit_state
    return 0
  fi

  if ! mpv_ipc_command '{"command":["set_property","pause",false]}' "resume"; then
    exit 1
  fi

  current_status
}

position_query() {
  local response
  response="$(mpv_ipc_send '{"command":["get_property","playback-time"]}' 2>/dev/null || true)"
  if [[ -n "$response" ]]; then
    local pos
    pos="$(printf '%s' "$response" | jq '.data // 0' 2>/dev/null || true)"
    if [[ -n "$pos" && "$pos" != "null" ]]; then
      printf '{"position":%s}\n' "$pos"
      return 0
    fi
  fi
  printf '{"position":0}\n'
}

speed_query() {
  local response
  response="$(mpv_ipc_send '{"command":["get_property","speed"]}' 2>/dev/null || true)"
  if [[ -n "$response" ]]; then
    local speed
    speed="$(printf '%s' "$response" | jq '.data // 1' 2>/dev/null || true)"
    if [[ -n "$speed" && "$speed" != "null" ]]; then
      printf '{"speed":%s}\n' "$speed"
      return 0
    fi
  fi
  printf '{"speed":1}\n'
}

seek_absolute() {
  local target_position="${1-}"
  require_cmd jq

  if [[ -z "$target_position" ]]; then
    die "Missing seek position."
  fi

  local normalized_position
  if ! normalized_position="$(jq -nr --arg value "$target_position" '$value | tonumber | if . < 0 then 0 else . end' 2>/dev/null)"; then
    die "Invalid seek position: $target_position"
  fi

  local pid
  pid="$(read_pid)"

  if ! is_running_pid "$pid"; then
    die "Playback is not running."
  fi

  local payload
  payload="$(jq -cn --argjson pos "$normalized_position" '{"command":["seek", $pos, "absolute+exact"]}')"

  local response=""
  response="$(mpv_ipc_send "$payload" 2>/dev/null || true)"
  if [[ -z "$response" ]]; then
    die "Could not seek playback: mpv IPC is unavailable."
  fi

  local ipc_error=""
  ipc_error="$(printf '%s' "$response" | jq -r '.error // "success"' 2>/dev/null || true)"
  if [[ "$ipc_error" != "success" ]]; then
    die "Could not seek playback: $ipc_error."
  fi

  current_status >/dev/null
  position_query
}

set_speed() {
  local target_speed="${1-}"
  require_cmd jq

  if [[ -z "$target_speed" ]]; then
    die "Missing speed value."
  fi

  local normalized_speed
  if ! normalized_speed="$(jq -nr --arg value "$target_speed" '$value | tonumber | if . < 0.25 then 0.25 elif . > 4 then 4 else . end' 2>/dev/null)"; then
    die "Invalid speed value: $target_speed"
  fi

  local pid
  pid="$(read_pid)"

  if ! is_running_pid "$pid"; then
    die "Playback is not running."
  fi

  local payload
  payload="$(jq -cn --argjson speed "$normalized_speed" '{"command":["set_property", "speed", $speed]}')"

  local response=""
  response="$(mpv_ipc_send "$payload" 2>/dev/null || true)"
  if [[ -z "$response" ]]; then
    die "Could not change speed: mpv IPC is unavailable."
  fi

  local ipc_error=""
  ipc_error="$(printf '%s' "$response" | jq -r '.error // "success"' 2>/dev/null || true)"
  if [[ "$ipc_error" != "success" ]]; then
    die "Could not change speed: $ipc_error."
  fi

  current_status
}
