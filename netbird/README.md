# NetBird Plugin

A NetBird VPN status plugin for Noctalia that shows your NetBird connection status in the menu bar.

> **Disclaimer:** This is a community-created plugin built on top of the NetBird CLI tool. It is not affiliated with, endorsed by, or officially connected to NetBird GmbH.

## Features

- **Status Indicator**: Shows whether NetBird is connected or disconnected with a visual indicator
- **IP Address Display**: Shows your current NetBird IP address when connected
- **Peer Count**: Displays connected/total peer count in your network
- **Connection Type**: Shows if peers are connected via P2P or Relayed
- **Management & Signal Status**: Visual indicators for management and signal server connectivity
- **FQDN Display**: Shows your fully qualified domain name
- **Quick Toggle**: Click to connect/disconnect NetBird (`netbird up` / `netbird down`)
- **Context Menu**: Right-click for additional options (connect, disconnect, settings)
- **Configurable Refresh**: Customize how often the plugin checks NetBird status
- **Compact Mode**: Option to show only the icon for a minimal display
- **Admin Console**: Quick link to NetBird admin console (app.netbird.io)

## Requirements

- NetBird must be installed on your system
- NetBird must be set up and authenticated
- The `netbird` CLI must be accessible in your PATH

## How It Works

The plugin uses the `netbird` CLI under the hood:

| Action | CLI Command |
|---|---|
| Check status | `netbird status --json` |
| Connect | `netbird up` |
| Disconnect | `netbird down` |
| Check installed | `which netbird` |

The JSON output from `netbird status --json` provides all the peer details, connection status, management/signal server connectivity, and network information.

## Settings

| Setting | Default | Description |
|---|---|---|
| `refreshInterval` | 5000 ms | How often to check NetBird status (1000-60000 ms) |
| `compactMode` | false | Show only the icon in the menu bar |
| `showIpAddress` | true | Display your NetBird IP address |
| `showPeerCount` | true | Display the number of connected peers |
| `hideDisconnected` | false | Hide disconnected peers in the panel |
| `terminalCommand` | "" | Terminal command prefix for SSH (e.g., `ghostty`, `alacritty`, `kitty`) |
| `pingCount` | 5 | Number of pings to send when pinging a peer |
| `defaultPeerAction` | "copy-ip" | Action when clicking a peer: `copy-ip`, `ssh`, or `ping` |

## IPC Commands

You can control the NetBird plugin via the command line using the Noctalia IPC interface.

### General Usage
```bash
qs -c noctalia-shell ipc call plugin:netbird <command>
```

### Available Commands

| Command | Description | Example |
|---|---|---|
| `toggle` | Toggle NetBird connection (connect/disconnect) | `qs -c noctalia-shell ipc call plugin:netbird toggle` |
| `status` | Get current NetBird status | `qs -c noctalia-shell ipc call plugin:netbird status` |
| `refresh` | Force refresh NetBird status | `qs -c noctalia-shell ipc call plugin:netbird refresh` |

### Examples

**Connect to NetBird:**
```bash
qs -c noctalia-shell ipc call plugin:netbird toggle
```

**Check current status:**
```bash
qs -c noctalia-shell ipc call plugin:netbird status
```

**Force refresh status:**
```bash
qs -c noctalia-shell ipc call plugin:netbird refresh
```

## Usage

1. **Click** the bar widget to open the panel with peer details
2. **Right-click** to open the context menu with options to connect, disconnect, or open settings
3. The icon will be colored when connected and crossed out when disconnected
4. Your NetBird IP, FQDN, and connected/total peer count are displayed (unless in compact mode)
5. Each peer shows its connection type (P2P or Relayed) and IP address
6. Click a peer to perform the default action (copy IP, SSH, or ping)
7. Right-click a peer for more actions

## Troubleshooting

### "Not installed" message
If you see "NetBird not installed", make sure NetBird is installed and the `netbird` binary is accessible in your PATH.

### Status not updating
If the status doesn't update automatically, try:
1. Increasing the refresh interval in settings
2. Using the IPC `refresh` command
3. Checking that NetBird daemon is running (`netbird service status`)

### Cannot connect/disconnect
Ensure that:
- You have proper permissions to control NetBird
- NetBird is authenticated and set up (`netbird up` in terminal first)
- The NetBird daemon service is running (`netbird service start`)
