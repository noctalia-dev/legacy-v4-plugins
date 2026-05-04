# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Noctalia Shell plugin (`clamshell`) that manages clamshell mode on laptops. When an external monitor is connected, it inhibits the lid-switch suspend via `systemd-inhibit`; when no external monitor is present, normal systemd behavior is restored. Full specification is in `noctalia-clamshell-spec.md`.

**Target platform:** CachyOS (Arch-based), niri ≥ 0.1.9, Noctalia Shell ≥ 3.6.0, Quickshell (via `noctalia-qs`).

**Install path:** `~/.config/noctalia/plugins/clamshell/`

## Planned File Structure

```
clamshell/
├── manifest.json
├── Main.qml                  # background logic: event-stream, inhibitor Process
├── ControlCenterWidget.qml   # toggle button
├── BarWidget.qml             # status icon
├── Settings.qml              # settings UI
├── preview.png
├── README.md
└── i18n/
    ├── en.json
    └── ru.json
```

## Architecture

### State Model (three sources of truth)

| Property | Type | Source | Description |
|---|---|---|---|
| `enabled` | bool rw | `pluginSettings` | UI toggle — is the plugin active? |
| `externalPresent` | bool ro | niri event-stream | Is at least one external monitor connected? |
| `inhibitorActive` | bool derived | `enabled && externalPresent` | Is the systemd-inhibit process running? |

Any change to `enabled` or `externalPresent` triggers a recalculation and starts/stops the inhibitor process.

### Main.qml is the single source of logic

Widgets get all state via `pluginApi.mainInstance.*`. Widgets must **not** spawn their own `niri msg` processes or duplicate JSON parsing logic.

`Main.qml` must export via `pluginApi.mainInstance`:
- Properties: `enabled` (rw), `externalPresent` (ro), `inhibitorActive` (ro), `outputs` (ro, list)
- Signal: `stateChanged()`
- Methods: `toggle()`, `enable()`, `disable()`, `refresh()`, `status()`

### Event-stream (niri monitor detection)

Use `Quickshell.Io.Process` to run `niri msg --json event-stream`. Read stdout line-by-line — each line is a JSON event. The stream sends full current state upfront, so a separate `niri msg --json outputs` call at startup is **not needed**.

On any output-related event: call `niri msg --json outputs`, filter by `internalConnectorRegex` (default `^(eDP|LVDS|DSI)`), set `externalPresent`. Unknown event types must be silently ignored (niri documents this explicitly).

Reconnect strategy on crash: wait 2 s, retry with exponential backoff up to 30 s. Do **not** kill the inhibitor during stream downtime.

### Inhibitor process lifecycle

Command:
```sh
systemd-inhibit --what=handle-lid-switch --who=<inhibitorWho> \
    --why="Clamshell mode — external display in use" --mode=block \
    sleep infinity
```

Bind `Process.running = inhibitorActive` declaratively. Verify cleanup in `Component.onDestruction`. If `systemd-inhibit` is missing from PATH: log error, show UI error, treat plugin as permanently `enabled=false`.

### IPC target: `plugin:clamshell`

Functions: `enable`, `disable`, `toggle`, `status`, `refresh`.  
`status` returns JSON — see spec §3.5 for schema.

## Key Implementation Rules

- **No polling** — `niri msg outputs` is called reactively from event-stream only, never on a timer.
- **No logind.conf changes** — the plugin must not modify `/etc/systemd/logind.conf`.
- **Single inhibitor process** — at most one `systemd-inhibit` process at any time (`pgrep -f noctalia-clamshell` should return ≤ 1 result).
- **Logging** — use `qs.Commons.Logger`, never `console.log` in production code.
- **No duplicate processes** — test for leaks by connect/disconnect cycling 10× and checking `pgrep`.

## Development & Testing

There is no build step. The plugin is loaded directly by Noctalia Shell from the install path.

**Manual IPC testing:**
```sh
qs -c noctalia-shell ipc call plugin:clamshell status
qs -c noctalia-shell ipc call plugin:clamshell toggle
systemd-inhibit --list   # verify inhibitor presence/absence
```

**Log inspection:**
```sh
journalctl --user -u noctalia* -f
```

**Acceptance scenarios** are fully defined in spec §9. The plugin is done when all 18 criteria pass.

## Key References

- niri IPC events/outputs: https://yalter.github.io/niri/IPC.html and https://docs.rs/niri-ipc/
- Noctalia plugin docs: https://docs.noctalia.dev/development/plugins/overview/
- Hello-world plugin example: https://github.com/noctalia-dev/noctalia-plugins (`hello-world/`)
- `man systemd-inhibit` — especially `--what=handle-lid-switch` and `--mode=block`
