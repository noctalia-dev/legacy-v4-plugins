#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/state.sh"
source "${LIB_DIR}/process.sh"
source "${LIB_DIR}/mpv-ipc.sh"
source "${LIB_DIR}/launch.sh"
source "${LIB_DIR}/media-utils.sh"
source "${LIB_DIR}/library.sh"
source "${LIB_DIR}/playback.sh"
source "${LIB_DIR}/settings.sh"
source "${LIB_DIR}/playlists.sh"
source "${LIB_DIR}/queue.sh"

ensure_files

command="${1-status}"
shift || true

case "$command" in
  play)
    play_track "${1-}" "${2-}" "${3-}" "${4-}" "${5-0}"
    ;;
  stop)
    stop_existing
    ;;
  status)
    current_status
    ;;
  search)
    search_tracks "${1-}" "${2-}"
    ;;
  details)
    details_for_url "${1-}"
    ;;
  save)
    save_entry "${1-}" "${2-}" "${3-}" "${4-}" "${5-0}"
    ;;
  edit-metadata)
    edit_metadata "${1-}" "${2-}" "${3-}"
    ;;
  save-url)
    save_url "${1-}"
    ;;
  download-mp3)
    download_mp3 "${1-}" "${2-}"
    ;;
  remove)
    remove_entry "${1-}"
    ;;
  import-folder-playlist)
    import_folder_playlist "${1-}" "${2-}"
    ;;
  sync-folder-playlist)
    sync_folder_playlist "${1-}"
    ;;
  playlist-hide-local-from-saved)
    playlist_hide_local_from_saved "${1-}"
    ;;
  library)
    library_list
    ;;
  pause)
    pause_playback
    ;;
  resume)
    resume_playback
    ;;
  position)
    position_query
    ;;
  get-speed)
    speed_query
    ;;
  seek)
    seek_absolute "${1-}"
    ;;
  speed)
    set_speed "${1-}"
    ;;
  get-provider)
    get_provider
    ;;
  set-provider)
    set_provider "${1-youtube}"
    ;;
  tag)
    tag_entry "${1-}" "${2-}"
    ;;
  untag)
    untag_entry "${1-}" "${2-}"
    ;;
  rate)
    rate_entry "${1-}" "${2-0}"
    ;;
  set-sort)
    set_sort "${1-date}"
    ;;
  set-download-dir)
    set_download_dir "${1-}"
    ;;
  set-cache-size)
    set_cache_size "${1-0}"
    ;;
  set-yt-player-client)
    set_yt_player_client "${1-android}"
    ;;
  create-playlist)
    create_playlist "${1-}"
    ;;
  delete-playlist)
    delete_playlist "${1-}"
    ;;
  rename-playlist)
    rename_playlist "${1-}" "${2-}"
    ;;
  playlist-add)
    playlist_add "${1-}" "${2-}"
    ;;
  playlist-remove)
    playlist_remove "${1-}" "${2-}"
    ;;
  playlists)
    list_playlists
    ;;
  queue-list)
    list_queue
    ;;
  queue-enqueue)
    queue_enqueue "${1-}" "${2-}" "${3-}" "${4-}" "${5-0}"
    ;;
  queue-remove)
    queue_remove "${1-}"
    ;;
  queue-clear)
    queue_clear
    ;;
  queue-load-library)
    queue_load_library "${1-}" "${2-ordered}"
    ;;
  queue-peek)
    queue_peek
    ;;
  *)
    die "Unknown command: $command"
    ;;
esac
