# music-search Plugin

Search YouTube, SoundCloud, or local files, play audio in the background with `mpv`, and manage a saved library with playlists, tags, ratings, preview metadata, and a built-in queue.

## Requirements

- `mpv` for playback
- `yt-dlp` for YouTube and SoundCloud search/details/downloads
- `jq` for local persistence helpers
- `ffprobe` is optional but improves local metadata detection

## Launcher usage

- `>music-search` opens the home view with status, library shortcuts, recent plays, top tracks, tags, artists, and playlists
- `>music-search <query>` searches the active provider
- `>music-search yt:<query>`, `sc:<query>`, `local:<query>` force a provider
- `>music-search <url>` plays a direct URL immediately
- `>music-search saved:` browses the saved library
- `>music-search queue` opens the built-in queue browser and controls
- `>music-search playlist:<name>` browses, creates, renames, and launches playlists
- `>music-search artist:<name>` browses saved tracks by uploader
- `>music-search #tag` or `>music-search tag:` filters or edits tags
- `>music-search edit:` updates title, artist, or album metadata for saved entries
- `>music-search speed:1.05` adjusts playback speed
- `>music-search stop` stops background playback

Search results and saved tracks expose inline actions for queueing, saving, downloading, metadata edits, tags, and playlists. Queue controls are now part of the music-search plugin, so the old standalone `queue` plugin should be treated as legacy.

The internal plugin ID remains `music` for IPC compatibility.

## IPC usage

```bash
qs -c noctalia-shell ipc call plugin:music launcher
qs -c noctalia-shell ipc call plugin:music play "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
qs -c noctalia-shell ipc call plugin:music save "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
qs -c noctalia-shell ipc call plugin:music seek 90
qs -c noctalia-shell ipc call plugin:music stop
```

## Data files

- By default, runtime data lives under `~/.cache/noctalia/plugins/music-search/`
- `~/.cache/noctalia/plugins/music-search/library.json` stores saved tracks and playback stats
- `~/.cache/noctalia/plugins/music-search/playlists.json` stores playlists
- `~/.cache/noctalia/plugins/music-search/queue.json` stores the built-in persistent queue
- `~/.cache/noctalia/plugins/music-search/state.json` stores current playback state
- `~/.cache/noctalia/plugins/music-search/settings.json` stores local user state
- Set `MUSIC_CACHE_DIR` to override the default cache directory
