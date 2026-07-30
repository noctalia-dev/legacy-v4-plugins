# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

niri-auto-tile is an auto-tiling daemon for the [niri](https://github.com/YaLTeR/niri) scrollable-tiling Wayland compositor. It listens to niri's JSON event stream and redistributes column widths evenly when windows open or close. It works both as a standalone Python script and as a [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) plugin (v4.4+).

## Running

**Standalone daemon:**
```bash
python3 auto-tile.py --max-visible 4 --debounce 0.3 --debug
```

**As Noctalia plugin:** Install to `~/.config/noctalia/plugins/niri-auto-tile/`, enable in Noctalia Settings. The QML layer (`Main.qml`) manages the daemon process lifecycle automatically.

There is no build step, test suite, or linter configured. The Python script uses only the standard library (no dependencies).

## Architecture

### Two-layer design

1. **Python daemon** (`auto-tile.py`) — the core logic. Runs as a long-lived process that connects to `niri msg -j event-stream`, filters events, debounces, and calls `niri msg action` to resize columns. Can run completely standalone without Noctalia.

2. **QML plugin layer** (Noctalia Shell integration) — provides GUI controls. `Main.qml` spawns/stops the Python daemon as a child process, passing settings as CLI args. The QML files depend on Noctalia/Quickshell APIs (`qs.Commons`, `qs.Widgets`, `qs.Services.UI`).

### Event flow (Python daemon)

```
niri event-stream → Event Filter (new window IDs only) → Rate Limiter → Debounce Timer → Redistribute All Workspaces → Restore Focus
```

Key detail: `WindowOpenedOrChanged` events are filtered by tracking `_known_window_ids`. Only truly new window IDs trigger redistribution — title changes (e.g., browser tab switches) are ignored.

### QML entry points (defined in `manifest.json`)

| File | Role |
|------|------|
| `Main.qml` | Daemon lifecycle (start/stop/restart), IPC handler, settings bridge, self-contained i18n |
| `BarWidget.qml` | Bar indicator with column count visualization and status dot |
| `Panel.qml` | Floating panel with visual 1-4 column grid selector |
| `Settings.qml` | Full settings page (toggles, sliders, status indicator) |

All QML components receive `pluginApi` from Noctalia and access the daemon instance via `pluginApi.mainInstance`. Settings are persisted through `pluginApi.saveSettings()`. Colors are entirely theme-driven (no hardcoded values).

### Niri IPC

All communication with niri uses `subprocess.run(["niri", "msg", ...])` in list form (never `shell=True`). Two helper functions:
- `niri_cmd(*args)` — queries that return JSON (windows, workspaces, focused-window)
- `niri_action(*args)` — fire-and-forget actions (focus-window, set-column-width, center-visible-columns)

### Thread safety

Shared mutable state (`_known_window_ids`, `_prev_col_counts`, `_debounce_timer`, rate limiter counters) is protected by a single `threading.Lock`. The debounce timer fires `redistribute()` on a separate thread.

## i18n

The plugin uses a **self-contained translation system** embedded in `Main.qml`. All EN and PT strings are defined as inline objects (`_enStrings`, `_ptStrings`) and resolved via `translate(key)`. This avoids dependency on the framework's `pluginApi.tr()`.

- **Language selection**: Configurable in Settings (Auto / English / Portuguese). The `auto` option detects the system locale via `Qt.locale().name`.
- **Live switching**: Changing language triggers `reloadLanguage()` which updates `_translations` and increments `translationVersion`. All QML components listen for `onTranslationVersionChanged` via `Connections` and re-render.
- **Access pattern**: Each QML component defines a local `t(key)` helper that calls `pluginApi.mainInstance.translate(key)`. Fallback uses `??` to English hardcoded strings.
- **Key namespacing**: `panel.*`, `bar.*`, `settings.*`.
- **Reference files**: `i18n/en.json` and `i18n/pt.json` serve as translation key reference but are **not loaded at runtime** — the strings are embedded in `Main.qml`.

## Requirements

- **niri** v25.11+ (JSON event-stream support)
- **Python** 3.10+ (uses `X | Y` union type syntax)
- **Noctalia Shell** 4.4+ (for the plugin UI — optional)
