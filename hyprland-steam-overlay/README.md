# Steam Overlay for Noctalia

> ## ⚠️ DEPRECATED — not maintained from Hyprland 0.55+
>
> Hyprland 0.55 deprecated hyprlang (`.conf`) in favour of Lua (`.lua`), which
> changed how `hyprctl dispatch` is parsed and how popups/xdg surfaces are
> handled. These changes broke the overlay's window management and the bar
> widget's context menu, and make the special-workspace overlay approach no
> longer worthwhile.
>
> **This plugin is no longer actively maintained.** The final `2.2.0` release
> includes a best-effort dual-mode dispatch fix and an optional custom Lua
> layout so it still works on Hyprland 0.55, but **no further updates are
> planned**. Use at your own discretion.

Steam overlay plugin for Noctalia/Quickshell with automatic window management using Hyprland special workspace.

## Features

- 🎮 **Automatic Steam window detection** and positioning
- 🖥️ **Multi-monitor support** with automatic resolution detection
- 📐 **Responsive layout**: 10% / 60% / 25% split (Friends / Main / Chat)
- 🎯 **Centered overlay** with 95% screen height
- 🔔 **Chat notifications** indicator
- ⌨️ **Keyboard shortcut** support via IPC
- 🎨 **Bar widget** with Steam status indicator

## Installation

1. Copy the plugin to your Noctalia plugins directory:
```bash
cp -r steam-overlay ~/.config/noctalia/plugins/
```

2. Restart Quickshell:
```bash
pkill -f "qs.*noctalia" && qs -c noctalia-shell &
```

## Usage

### Via Bar Widget
Click the gamepad icon in your top bar to toggle the Steam overlay.

### Via Keyboard Shortcut

hyprlang config (`~/.config/hypr/hyprland.conf`):
```
bind = SUPER, G, exec, qs -c noctalia-shell ipc call plugin:hyprland-steam-overlay toggle
```

Lua config (`~/.config/hypr/hyprland.lua`, Hyprland 0.55+):
```lua
hl.bind("SUPER + G", hl.dsp.exec_cmd("qs -c noctalia-shell ipc call plugin:hyprland-steam-overlay toggle"))
```

### Via IPC Command
```bash
qs -c noctalia-shell ipc call plugin:hyprland-steam-overlay toggle
```

## How It Works

1. **Detection**: Automatically detects Steam windows by class and title
2. **Workspace**: Moves all Steam windows to Hyprland special workspace `special:steam`
3. **Positioning**: Arranges windows in a centered layout:
   - Friends List: 10% width (left)
   - Main Steam: 60% width (center)
   - Chat: 25% width (right)
4. **Toggle**: Shows/hides the special workspace as an overlay

## Layout

```
┌─────────────────────────────────────────┐
│  [Friends]   [   Main Steam   ]  [Chat] │ 95% height
│    10%              60%            25%   │ Centered
└─────────────────────────────────────────┘
```

## Configuration

Default settings in `settings.json`:
```json
{
  "autoLaunchSteam": true,
  "hasNewMessages": false
}
```

## Hyprland 0.55+ / Lua config

Since Hyprland 0.55, hyprlang (`.conf`) is deprecated in favour of Lua
(`.lua`). Under a Lua config, `hyprctl dispatch` is parsed **as Lua**, so the
old classic dispatch syntax errors out — this is what broke the overlay on
older plugin versions.

The plugin now **auto-detects** the active config mode at startup (probing
`hyprctl dispatch 'hl.dsp.no_op()'`) and emits the correct syntax for either
hyprlang or Lua. No configuration needed — it just works on both.

## Optional: custom Hyprland Lua layout

Instead of floating + pixel-positioning the windows, you can let Hyprland's
custom layout API (0.55+) tile them. This auto-reflows on window add/remove
/resize, with no polling and no pixel math.

1. Copy the layout next to your Lua config:
   ```bash
   cp ~/.config/noctalia/plugins/hyprland-steam-overlay/steam-layout.lua ~/.config/hypr/steam-layout.lua
   ```
2. In `~/.config/hypr/hyprland.lua` add:
   ```lua
   require("steam-layout")
   hl.workspace_rule({ workspace = "special:steam", layout = "lua:steam" })
   ```
   The `workspace_rule` scopes the layout to **only** the steam overlay
   workspace, leaving your normal layout untouched everywhere else.
3. Reload Hyprland, then enable **"Use custom Hyprland layout (Lua)"** in the
   plugin settings.

If the setting is enabled but the snippet is missing, Steam windows still
open in the overlay workspace using your default layout (graceful fallback).
Edit the width ratios at the top of `steam-layout.lua` to taste.

## Requirements

- Noctalia/Quickshell 3.6.0+
- Hyprland compositor (hyprlang or Lua config — both supported)
- Steam
- `jq` for JSON parsing
- `hyprctl` for window management
- Custom layout (optional): Hyprland 0.55+ with a Lua config

## Files

- `Main.qml` - Core plugin logic
- `BarWidget.qml` - Top bar widget with icon
- `Panel.qml` - Overlay panel (optional)
- `manifest.json` - Plugin metadata
- `settings.json` - Plugin settings
- `steam-layout.lua` - Optional Hyprland custom Lua layout (0.55+)

## Author

Created with ❤️ using Claude Code

## License

MIT
