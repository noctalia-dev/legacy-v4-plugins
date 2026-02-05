# Tailscale Plugin

A Tailscale status plugin for Noctalia that shows your Tailscale connection status in the menu bar.

![Preview of the tailscale status plugin](preview.png)

> **Disclaimer:** This is a community-created plugin built on top of the great Tailscale CLI tool. It is not affiliated with, endorsed by, or officially connected to Tailscale Inc.

## Features

- **Status Indicator**: Shows whether Tailscale is connected or disconnected with a visual indicator
- **IP Address Display**: Shows your current Tailscale IP address when connected
- **Peer Count**: Displays the number of connected devices in your tailnet
- **Quick Toggle**: Click to connect/disconnect Tailscale
- **Context Menu**: Right-click for additional options (connect, disconnect, refresh, settings)
- **Configurable Refresh**: Customize how often the plugin checks Tailscale status
- **Compact Mode**: Option to show only the icon for a minimal display

## Requirements

- Tailscale must be installed on your system
- Tailscale must be set up and authenticated

## Settings

| Setting | Default | Description |
|---|---|---|
| `refreshInterval` | 5000 ms | How often to check Tailscale status (1000-60000 ms) |
| `compactMode` | false | Show only the icon in the menu bar |
| `showIpAddress` | true | Display your Tailscale IP address |
| `showPeerCount` | true | Display the number of connected peers |
| `hideDisconnected` | false | Hide the widget when Tailscale is disconnected |
| `terminalCommand` | "" | Terminal command prefix for SSH (e.g., `wezterm start --` or `ghostty`) |
| `pingCount` | 5 | Number of pings to send when pinging a peer |
| `defaultPeerAction` | "copy-ip" | Action when clicking a peer: `copy-ip`, `ssh`, or `ping` |

## IPC Commands

You can control the Tailscale plugin via the command line using the Noctalia IPC interface.

### General Usage
```bash
qs -c noctalia-shell ipc call plugin:tailscale <command>
```

### Available Commands

| Command | Description | Example |
|---|---|---|
| `toggle` | Toggle Tailscale connection (connect/disconnect) | `qs -c noctalia-shell ipc call plugin:tailscale toggle` |
| `status` | Get current Tailscale status | `qs -c noctalia-shell ipc call plugin:tailscale status` |
| `refresh` | Force refresh Tailscale status | `qs -c noctalia-shell ipc call plugin:tailscale refresh` |

### Examples

**Connect to Tailscale:**
```bash
qs -c noctalia-shell ipc call plugin:tailscale toggle
```

**Check current status:**
```bash
qs -c noctalia-shell ipc call plugin:tailscale status
```

**Force refresh status:**
```bash
qs -c noctalia-shell ipc call plugin:tailscale refresh
```

## Usage

1. **Click** the icon to toggle Tailscale connection (connect/disconnect)
2. **Right-click** to open the context menu with options to connect, disconnect, refresh, or open settings
3. The icon will be colored when connected and gray when disconnected
4. Your Tailscale IP and peer count are displayed (unless in compact mode)

## Troubleshooting

### "Not installed" message
If you see "Tailscale not installed" in the context menu, make sure Tailscale is installed and accessible in your PATH.

### Status not updating
If the status doesn't update automatically, try:
1. Increasing the refresh interval in settings
2. Using the "Refresh" option from the context menu
3. Checking that Tailscale is running properly on your system

### Cannot connect/disconnect
Ensure that:
- You have proper permissions to control Tailscale
- Tailscale is authenticated and set up
- No other process is interfering with Tailscale
