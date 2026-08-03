# Wi-Fi QR

A Noctalia Shell plugin that shows a QR code to join the current Wi-Fi network.

## Features

- **Bar Widget**: Click the QR icon in the bar to open the panel
- **Panel**: Shows a scannable QR code for the active Wi-Fi connection, including the network name
- **IPC Support**: Open, close, or toggle the panel from external scripts or global hotkeys

## Usage

Add the bar widget to your bar, then click it to open the panel with the QR code.

### IPC Commands

Control the panel from external scripts using Quickshell IPC:

```bash
# Toggle the panel (open if closed, close if open)
qs -c noctalia-shell ipc call plugin:wifi-qr toggle

# Open the panel
qs -c noctalia-shell ipc call plugin:wifi-qr open

# Close the panel
qs -c noctalia-shell ipc call plugin:wifi-qr close
```

### Global Hotkey Example

Bind a key to toggle the panel, e.g. in Hyprland:

```ini
bind = SUPER, Q, exec, qs -c noctalia-shell ipc call plugin:wifi-qr toggle
```

## Requirements

- Noctalia Shell v4.1.0 or newer
- `nmcli` (from NetworkManager) and `qrencode` for QR generation
- An active Wi-Fi connection

## Installation

Copy the plugin folder into your Noctalia plugins directory (e.g. `~/.config/noctalia/plugins/wifi-qr/`) and enable it from the Plugins settings panel.
