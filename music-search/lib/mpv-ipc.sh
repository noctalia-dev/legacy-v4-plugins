#!/usr/bin/env bash
# mpv-ipc.sh — mpv IPC communication and status

_current_status_commit_unlocked() {
  local pid="${1-}"
  local is_running="${2-false}"
  local pause_state="${3-false}"
  local speed_state="${4-1}"
  safe_read_json "$STATE_FILE"

  local previous_playing
  local previous_end_reason
  local next_end_reason

  previous_playing="$(state_field '.isPlaying')"
  previous_end_reason="$(state_field '.endReason // ""')"

  if [[ "$is_running" == "true" ]]; then
    _write_state_unlocked \
      true \
      "$(state_field '.id')" \
      "$(state_field '.title')" \
      "$(state_field '.url')" \
      "$(state_field '.uploader')" \
      "$(state_field '.duration')" \
      "$speed_state" \
      "$pid" \
      "" \
      "" \
      "$pause_state"
  else
    rm -f "$PID_FILE"
    cleanup_runtime_cache
    next_end_reason="$previous_end_reason"
    if [[ "$previous_playing" == "true" ]]; then
      if [[ "$previous_end_reason" == "stopped" ]]; then
        next_end_reason="stopped"
      else
        next_end_reason="finished"
      fi
    fi
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
      "$next_end_reason" \
      "false"
  fi

  _emit_state_unlocked
}

current_status() {
  local pid=""
  local pause_state="false"
  local speed_state="1"
  local is_running="false"

  pid="$(read_pid)"
  if is_running_pid "$pid"; then
    is_running="true"

    local pause_response=""
    pause_response="$(mpv_ipc_send '{"command":["get_property","pause"]}' 2>/dev/null || true)"
    if [[ -n "$pause_response" ]]; then
      local pause_val
      pause_val="$(printf '%s' "$pause_response" | jq -r '.data // false' 2>/dev/null || true)"
      if [[ "$pause_val" == "true" ]]; then
        pause_state="true"
      fi
    fi

    local speed_response=""
    speed_response="$(mpv_ipc_send '{"command":["get_property","speed"]}' 2>/dev/null || true)"
    if [[ -n "$speed_response" ]]; then
      local speed_val
      speed_val="$(printf '%s' "$speed_response" | jq -r '.data // 1' 2>/dev/null || true)"
      if [[ -n "$speed_val" && "$speed_val" != "null" ]]; then
        speed_state="$speed_val"
      fi
    fi
  fi

  _current_status_commit_unlocked "$pid" "$is_running" "$pause_state" "$speed_state"
}

mpv_ipc_send() {
  local payload="$1"
  [[ -S "$SOCKET_FILE" ]] || return 1
  if command -v socat >/dev/null 2>&1; then
    printf '%s\n' "$payload" | socat -t 1 - UNIX-CONNECT:"$SOCKET_FILE" 2>/dev/null | head -1 || true
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$SOCKET_FILE" "$payload" 2>/dev/null <<'PYEOF'
import sys, socket as sock
path, msg = sys.argv[1], sys.argv[2]
s = sock.socket(sock.AF_UNIX, sock.SOCK_STREAM)
s.settimeout(1)
try:
    s.connect(path); s.sendall((msg+'\n').encode())
    print(s.recv(4096).decode().strip().split('\n')[0])
except Exception: pass
finally: s.close()
PYEOF
  else
    return 1
  fi
}

mpv_ipc_command() {
  local payload="$1"
  local action_label="$2"
  require_cmd jq

  local response=""
  response="$(mpv_ipc_send "$payload" 2>/dev/null || true)"
  if [[ -z "$response" ]]; then
    write_current_state_error_and_emit "Could not ${action_label} playback: mpv IPC is unavailable."
    return 1
  fi

  local ipc_error=""
  ipc_error="$(printf '%s' "$response" | jq -r '.error // "success"' 2>/dev/null || true)"
  if [[ "$ipc_error" != "success" ]]; then
    write_current_state_error_and_emit "Could not ${action_label} playback: ${ipc_error}."
    return 1
  fi

  return 0
}
