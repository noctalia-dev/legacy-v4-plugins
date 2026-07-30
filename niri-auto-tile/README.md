# niri-auto-tile

**Auto-tiling daemon for [niri](https://github.com/YaLTeR/niri) compositor** — automatically redistributes column widths evenly when windows are opened or closed.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![niri](https://img.shields.io/badge/niri-v25.11+-green.svg)](https://github.com/YaLTeR/niri)
[![Python](https://img.shields.io/badge/Python-3.10+-yellow.svg)](https://python.org)
[![Noctalia Plugin](https://img.shields.io/badge/Noctalia-Plugin-purple.svg)](https://github.com/noctalia-dev/noctalia-plugins)

---

## The Problem

Niri is a scrollable-tiling Wayland compositor where windows are arranged in columns on an infinite horizontal strip. When you open or close windows, existing columns don't automatically resize to fill the viewport — you're left with empty space or columns scrolled off-screen.

## The Solution

`niri-auto-tile` listens to niri's JSON event stream and automatically resizes all tiling columns to equal widths whenever a window is opened or closed. If you have 4 columns and close one, the remaining 3 instantly expand to fill the screen.

### Features

- **Automatic redistribution** — columns resize instantly on window open/close
- **Multi-workspace support** — redistributes all active workspaces, restoring original focus afterwards
- **Configurable max visible columns** — caps how many columns fit on screen (default: 4)
- **Per-workspace settings** — each workspace can have its own column count
- **Only at max mode** — only redistribute when column count reaches the configured maximum
- **Smart event filtering** — only reacts to actual window open/close, ignores title changes (e.g., browser tab switches)
- **Theme-aware UI** — all colors follow the active Noctalia theme (no hardcoded colors)
- **Thread-safe debouncing** — coalesces rapid events to prevent flickering
- **Rate limiting** — circuit breaker for event floods (20 events/second cap)
- **Auto-reconnection** — recovers if the niri event stream drops
- **Graceful shutdown** — handles SIGTERM cleanly
- **JSON IPC** — uses niri's structured JSON protocol, not fragile text parsing
- **Input validation** — validates all IPC responses and data types
- **i18n** — English and Portuguese translations

---

## Installation

### Standalone (any niri setup)

1. **Copy the script:**

   ```bash
   cp auto-tile.py ~/.config/niri/auto-tile.py
   chmod 700 ~/.config/niri/auto-tile.py
   ```

2. **Add to niri autostart** (`~/.config/niri/config.kdl`):

   ```kdl
   spawn-at-startup "python3" "/home/YOUR_USER/.config/niri/auto-tile.py"
   ```

3. **Restart niri** or run manually:

   ```bash
   python3 ~/.config/niri/auto-tile.py
   ```

### Noctalia Shell Plugin

If you use [noctalia-shell](https://github.com/noctalia-dev/noctalia-shell), this project includes a native plugin with a bar indicator, floating panel, and settings UI:

1. **Clone into the plugins directory:**

   ```bash
   git clone https://github.com/pir0c0pter0/niri-auto-tile.git \
     ~/.config/noctalia/plugins/niri-auto-tile
   ```

2. **Enable** in Noctalia Settings > Plugins > niri-auto-tile

3. **Add the bar widget** — drag "Auto-Tile" to your bar in Noctalia Settings > Bar

### Systemd User Service (optional)

For process supervision with automatic restart:

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/niri-auto-tile.service << 'EOF'
[Unit]
Description=niri auto-tile daemon
After=graphical-session.target

[Service]
ExecStart=/usr/bin/python3 %h/.config/niri/auto-tile.py
Restart=on-failure
RestartSec=2
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user enable --now niri-auto-tile.service
```

---

## Noctalia Plugin UI

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
- **About** — credits and version info

---

## Configuration

### CLI Arguments

```bash
python3 auto-tile.py \
  --max-visible 4 \
  --debounce 0.3 \
  --max-events 20 \
  --only-at-max \
  --per-workspace \
  --workspace-config '{"3":2,"1":4}' \
  --debug
```

### Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MAX_VISIBLE` | `4` | Maximum columns visible on screen at once |
| `MAX_COLUMNS` | `20` | Safety cap for total column count |
| `DEBOUNCE_SECONDS` | `0.3` | Delay before redistribution (coalesces rapid events) |
| `NIRI_TIMEOUT` | `5` | Timeout for niri IPC calls (seconds) |
| `RECONNECT_DELAY` | `2.0` | Delay before reconnecting after event stream drops |
| `MAX_EVENTS_PER_SECOND` | `20` | Rate limiter threshold |
| `PER_WORKSPACE` | `False` | Per-workspace column count settings |
| `ONLY_AT_MAX` | `True` | Only redistribute at or above max visible |

### Recommended niri layout

For best results, set your default column width to match `MAX_VISIBLE`:

```kdl
// ~/.config/niri/config.kdl
layout {
    default-column-width { proportion 0.25; }  // 1/4 for MAX_VISIBLE=4
    preset-column-widths {
        proportion 0.25
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }
}
```

---

## How It Works

```
niri event-stream (JSON)
         |
         v
   Event Filter          — only WindowOpened / WindowClosed (not title changes)
         |
         v
   Rate Limiter          — max 20 events/second sliding window
         |
         v
   Debounce Timer        — 300ms coalescence
         |
         v
   Save Original Focus   — remember current workspace and focused window
         |
         v
   Redistribute All      — set-column-width for each column on every active workspace
         |
         v
   Restore Focus         — return to original workspace and window
```

### Multi-Workspace Redistribution

When a window event triggers redistribution:

1. The daemon saves the currently focused workspace and window
2. Iterates through all active workspaces with tiled windows
3. For each workspace, focuses a window there, walks columns, and sets equal widths
4. After all workspaces are processed, restores focus to the original window
5. If no window was focused (e.g., panel was open), falls back to focusing any window on the original workspace via `niri msg -j workspaces`

### Event Filtering

The script maintains a set of known window IDs. When `WindowOpenedOrChanged` fires:
- If the window ID is **new** -> trigger redistribution
- If the window ID **already exists** -> it's just a title change, skip

This prevents the flickering that would occur with apps like Firefox that fire `WindowOpenedOrChanged` on every tab switch or page load.

### Width Calculation

Columns are sized to fill exactly 100% of the viewport:

| Columns | Width per column |
|---------|-----------------|
| 1 | 100% |
| 2 | 50% |
| 3 | 33% + 33% + 34% |
| 4 | 25% |
| 5+ | 25% each (scrolled) |

The last column absorbs any rounding remainder to ensure widths sum to exactly 100%.

---

## Logging

The script logs to stdout with structured messages:

```
18:07:44 INFO auto-tile: starting (max_visible=4, mode=global, debounce=300ms)
18:07:44 INFO auto-tile: tracking 4 existing windows
18:08:01 INFO auto-tile: ws=3: 4 cols, max=4 -> 25% each (+0% last)
```

When using systemd, view logs with:

```bash
journalctl --user -u niri-auto-tile -f
```

---

## Compatibility

- **niri** v25.11+ (requires JSON event-stream support)
- **Python** 3.10+ (uses `X | Y` union syntax)
- **noctalia-shell** 4.4+ (for the plugin — optional)

No external Python dependencies required — uses only the standard library.

---

## Security

This script has been through two rounds of multi-perspective security review (5 specialized agents each round). Key security properties:

- **No shell injection** — all subprocess calls use list form, never `shell=True`
- **No network access** — communicates only via local niri IPC
- **No credentials or secrets** — reads only window metadata
- **Input validation** — all IPC responses are type-checked and validated
- **Thread safety** — all shared state protected by `threading.Lock`
- **Rate limiting** — prevents event flood DoS
- **Graceful shutdown** — SIGTERM handler without deadlock risk

---

## Troubleshooting

### Windows don't redistribute

1. Check if the script is running: `pgrep -f auto-tile.py`
2. Check logs: `journalctl --user -u niri-auto-tile -f` or `/tmp/auto-tile.log`
3. Verify niri IPC works: `niri msg -j windows`

### Flickering when switching browser tabs

This should not happen — the script filters title-change events. If it does:
1. Increase `DEBOUNCE_SECONDS` to `0.5`
2. Check logs for unexpected `WindowOpenedOrChanged` events with new IDs

### Script crashes on startup

Ensure niri is running and `niri msg -j event-stream` produces output. The script will auto-reconnect if the stream drops.

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test with at least 2-4 windows across multiple workspaces
4. Submit a pull request

---

## License

[MIT](LICENSE) — same as niri.

---

## Credits

Developed by Pir0c0pter0 using [Claude Code](https://claude.ai/claude-code).

## Acknowledgements

- [niri](https://github.com/YaLTeR/niri) by YaLTeR — the scrollable-tiling Wayland compositor
- [noctalia-shell](https://github.com/noctalia-dev/noctalia-shell) — the desktop shell framework
