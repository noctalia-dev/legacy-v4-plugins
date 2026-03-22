#!/usr/bin/env bash
# config.sh — constants, directory setup, and helpers

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${MUSIC_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/noctalia/plugins/music-search}"
PID_FILE="${CACHE_DIR}/mpv.pid"
STATE_FILE="${CACHE_DIR}/state.json"
LIBRARY_FILE="${CACHE_DIR}/library.json"
LOG_FILE="${CACHE_DIR}/mpv.log"
SOCKET_FILE="${CACHE_DIR}/mpv.sock"
SETTINGS_FILE="${CACHE_DIR}/settings.json"
PLAYLISTS_FILE="${CACHE_DIR}/playlists.json"
QUEUE_FILE="${CACHE_DIR}/queue.json"
DOWNLOAD_BASENAME="${CACHE_DIR}/current-media"
DOWNLOADS_DIR_DEFAULT="${HOME}/Music/Noctalia"
LOCAL_MUSIC_DIR="${HOME}/Music"

STATE_LOCK="${CACHE_DIR}/state.lock"
DATA_LOCK="${CACHE_DIR}/data.lock"
SETTINGS_LOCK="${CACHE_DIR}/settings.lock"
QUEUE_LOCK="${CACHE_DIR}/queue.lock"

mkdir -p "$CACHE_DIR"

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

require_cmd() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "Missing dependency: $name"
}

with_lock() {
  local lock_file="$1"; shift
  local _wl_fd
  exec {_wl_fd}>"$lock_file"
  flock "$_wl_fd"
  local _wl_rc=0
  "$@" || _wl_rc=$?
  exec {_wl_fd}>&-
  return $_wl_rc
}

json_write_raw() {
  local target="$1"
  local tmp_file
  tmp_file="$(mktemp "${target}.tmp.XXXXXX")"
  if ! cat > "$tmp_file"; then
    rm -f "$tmp_file"
    die "json_write_raw: write failed for $target"
  fi
  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    die "json_write_raw: refusing empty write for $target"
  fi
  if ! jq empty "$tmp_file" 2>/dev/null; then
    rm -f "$tmp_file"
    die "json_write_raw: produced invalid JSON for $target"
  fi
  [[ -f "$target" ]] && cp "$target" "${target}.bak"
  mv "$tmp_file" "$target"
}

safe_read_json() {
  local target="$1"
  [[ -f "$target" ]] || return 0
  if jq empty "$target" 2>/dev/null; then return 0; fi

  # Quarantine corrupted file
  local ts
  ts="$(date +%s)"
  mv "$target" "${target}.corrupt.${ts}"

  # Restore from backup if valid
  if [[ -f "${target}.bak" ]] && jq empty "${target}.bak" 2>/dev/null; then
    cp "${target}.bak" "$target"
    return 0
  fi

  # state.json can be reinitialized; user data cannot
  if [[ "$target" == "$STATE_FILE" ]]; then
    _ensure_state_file
    return 0
  fi

  die "Corrupted: ${target}.corrupt.${ts} — no valid backup. Manual recovery required."
}

_ensure_state_file() {
  jq -nc \
    --arg id "" \
    --arg title "" \
    --arg url "" \
    --arg uploader "" \
    --arg error "" \
    --arg endReason "" \
    --arg updatedAt "0" \
    '{isPlaying:false,isPaused:false,id:$id,title:$title,url:$url,uploader:$uploader,duration:0,speed:1,pid:0,error:$error,endReason:$endReason,updatedAt:$updatedAt}' > "$STATE_FILE"
}

yt_player_client() {
  local configured=""
  if [[ -f "$SETTINGS_FILE" ]]; then
    configured="$(jq -r '.ytPlayerClient // empty' "$SETTINGS_FILE" 2>/dev/null || true)"
  fi
  printf '%s\n' "${configured:-android}"
}

yt_extractor_args() {
  local client
  client="$(yt_player_client)"
  if [[ "$client" == "default" || -z "$client" ]]; then
    return 0
  fi
  printf '%s\n' "--extractor-args=youtube:player_client=${client}"
}

yt_mpv_raw_option() {
  local client
  client="$(yt_player_client)"
  if [[ "$client" == "default" || -z "$client" ]]; then
    return 0
  fi
  printf '%s\n' "--ytdl-raw-options=extractor-args=youtube:player_client=${client}"
}

downloads_dir() {
  local configured=""
  if [[ -f "$SETTINGS_FILE" ]]; then
    configured="$(jq -r '.downloadDirectory // empty' "$SETTINGS_FILE" 2>/dev/null || true)"
  fi
  printf '%s\n' "${configured:-$DOWNLOADS_DIR_DEFAULT}"
}

download_cache_max_mb() {
  local configured=""
  if [[ -f "$SETTINGS_FILE" ]]; then
    configured="$(jq -r '.downloadCacheMaxMb // empty' "$SETTINGS_FILE" 2>/dev/null || true)"
  fi
  if [[ "$configured" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$configured"
  else
    printf '0\n'
  fi
}

prune_download_cache() {
  local target_dir max_mb limit_bytes total_bytes oldest_path
  target_dir="$(downloads_dir)"
  max_mb="$(download_cache_max_mb)"

  if [[ ! "$max_mb" =~ ^[0-9]+$ ]] || (( max_mb <= 0 )) || [[ ! -d "$target_dir" ]]; then
    return 0
  fi

  limit_bytes=$((max_mb * 1024 * 1024))
  total_bytes="$(find "$target_dir" -maxdepth 1 -type f -printf '%s\n' 2>/dev/null | awk '{sum+=$1} END {print sum+0}')"

  while [[ "$total_bytes" =~ ^[0-9]+$ ]] && (( total_bytes > limit_bytes )); do
    oldest_path="$(find "$target_dir" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -n 1 | cut -d' ' -f2-)"
    if [[ -z "$oldest_path" ]]; then
      break
    fi
    rm -f -- "$oldest_path" || break
    total_bytes="$(find "$target_dir" -maxdepth 1 -type f -printf '%s\n' 2>/dev/null | awk '{sum+=$1} END {print sum+0}')"
  done
}

ensure_files() {
  [[ -f "$STATE_FILE" ]] || _ensure_state_file
  [[ -f "$LIBRARY_FILE" ]] || printf '[]\n' > "$LIBRARY_FILE"
  [[ -f "$SETTINGS_FILE" ]] || jq -nc \
    --arg provider "youtube" \
    --arg sortBy "date" \
    --arg downloadDirectory "$DOWNLOADS_DIR_DEFAULT" \
    --argjson downloadCacheMaxMb 0 \
    '{activeProvider:$provider,sortBy:$sortBy,downloadDirectory:$downloadDirectory,downloadCacheMaxMb:$downloadCacheMaxMb}' > "$SETTINGS_FILE"
  [[ -f "$PLAYLISTS_FILE" ]] || printf '[]\n' > "$PLAYLISTS_FILE"
  [[ -f "$QUEUE_FILE" ]] || printf '[]\n' > "$QUEUE_FILE"
}
