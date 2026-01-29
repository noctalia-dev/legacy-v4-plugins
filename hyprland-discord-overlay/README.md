# Discord Overlay (Hyprland)

Intelligent Discord window management for Hyprland with customizable overlay positioning.

## Features

- **Automatic Window Management**: Moves Discord to a special overlay workspace with floating window
- **Customizable Layout**: Adjust window size (width, height) and position (top margin) via percentage-based settings
- **Smart Detection**: Auto-detects screen resolution and Discord windows
- **Auto-Launch**: Optionally launch Discord automatically when toggling overlay
- **Quick Toggle**: Bar widget with visual status indicator for one-click access
- **Overlay Panel**: Control panel with Discord status, window preview, and keyboard shortcuts

## Requirements

- **Hyprland** window manager
- **jq** - JSON parser for window detection
- **Discord** - Discord application (optional if auto-launch disabled)
- **Noctalia** 3.6.0 or later

### Installation

Install required dependencies:

```bash
# Arch Linux
sudo pacman -S jq discord

# Ubuntu/Debian
sudo apt install jq discord
```

## Usage

### Quick Start

1. **Toggle Overlay**: Click the Discord icon in the bar
2. **Configure**: Open Settings panel to adjust window size and position
3. **Close**: Press `ESC` or click "Close" button in the overlay panel

### Configuration

Open the plugin settings to customize:

- **Auto-launch Discord**: Automatically launch Discord if not running
- **Window Width**: 50-100% of screen width (default: 80%)
- **Window Height**: 70-100% of screen height (default: 90%)
- **Top Margin**: 0-20% of screen height (default: 5%)

All settings use percentages for resolution independence.

### IPC Control

Toggle the overlay programmatically:

```bash
qs -p /path/to/noctalia ipc call plugin:hyprland-discord-overlay toggle
```

### Bar Widget

The bar widget displays:
- **Blue icon**: Discord is running
- **Gray icon**: Discord is not running
- **Hover**: Highlights the icon
- **Click**: Toggles the overlay

## How It Works

1. **Detection**: Plugin monitors for Discord windows using `hyprctl clients`
2. **Move to Overlay**: Moves Discord to special workspace `special:discord`
3. **Float & Position**: Sets window as floating and positions it based on settings
4. **Toggle**: Shows/hides the special workspace on demand
5. **Auto-detect**: Automatically moves new Discord windows to overlay workspace

### Hyprland Commands Used

```bash
# Move window to special workspace
hyprctl dispatch movetoworkspacesilent special:discord,address:ADDRESS

# Set as floating
hyprctl dispatch setfloating address:ADDRESS

# Resize window
hyprctl dispatch resizewindowpixel exact WIDTH HEIGHT,address:ADDRESS

# Position window
hyprctl dispatch movewindowpixel exact X Y,address:ADDRESS

# Toggle special workspace
hyprctl dispatch togglespecialworkspace discord
```

## Troubleshooting

### Discord doesn't appear in overlay

- Check if Discord is running: `pidof discord`
- Verify Hyprland is running: `echo $HYPRLAND_INSTANCE_SIGNATURE`
- Check for Discord window: `hyprctl clients | grep discord`

### Window size/position incorrect

- Re-toggle the overlay after changing settings
- Verify screen resolution detection: check logs
- Manually adjust percentages in settings

### Auto-launch not working

- Ensure `discord` command is in PATH: `which discord`
- Check plugin logs for launch errors
- Try launching Discord manually first

## Technical Details

### Window Detection

Detects Discord windows with:
```bash
hyprctl clients -j | jq '.[] | select(.class == "discord" and .fullscreen == 0)'
```

Excludes fullscreen Discord to avoid interfering with video calls or streaming.

### Monitoring

- **Discord Process**: Checked every 3 seconds
- **New Windows**: Checked every 150ms when overlay is active
- **Resolution**: Detected once on plugin load

### Percentage-Based Layout

All dimensions are calculated from screen resolution:
```javascript
windowWidth = screenWidth * (windowWidthPercent / 100)
windowHeight = screenHeight * (windowHeightPercent / 100)
topMargin = screenHeight * (topMarginPercent / 100)
centerX = (screenWidth - windowWidth) / 2
```

## Limitations

- **Hyprland Only**: Uses Hyprland-specific IPC commands
- **Single Window**: Manages first detected Discord window only
- **No Fullscreen**: Ignores fullscreen Discord windows
- **jq Required**: Requires `jq` for JSON parsing

## Contributing

Contributions welcome! Please submit issues or pull requests to the Noctalia plugins repository.

## License

MIT License - see LICENSE file for details.

## Credits

- **Author**: blacku
- **Noctalia**: [noctalia.dev](https://github.com/noctalia-dev)
- **Hyprland**: [hyprland.org](https://hyprland.org)
