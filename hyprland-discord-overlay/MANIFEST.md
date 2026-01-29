# Discord Overlay (Hyprland) - Plugin Manifest

## Overview

Discord Overlay is a Noctalia plugin that provides intelligent window management for Discord on Hyprland. It automatically positions Discord in a special overlay workspace with customizable size and positioning, making it easy to quickly access Discord without switching workspaces.

## Plugin Information

- **ID**: `hyprland-discord-overlay`
- **Name**: Discord Overlay (Hyprland)
- **Version**: 1.0.0
- **Author**: blacku
- **License**: MIT
- **Minimum Noctalia Version**: 3.6.0

## Features

### Core Functionality

1. **Automatic Window Management**
   - Detects Discord windows automatically
   - Moves Discord to special workspace (`special:discord`)
   - Sets window as floating with custom dimensions
   - Centers and positions window on screen

2. **Configurable Layout**
   - Adjustable window width (50-100%)
   - Adjustable window height (70-100%)
   - Customizable top margin (0-20%)
   - All values are percentage-based for resolution independence

3. **Smart Detection**
   - Auto-detects screen resolution via Hyprland IPC
   - Monitors for new Discord windows
   - Automatically moves new windows to overlay workspace
   - Prevents fullscreen Discord from being moved

4. **Auto-Launch**
   - Optional automatic Discord launch
   - Launches Discord if not running when overlay is toggled

5. **IPC Integration**
   - Toggle overlay via `qs ipc call plugin:hyprland-discord-overlay toggle`
   - Bar widget with visual status indicator
   - Panel for overlay management

## Entry Points

### Main.qml
Core plugin logic implementing:
- Discord process monitoring
- Window detection and management
- Resolution detection
- Overlay workspace management
- IPC handler for remote control

### BarWidget.qml
Status bar indicator showing:
- Discord running status (colored icon)
- Clickable toggle for overlay
- Visual feedback on hover

### Panel.qml
Overlay control panel displaying:
- Discord status indicator
- Window layout preview
- Close button with keyboard shortcut (ESC)

### Settings.qml
Configuration UI with:
- Auto-launch Discord toggle
- Window dimension sliders (width, height)
- Position controls (top margin)
- Real-time preview of percentage values

## Default Settings

```json
{
  "autoLaunchDiscord": true,
  "windowWidthPercent": 80,
  "windowHeightPercent": 90,
  "topMarginPercent": 5
}
```

## Dependencies

### System Requirements
- **Window Manager**: Hyprland (required)
- **Required Commands**:
  - `hyprctl` - Hyprland IPC control
  - `jq` - JSON parsing for window detection
  - `discord` - Discord application (optional if auto-launch disabled)

### Plugin Dependencies
None - standalone plugin

## Technical Details

### Window Detection
Uses `hyprctl clients -j` with jq filtering to find Discord windows:
```bash
hyprctl clients -j | jq '.[] | select(.class == "discord" and .fullscreen == 0)'
```

### Window Management Commands
1. Move to workspace: `hyprctl dispatch movetoworkspacesilent special:discord,address:ADDRESS`
2. Set floating: `hyprctl dispatch setfloating address:ADDRESS`
3. Resize: `hyprctl dispatch resizewindowpixel exact WIDTH HEIGHT,address:ADDRESS`
4. Position: `hyprctl dispatch movewindowpixel exact X Y,address:ADDRESS`
5. Toggle workspace: `hyprctl dispatch togglespecialworkspace discord`

### Monitoring
- Discord process check: every 3 seconds
- New window detection: every 150ms (only when overlay active)
- Resolution detection: on plugin load

## Internationalization

Supports i18n with English locale included (`i18n/en.json`).

Translation keys:
- `main.plugin_loaded`
- `main.ipc_received`
- `main.launching_discord`
- `main.no_window_found`
- `main.window_found`
- `main.window_moved`
- `main.workspace_toggled`
- `main.resolution_detected`

## Usage

1. **Toggle Overlay**: Click bar widget or use IPC call
2. **Configure Layout**: Open settings panel to adjust window size/position
3. **Close Overlay**: Press ESC or click close button in panel
4. **Auto-launch**: Enable in settings to launch Discord automatically

## Limitations

- Hyprland-specific (uses Hyprland IPC)
- Requires `jq` for JSON parsing
- Only manages non-fullscreen Discord windows
- Single Discord window support (moves first detected window)

## Changelog

### v1.0.0 (Initial Release)
- Automatic Discord window management
- Configurable window dimensions (percentage-based)
- Auto-launch Discord support
- Special workspace integration
- Bar widget with status indicator
- Settings panel with sliders
- IPC control interface
- New window auto-detection
