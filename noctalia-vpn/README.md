# Noctalia VPN

VPN/proxy manager for [Noctalia Shell](https://noctalia.dev). Drives a local
[sing-box](https://sing-box.sagernet.org) instance through a Python DBus
backend; the plugin itself is a QML front-end that talks to the backend over
the session bus.

![Preview](preview.png)

## What it does

- Manage proxy servers (add / edit / switch / ping)
- Toggle the system SOCKS5 proxy or a TUN device, both transparently
- Route blocked sites through the tunnel via country presets (RU / CN / IR)
- Add custom rules to force a domain through the proxy, force it direct, or
  block it outright
- Watch live latency, jitter, and up/down throughput
- One-shot network speed test that always measures the tunnel (not the
  direct-Internet bypass) regardless of mode
- Kill switch via `nft` rules — only the configured server endpoint stays
  reachable when the proxy is down
- Subscription import for VLESS / VMess / SS / SOCKS5 share links

## Supported protocols

- **SSH** (password or key file) — handled directly by OpenSSH
- **VLESS** (including Reality, WS, gRPC, HTTP/2)
- **VMess**
- **Shadowsocks**
- **SOCKS5**

## Features

- Bar widget showing connection state, server name, ping, and traffic counters
  (ping/traffic visibility independently toggleable in Settings → General)
- Panel with server list, live health, routing chips, network test card
- Two routing modes:
  - `rules` — blocked sites + active country presets go through proxy; everything else direct
  - `global` — everything through proxy
- Two proxy modes:
  - `system` — sets system SOCKS5 proxy via `gsettings` / KDE config
  - `tun` — creates a TUN device, intercepts all traffic (needs polkit/root)
- Hot-reload of sing-box rules when a preset or custom rule changes — no
  reconnect needed

## Requirements

System:
- `sing-box` ≥ 1.10 (in `$PATH`)
- `python3` ≥ 3.12
- DBus session bus
- `nft` (only if you want the kill switch)
- `openssh` (only for SSH servers)

Python (installed via the backend `.venv`):
- `dbus-next` ≥ 0.2.3
- `pydantic` ≥ 2.0
- `aiofiles` ≥ 23.0
- `aiohttp` ≥ 3.9
- `aiohttp-socks` (for the speed test to measure through the proxy)

## Installation

### 1. Install the plugin

```bash
cd ~/.config/noctalia/plugins
git clone https://github.com/noctalia-dev/noctalia-plugins.git tmp-plugins
cp -r tmp-plugins/noctalia-vpn .
rm -rf tmp-plugins
```

Or copy this directory directly into `~/.config/noctalia/plugins/noctalia-vpn`.

### 2. Install the backend

The backend lives in a separate repo so it can be updated independently:

```bash
git clone https://github.com/<your-account>/noctalia-vpn-plugin.git ~/dev/noctalia-vpn-plugin
cd ~/dev/noctalia-vpn-plugin
python3 -m venv .venv
.venv/bin/pip install -e .
.venv/bin/pip install aiohttp-socks
```

`Main.qml` looks for the backend at `~/dev/noctalia-vpn-plugin/.venv/bin/python3`.
Change `venvPython` in `Main.qml` if you put it somewhere else.

### 3. Start the backend

Manual start:

```bash
cd ~/dev/noctalia-vpn-plugin
nohup .venv/bin/python3 -m backend.app >> /tmp/noctalia-vpn-backend.log 2>&1 &
disown
```

Auto-start on login (recommended): copy the included unit file:

```bash
mkdir -p ~/.config/systemd/user
cp noctalia-vpn-backend.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now noctalia-vpn-backend.service
```

The bridge (`dbus-bridge.py`) will also spawn the backend itself if the DBus
name isn't yet owned when the plugin loads — the systemd unit is just there to
get an early start before the bar comes up.

## Ports

The backend listens on:

- `11080` — transport SOCKS5 (talks to the remote VPN server)
- `11081` — rules-mode mux (route-aware SOCKS5/HTTP)
- `11082` — global-mode mux (everything → proxy)
- `11089` — clash API (used internally for hot-reload)

Don't put anything else on those ports.

## Configuration files

Persisted under `~/.config/noctalia-vpn/`:

- `servers.json` — saved server entries
- `rules.json` — user routing rules
- `settings.json` — active server, mode, ports, active presets, UI toggles
- `subscriptions.json` — subscription URLs

Generated sing-box configs go to `~/.config/sing-box/noctalia-vpn-*.json`.

## License

MIT
