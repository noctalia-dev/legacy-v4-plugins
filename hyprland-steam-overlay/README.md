# Steam Overlay for Noctalia

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
Add to your Hyprland config (`~/.config/hypr/hyprland.conf`):
```
bind = SUPER, G, exec, qs -c noctalia-shell ipc call plugin:steam-overlay toggle
```

### Via IPC Command
```bash
qs -c noctalia-shell ipc call plugin:steam-overlay toggle
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

## Requirements

- Noctalia/Quickshell 3.6.0+
- Hyprland compositor
- Steam
- `jq` for JSON parsing
- `hyprctl` for window management

## Files

- `Main.qml` - Core plugin logic
- `BarWidget.qml` - Top bar widget with icon
- `Panel.qml` - Overlay panel (optional)
- `manifest.json` - Plugin metadata
- `settings.json` - Plugin settings

## Author

Created with ❤️ using Claude Code

## License

MIT
