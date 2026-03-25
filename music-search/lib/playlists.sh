#!/usr/bin/env bash
# playlists.sh — playlist CRUD and library listing

_create_playlist_unlocked() {
  local name="${1-}"
  require_cmd jq

  if [[ -z "$name" ]]; then
    die "Missing playlist name."
  fi

  safe_read_json "$PLAYLISTS_FILE"

  if playlist_name_exists "$name"; then
    die "Playlist already exists: $name"
  fi

  local playlist_id
  playlist_id="playlist-$(hash_value "$name-$(date +%s%3N)")"

  jq --arg id "$playlist_id" --arg name "$name" --arg createdAt "$(date -Iseconds)" \
    '. + [{id: $id, name: $name, createdAt: $createdAt, entryIds: []}]' \
    "$PLAYLISTS_FILE" | json_write_raw "$PLAYLISTS_FILE"
  cat "$PLAYLISTS_FILE"
}

create_playlist() {
  with_lock "$DATA_LOCK" _create_playlist_unlocked "$@"
}

_delete_playlist_unlocked() {
  local playlist_id="${1-}"
  require_cmd jq

  if [[ -z "$playlist_id" ]]; then
    die "Missing playlist id."
  fi

  safe_read_json "$PLAYLISTS_FILE"

  if ! playlist_exists "$playlist_id"; then
    die "Playlist not found: $playlist_id"
  fi

  jq --arg id "$playlist_id" 'map(select(.id != $id))' "$PLAYLISTS_FILE" \
    | json_write_raw "$PLAYLISTS_FILE"
  cat "$PLAYLISTS_FILE"
}

delete_playlist() {
  with_lock "$DATA_LOCK" _delete_playlist_unlocked "$@"
}

_rename_playlist_unlocked() {
  local playlist_id="${1-}"
  local name="${2-}"
  require_cmd jq

  if [[ -z "$playlist_id" ]]; then
    die "Missing playlist id."
  fi

  if [[ -z "$name" ]]; then
    die "Missing playlist name."
  fi

  safe_read_json "$PLAYLISTS_FILE"

  if ! playlist_exists "$playlist_id"; then
    die "Playlist not found: $playlist_id"
  fi

  if playlist_name_exists_except "$playlist_id" "$name"; then
    die "Playlist already exists: $name"
  fi

  jq --arg id "$playlist_id" --arg name "$name" \
    'map(if .id == $id then .name = $name else . end)' "$PLAYLISTS_FILE" \
    | json_write_raw "$PLAYLISTS_FILE"
  cat "$PLAYLISTS_FILE"
}

rename_playlist() {
  with_lock "$DATA_LOCK" _rename_playlist_unlocked "$@"
}

_playlist_add_unlocked() {
  local playlist_id="${1-}"
  local entry_id="${2-}"
  require_cmd jq

  if [[ -z "$playlist_id" || -z "$entry_id" ]]; then
    die "Missing playlist or entry id."
  fi

  safe_read_json "$PLAYLISTS_FILE"
  safe_read_json "$LIBRARY_FILE"

  if ! playlist_exists "$playlist_id"; then
    die "Playlist not found: $playlist_id"
  fi

  if ! library_entry_exists "$entry_id"; then
    die "Library entry not found: $entry_id"
  fi

  if playlist_contains_entry "$playlist_id" "$entry_id"; then
    die "Playlist already contains entry: $entry_id in $playlist_id"
  fi

  jq --arg pid "$playlist_id" --arg eid "$entry_id" \
    'map(if .id == $pid then .entryIds = ((.entryIds // []) | if index($eid) then . else . + [$eid] end) else . end)' \
    "$PLAYLISTS_FILE" | json_write_raw "$PLAYLISTS_FILE"
  cat "$PLAYLISTS_FILE"
}

playlist_add() {
  with_lock "$DATA_LOCK" _playlist_add_unlocked "$@"
}

_playlist_remove_unlocked() {
  local playlist_id="${1-}"
  local entry_id="${2-}"
  require_cmd jq

  if [[ -z "$playlist_id" || -z "$entry_id" ]]; then
    die "Missing playlist or entry id."
  fi

  safe_read_json "$PLAYLISTS_FILE"

  if ! playlist_exists "$playlist_id"; then
    die "Playlist not found: $playlist_id"
  fi

  if ! playlist_contains_entry "$playlist_id" "$entry_id"; then
    die "Playlist entry not found: $entry_id in $playlist_id"
  fi

  jq --arg pid "$playlist_id" --arg eid "$entry_id" \
    'map(if .id == $pid then .entryIds = ((.entryIds // []) | map(select(. != $eid))) else . end)' \
    "$PLAYLISTS_FILE" | json_write_raw "$PLAYLISTS_FILE"
  cat "$PLAYLISTS_FILE"
}

playlist_remove() {
  with_lock "$DATA_LOCK" _playlist_remove_unlocked "$@"
}

