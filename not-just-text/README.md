# Not Just Text

A Noctalia bar widget that displays a short message — either custom text, a random quote from `fortune`, or a random entry from a text file you provide.

## Features

- **just text** — type anything, it shows up in the bar
- **List mode** — picks a random line from a text file each time the wallpaper changes
- **Fortune mode** — shows a random quote from `fortune -s` instead
- **Wallpaper-triggered refresh** — when list or fortune mode is on, a new entry is picked each time the wallpaper changes (can be disabled to pick once per session)
- **Fortune options** — optionally filter by category (e.g. `computers`), enable offensive quotes (`-o`), or equalise category probability (`-e`)
- Click the widget to open settings directly

## List mode

Picks a random line from a plain text file — one entry per line. You can put anything in it: kaomoji, short phrases, quotes, whatever.

An `examples.txt` is included in the plugin directory as a starting point. Point the setting at any file you like; if no file is configured, `examples.txt` is used automatically.

Lines starting with `# ` (hash + space) and blank lines are ignored, so `#hashtag` style entries work fine.

## Fortune mode

Requires `fortune` to be installed.
Quotes are filtered to single-line entries up to a configurable character limit (default: 60). If no suitable quote is found after 10 attempts, the widget displays `(╯°□°）╯︵ ┻━┻`.

## Settings

| Key | Type | Default | Description |
|---|---|---|---|
| `text` | string | `"Hello"` | Static text shown in the bar (just text mode) |
| `fortuneEnabled` | bool | `false` | Enable fortune mode |
| `fortuneCategory` | string | `""` | Limit fortune to a specific category (e.g. `computers`) |
| `fortuneMaxLength` | int | `60` | Maximum character length a fortune quote may have |
| `fortuneOffensive` | bool | `false` | Also draw from the offensive fortune database (`-o`) |
| `fortuneEqual` | bool | `false` | Give all categories equal probability regardless of size (`-e`) |
| `listEnabled` | bool | `false` | Enable list mode |
| `textFile` | string | `""` | Path to a text file; falls back to bundled `examples.txt` if empty |
| `refreshOnWallpaper` | bool | `true` | Pick a new entry when the wallpaper changes; disable to pick once per session |
