# MimeApp GUI

A Noctalia plugin to manage MIME default applications from a panel UI.

## Requirements

- `python3` must be installed and available in `PATH`.

## What it does

- Scans installed `.desktop` files for their `MimeType=` entries.
- Lists MIME types and candidate handlers.
- Updates `~/.config/mimeapps.list` in the `[Default Applications]` section.

## Notes

- This plugin writes user overrides to `~/.config/mimeapps.list`.
- Effective defaults may still be influenced by desktop-specific `*-mimeapps.list` files and system-level files.
- For troubleshooting, run: `XDG_UTILS_DEBUG_LEVEL=2 xdg-mime query default <mime-type>`

## IPC

This plugin exposes an IPC target so the panel can be opened from keybinds, scripts, or a `.desktop` launcher.

```txt
target plugin:mimeapp-gui
	function open(): void
```

Example commands:

```bash
qs -c noctalia-shell ipc call plugin:mimeapp-gui open
```

Example `.desktop` `Exec` line:

```txt
Exec=qs -c noctalia-shell ipc call plugin:mimeapp-gui open
```

## Features

- The "Common" tab visually groups common types (browsers, images, music, video, archives, etc.) and displays typical file extensions beside each group. 
- Changing a default updates only the selected MIME type in `~/.config/mimeapps.list`.
- `ControlCenterWidget` for Control Center shortcuts
