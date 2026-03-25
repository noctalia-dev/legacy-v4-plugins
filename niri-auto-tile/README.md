# niri-auto-tile

**Auto-tiling daemon for [niri](https://github.com/YaLTeR/niri) compositor** — automatically redistributes column widths evenly when windows are opened or closed.

---

## Features

- **Automatic redistribution** — columns resize instantly on window open/close
- **Multi-workspace support** — redistributes all active workspaces, restoring original focus afterwards
- **Configurable max visible columns** — caps how many columns fit on screen (default: 4)
- **Per-workspace settings** — each workspace can have its own column count
- **Only at max mode** — only redistribute when column count reaches the configured maximum
- **Smart event filtering** — only reacts to actual window open/close, ignores title changes
- **Theme-aware UI** — all colors follow the active Noctalia theme
- **Hot-reload config** — update settings without restarting the daemon (SIGUSR1)
- **Thread-safe debouncing** — coalesces rapid events to prevent flickering
- **Rate limiting** — circuit breaker for event floods
- **i18n** — 10 languages (en, pt, es, fr, de, it, ru, zh, ja, ko)

---

## Usage

### Bar Widget

- Column indicators showing the current max visible count
- Status dot (theme primary = running, theme secondary = starting)
- Left-click opens the floating panel
- Right-click context menu: enable/disable, settings

### Floating Panel

- Enable/disable toggle in the header
- Visual column layout selector (1-4 columns grid)
- Status bar with current state and workspace info

### Settings

- **Enable Auto-Tile** — master on/off switch
- **Per workspace** — each workspace has its own column count
- **Only at max** — only redistribute when columns reach the maximum
- **Max visible columns** — slider from 1 to 8
- **Debounce delay** — 100-1000ms event coalescence
- **Rate limit** — 5-50 events per second
- **Daemon status** — running/error/stopped indicator

---

## Files

| File | Role |
|------|------|
| `Main.qml` | Daemon lifecycle (start/stop/restart), settings bridge |
| `BarWidget.qml` | Bar indicator with column count visualization and status dot |
| `Panel.qml` | Floating panel with visual column grid selector |
| `Settings.qml` | Full settings page (toggles, sliders, status indicator) |
| `auto-tile.py` | Python daemon — core auto-tiling logic |

---

## Author

Developed by [Pir0c0pter0](https://github.com/pir0c0pter0).

Standalone repo: [pir0c0pter0/niri-auto-tile](https://github.com/pir0c0pter0/niri-auto-tile)
