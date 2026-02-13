# Screenshot Plugin

A simple screenshot plugin for Noctalia Shell that provides a button in the bar to quickly take screenshots. Automatically detects your compositor and uses the appropriate tool.

## Features

- **Quick Screenshot**: One-click screenshot button in the bar
- **Compositor Detection**: Automatically detects Hyprland or Niri and uses the appropriate tool
- **Two Modes** (Hyprland only): Choose between region selection or direct full screen capture
- **Niri Screenshot Types**: Choose between default (interactive), window, or fullscreen capture
- **Clipboard Integration**: Screenshots are automatically copied to clipboard
- **Silent Operation**: Runs silently without notifications

## Requirements

- **Hyprland**: 
  - **hyprshot** - The screenshot tool
    - Install via package manager: `hyprshot`
- **Niri**: 
  - Built-in screenshot functionality (no additional tools required)
- Noctalia 3.6.0 or later

## Installation

1. Copy this plugin to your Noctalia plugins directory:
   ```bash
   cp -r screenshot ~/.config/noctalia/plugins/
   ```

2. Add the widget to your bar through Noctalia settings

## Usage

### Bar Widget

- **Left Click**: Take a screenshot (mode depends on configuration)
- **Right Click**: Open plugin settings

### Configuration

**Hyprland**: Configure the screenshot mode through the settings panel:

- **Region Selection**: Opens a region selector to capture a specific area
- **Full Screen**: Captures the entire screen directly

**Niri**: Configure the screenshot type through the settings panel:

- **Default (Interactive)**: Opens Niri's interactive screenshot UI
- **Window**: Captures the focused window
- **Fullscreen**: Captures the entire screen

When clicked, the plugin will:
1. Detect your compositor (Hyprland or Niri)
2. Use the appropriate tool:
   - **Hyprland**: `hyprshot` with the selected mode (region or screen)
   - **Niri**: `niri msg action screenshot` with the selected type (default, window, or fullscreen)
3. Copy the screenshot to clipboard
4. Run silently without notifications

## License

MIT License
