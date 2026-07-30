# Clamshell Mode Plugin for Noctalia Shell

Automatically inhibits lid-switch suspend when an external monitor is connected.
When the lid is closed with an external display active, niri turns off the
internal screen while the system stays awake.

## Requirements

- Noctalia Shell 3.6.0 or newer
- niri 0.1.9 or newer
- systemd with `systemd-inhibit`
- Quickshell through `noctalia-qs`

## Installation

Place this directory at:

```sh
~/.config/noctalia/plugins/clamshell/
```

Register and enable the plugin in Noctalia, then add the bar widget or control
center widget from Noctalia settings.

## IPC

```sh
qs -c noctalia-shell ipc call plugin:clamshell status
qs -c noctalia-shell ipc call plugin:clamshell toggle
qs -c noctalia-shell ipc call plugin:clamshell enable
qs -c noctalia-shell ipc call plugin:clamshell disable
qs -c noctalia-shell ipc call plugin:clamshell refresh
```

`status` returns JSON with `enabled`, `externalPresent`, `inhibitorActive`, the
inhibitor PID, and the detected outputs.

## niri Keybinding

Add a binding like this to `~/.config/niri/config.kdl`:

```kdl
binds {
    Mod+Shift+L { spawn "sh" "-c" "qs -c noctalia-shell ipc call plugin:clamshell toggle"; }
}
```

## logind.conf

Leave `/etc/systemd/logind.conf` at the normal lid-switch behavior, typically
`HandleLidSwitch=suspend`. This plugin does not edit system configuration; it
uses `systemd-inhibit --mode=block` only while clamshell mode is active.

## Known Limitation

If the lid is already closed when the last external monitor is disconnected,
logind will not receive another lid-close event until the lid is opened and
closed again.