_playlist_hide_local_from_saved_unlocked() {
  local playlist_id="${1-}"
  local playlist_name=""
  local entry_ids_json="[]"
  local affected_count=0
  require_cmd jq

  if [[ -z "$playlist_id" ]]; then
    die "Missing playlist id."
  fi

  safe_read_json "$PLAYLISTS_FILE"
  safe_read_json "$LIBRARY_FILE"

  if ! playlist_exists "$playlist_id"; then
    die "Playlist not found: $playlist_id"
  fi

  playlist_name="$(jq -r --arg id "$playlist_id" '(map(select(.id == $id)) | first | .name) // ""' "$PLAYLISTS_FILE")"
  entry_ids_json="$(jq -c --arg id "$playlist_id" '(map(select(.id == $id)) | first | .entryIds) // []' "$PLAYLISTS_FILE")"

  affected_count="$(
    jq -r --argjson ids "$entry_ids_json" '
      map(select(
        (.provider // "") == "local"
        and (. as $entry | ($ids | index($entry.id)) != null)
        and (.isSaved != false)
      )) | length
    ' "$LIBRARY_FILE"
  )"

  jq --argjson ids "$entry_ids_json" '
    map(
      if (.provider // "") == "local" and (. as $entry | ($ids | index($entry.id)) != null)
      then . + { isSaved: false }
      else .
      end
    )
  ' "$LIBRARY_FILE" | json_write_raw "$LIBRARY_FILE"

  printf 'Marked %s local tracks in playlist "%s" as playlist-only.\n' "$affected_count" "$playlist_name"
}

playlist_hide_local_from_saved() {
  with_lock "$DATA_LOCK" _playlist_hide_local_from_saved_unlocked "$@"
}

_local_entry_id_for_filepath() {
  local filepath="${1-}"
  local entry_id=""

  if [[ -z "$filepath" ]]; then
    printf '\n'
    return 0
  fi

  entry_id="$(jq -r '.id // ""' <<< "$(local_file_metadata_json "$filepath")" 2>/dev/null || true)"
  if [[ -z "$entry_id" ]]; then
    entry_id="local-$(printf '%s' "$filepath" | sha256sum | cut -c1-16)"
  fi

  printf '%s\n' "$entry_id"
}

_cleanup_orphaned_playlist_only_entries_unlocked() {
  local removed_ids_json="${1-[]}"

  jq --argjson removed "$removed_ids_json" --slurpfile playlists "$PLAYLISTS_FILE" '
    [($playlists[0] // [])[]?.entryIds[]?] as $activeIds
    | map(
        select(
          (. as $entry | ($removed | index($entry.id)) == null)
          or (.isSaved != false)
          or (. as $entry | ($activeIds | index($entry.id)) != null)
        )
      )
  ' "$LIBRARY_FILE" | json_write_raw "$LIBRARY_FILE"
}

_import_folder_playlist_unlocked() {
  local folder_path="${1-}"
  local playlist_name="${2-}"
  local expanded_folder=""
  local -a files=()
  local -a entry_ids=()
  local filepath=""
  local entry_id=""
  local imported_count=0
  local playlist_id=""

  require_cmd jq

  if [[ -z "$folder_path" ]]; then
    die "Missing folder path."
  fi

  expanded_folder="${folder_path/#\~/$HOME}"
  if [[ ! -d "$expanded_folder" ]]; then
    die "Folder not found: $folder_path"
  fi

  if [[ -z "$playlist_name" ]]; then
    playlist_name="$(basename "$expanded_folder")"
  fi

  if [[ -z "$playlist_name" ]]; then
    die "Could not derive playlist name from folder."
  fi

  while IFS= read -r filepath; do
    [[ -n "$filepath" ]] && files+=("$filepath")
  done < <(folder_audio_candidates "$expanded_folder")

  if [[ ${#files[@]} -eq 0 ]]; then
    die "No audio files found in: $folder_path"
  fi

  safe_read_json "$PLAYLISTS_FILE"
  safe_read_json "$LIBRARY_FILE"

  if playlist_name_exists "$playlist_name"; then
    die "Playlist already exists: $playlist_name"
  fi

  playlist_id="playlist-$(hash_value "$playlist_name-$(date +%s%3N)")"

  for filepath in "${files[@]}"; do
    entry_id="$(_local_entry_id_for_filepath "$filepath")"
    _save_entry_unlocked "$entry_id" "" "$filepath" "" 0 false >/dev/null
    entry_ids+=("$entry_id")
    ((imported_count+=1))
  done

  local entry_ids_json
  entry_ids_json="$(printf '%s\n' "${entry_ids[@]}" | jq -R . | jq -sc '.')"

  jq --arg id "$playlist_id" \
    --arg name "$playlist_name" \
    --arg createdAt "$(date -Iseconds)" \
    --arg sourceFolder "$expanded_folder" \
    --argjson entryIds "$entry_ids_json" \
    '. + [{id: $id, name: $name, createdAt: $createdAt, updatedAt: $createdAt, sourceType: "folder", sourceFolder: $sourceFolder, entryIds: $entryIds}]' \
    "$PLAYLISTS_FILE" | json_write_raw "$PLAYLISTS_FILE"

  printf 'Imported %s tracks into playlist \"%s\".\n' "$imported_count" "$playlist_name"
}

import_folder_playlist() {
  with_lock "$DATA_LOCK" _import_folder_playlist_unlocked "$@"
}

_sync_folder_playlist_unlocked() {
  local playlist_id="${1-}"
  local playlist_name=""
  local source_folder=""
  local old_entry_ids_json="[]"
  local new_entry_ids_json="[]"
  local removed_entry_ids_json="[]"
  local -a files=()
  local -a new_entry_ids=()
  local filepath=""
  local entry_id=""
  local synced_count=0
  local added_count=0
  local removed_count=0
  declare -A old_ids_map=()
  declare -A new_ids_map=()
  require_cmd jq

  if [[ -z "$playlist_id" ]]; then
    die "Missing playlist id."
  fi

  safe_read_json "$PLAYLISTS_FILE"
  safe_read_json "$LIBRARY_FILE"

  if ! playlist_exists "$playlist_id"; then
    die "Playlist not found: $playlist_id"
  fi

  playlist_name="$(jq -r --arg id "$playlist_id" '(map(select(.id == $id)) | first | .name) // ""' "$PLAYLISTS_FILE")"
  source_folder="$(jq -r --arg id "$playlist_id" '(map(select(.id == $id)) | first | .sourceFolder) // ""' "$PLAYLISTS_FILE")"
  old_entry_ids_json="$(jq -c --arg id "$playlist_id" '(map(select(.id == $id)) | first | .entryIds) // []' "$PLAYLISTS_FILE")"

  if [[ -z "$source_folder" ]]; then
    die "Playlist is not linked to an imported folder: $playlist_name"
  fi

  if [[ ! -d "$source_folder" ]]; then
    die "Folder no longer exists for playlist \"$playlist_name\": $source_folder"
  fi

  while IFS= read -r filepath; do
    [[ -n "$filepath" ]] && files+=("$filepath")
  done < <(folder_audio_candidates "$source_folder")

  for filepath in "${files[@]}"; do
    entry_id="$(_local_entry_id_for_filepath "$filepath")"
    _save_entry_unlocked "$entry_id" "" "$filepath" "" 0 false >/dev/null
    new_entry_ids+=("$entry_id")
    new_ids_map["$entry_id"]=1
    ((synced_count+=1))
  done

  while IFS= read -r entry_id; do
    [[ -n "$entry_id" ]] && old_ids_map["$entry_id"]=1
  done < <(jq -r '.[]' <<< "$old_entry_ids_json")

  for entry_id in "${new_entry_ids[@]}"; do
    if [[ -z "${old_ids_map[$entry_id]+x}" ]]; then
      ((added_count+=1))
    fi
  done

  while IFS= read -r entry_id; do
    if [[ -n "$entry_id" && -z "${new_ids_map[$entry_id]+x}" ]]; then
      ((removed_count+=1))
    fi
  done < <(jq -r '.[]' <<< "$old_entry_ids_json")

  new_entry_ids_json="$(printf '%s\n' "${new_entry_ids[@]}" | jq -R . | jq -sc '.')"
  removed_entry_ids_json="$(jq -cn --argjson old "$old_entry_ids_json" --argjson current "$new_entry_ids_json" '$old - $current')"

  jq --arg id "$playlist_id" \
    --arg sourceFolder "$source_folder" \
    --arg updatedAt "$(date -Iseconds)" \
    --argjson entryIds "$new_entry_ids_json" \
    'map(
      if .id == $id
      then .entryIds = $entryIds
      | .sourceType = "folder"
      | .sourceFolder = $sourceFolder
      | .updatedAt = $updatedAt
      else .
      end
    )' "$PLAYLISTS_FILE" | json_write_raw "$PLAYLISTS_FILE"

  _cleanup_orphaned_playlist_only_entries_unlocked "$removed_entry_ids_json"

  printf 'Synced playlist \"%s\": %s tracks, %s added, %s removed.\n' \
    "$playlist_name" "$synced_count" "$added_count" "$removed_count"
}

sync_folder_playlist() {
  with_lock "$DATA_LOCK" _sync_folder_playlist_unlocked "$@"
}

list_playlists() {
  with_lock "$DATA_LOCK" _list_playlists_unlocked
}

library_list() {
  with_lock "$DATA_LOCK" _library_list_unlocked
}

_list_playlists_unlocked() {
  safe_read_json "$PLAYLISTS_FILE"
  cat "$PLAYLISTS_FILE"
}

_library_list_unlocked() {
  safe_read_json "$LIBRARY_FILE"
  cat "$LIBRARY_FILE"
}
