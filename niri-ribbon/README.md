# Noctalia Niri Ribbon Widget

An independent widget for [Noctalia](https://github.com/noctalia-dev/noctalia) that tracks off-screen windows in the [niri](https://github.com/YaLTeR/niri) window manager's horizontal ribbon.

Developed by **J Pablo Puerta** <ews@folksonomy.com>.

## Features
- Real-time tracking of hidden windows to the left and right.
- Native Quickshell implementation via Noctalia's plugin system.
- Muted/Active color states based on window counts.
- Robust state handling via niri's `event-stream`.

## Installation

1. Clone this repository into your Noctalia plugins directory (or symlink it):
   ```bash
   mkdir -p ~/.config/noctalia/plugins
   ln -s ~/projects/noctalia-niri-ribbon ~/.config/noctalia/plugins/niri-ribbon
   ```

2. Enable the plugin in `~/.config/noctalia/plugins.json`:
   ```json
   "niri-ribbon": {
       "enabled": true
   }
   ```

3. Add the widget to your bar in `~/.config/noctalia/settings.json`:
   ```json
   "widgets": {
       "center": [
           { "id": "niri-ribbon" }
       ]
   }
   ```

## Requirements
- `niri` window manager
- `python3`
- `noctalia` / `quickshell`
