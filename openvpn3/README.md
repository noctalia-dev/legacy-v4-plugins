# OpenVPN3 Plugin

Manage OpenVPN3 VPN connections from the Noctalia bar and control center.

## Features

- **OpenVPN brand icon** — Custom OpenVPN logo on the bar, control center, and panel (colorized by theme)
- **Real-time status** — Icon color indicates connection state
- **One-click connect/disconnect** — Click to toggle, with loading spinner inside button
- **Session stats** — View download/upload bytes, packets, and reconnect count
- **Restart sessions** — Hover over active sessions to restart
- **Config details** — Double-click disconnected items to see server/port/protocol
- **Log streaming** — Stream VPN logs in real-time
- **Import configs** — Import .ovpn files with custom names and persistence toggle
- **Rename/Delete** — Manage configs with confirmation flows
- **Persistent vs Temporary** — Lock icon for persistent, clock icon for temporary configs
- **Hide when inactive** — Optionally hide the bar widget when VPN is disconnected
- **Two-tier polling** — Light polling keeps the bar updated; heavy polling (stats, logs) only runs when panel is open

## Requirements

- `openvpn3` CLI installed and in PATH
- OpenVPN3 D-Bus service running

## Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| Display Mode | When to show label (always, onhover, never) | onhover |
| Connected Color | Icon color when connected | primary |
| Disconnected Color | Icon color when disconnected | none |
| Poll Interval | Status check interval (seconds) | 5 |
| Show Notifications | Toast on errors | true |
| Default Persistent | Default for new imports | true |
| Hide When Inactive | Hide bar widget when VPN is disconnected | false |

## Usage

1. Add `"plugin:openvpn3"` to your bar widgets in `settings.json`
2. Click the shield icon to open the VPN panel
3. Click a config to connect/disconnect
4. Right-click or double-click for more options

## Tags

- Bar
- Panel
- Network
- Utility