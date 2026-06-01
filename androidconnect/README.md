# AndroidConnect

`AndroidConnect` is a Noctalia plugin for Android device status, quick actions, file transfer, and embedded `scrcpy` control directly inside the panel.

This project is built on top of the original Noctalia `kde-connect` plugin. Credit and thanks to the original Noctalia KDE Connect plugin developers for the base plugin and architecture this work extends.

Upstream base project:
- https://github.com/WerWolv/noctalia-kde-connect

Project repository:
- https://github.com/demencia89/noctalia-shell-androidconnect-plugin

## Screenshots

### Plugin Preview

![AndroidConnect plugin preview](preview.png)

### Panel Overview

![AndroidConnect panel overview](Docs/Screenshots/androidconnect-panel-overview.png)

### Lock Screen View

![AndroidConnect lock screen view](Docs/Screenshots/androidconnect-lock-screen.png)

### Panel Close-up

![AndroidConnect panel close-up](Docs/Screenshots/androidconnect-panel-closeup.png)

## Current Status

Current plugin version: `1.6.0`

See `CHANGELOG.md` for release notes.

The embedded mirror uses a single live feed path:

- `scrcpy` writes into `v4l2loopback`
- Qt Multimedia reads that loopback device inside the panel
- There is no second mirror backend in the normal path

Current behavior:
- Embedded mirror launches automatically when the panel is ready, typically within about one second of `scrcpy` starting
- The embedded mirror is tied to the selected KDE Connect device and will not reuse another phone's ADB session
- Audio can be toggled from the panel header
- Android nav buttons stay visible below the phone preview
- The decorative phone home indicator is hidden while the live `scrcpy` feed is connected
- Screenshot and screen recording actions are available from the right-side utility row
- Keep-screen-awake is available from the utility row while the panel is open
- Status and error messages stay hidden during the initial grace period, then appear only if the feed or input path is still not ready
- Opening the panel while `scrcpy` is already connected sends unlock-only, not Home
- Embedded mirror launch probes Android display geometry, chooses a full-frame size for the phone's aspect ratio, and avoids cropping unless a fallback path is needed
- The V4L2 loopback format is checked against the expected `scrcpy` output before the feed is locked for Qt Multimedia
- Header brand badges use logo assets where available, including Google, Xiaomi-family, and Motorola-family names, and fall back to icons otherwise
- First-run cold-start reliability is fixed in `1.4.0`: the root cause was `v4l2loopback` advertising the scrcpy device as `V4L2_CAP_VIDEO_OUTPUT` at process start when created with `exclusive_caps=1`, which caused Qt Multimedia to filter it out and never re-enumerate. Using `exclusive_caps=0` on the scrcpy loopback resolves it

## Features

- KDE Connect device list, state, battery, signal, and notification summary
- Wake device, browse files, send files, and ring phone from the panel
- Embedded in-panel Android mirror
- Live V4L2 feed for the embedded mirror
- Display-size probing for broader phone aspect-ratio compatibility
- Optional embedded audio toggle, off by default
- ADB tap, swipe, text, key, and Android navigation input
- In-panel utility actions for screenshot, screen recording, and keep-screen-awake
- Wireless ADB pairing and reconnect helpers
- Wireless ADB auto-detect for the selected phone's current random connect port when mDNS is available
- Existing plugin toasts are mirrored into notification history
- Screenshot and screen recording save notifications include a link to the output folder

## Dependencies

Required for the base plugin:
- Noctalia `>= 4.4.0`
- KDE Connect desktop app and a running `kdeconnectd`
- `busctl` from `systemd`

Required for mirror and Android input features:
- `scrcpy`
- `adb` from Android platform-tools
- Qt Multimedia runtime for your distro, for example `qt6-multimedia`

Required for the embedded live feed:
- `v4l2loopback`
- A loopback device such as `/dev/video10`
- A loopback label visible to Qt Multimedia, for example `scrcpy-panel`

Required for some optional features:
- `qrencode` for Wireless ADB QR pairing
- `sshfs` and FUSE support for the Browse Files action

Recommended:
- `avahi-browse` for more reliable Wireless ADB service discovery

Not versioned in this repository:
- `settings.json` is local user state and should stay untracked

## Install

1. Copy this plugin directory into your Noctalia plugins directory.
   Example: `~/.config/noctalia/plugins/androidconnect`
2. Reload Noctalia or restart the shell so it picks up the plugin.
3. Enable the plugin in Noctalia.
4. Make sure KDE Connect is installed on both the desktop and phone, then pair the phone normally.

## First-Time Setup

If you want the default experience, which is embedded `scrcpy` inside the panel:

1. Install `scrcpy`, `adb`, Qt Multimedia, and `v4l2loopback`.
2. On the phone, enable Developer options and USB debugging.
3. Connect the phone over USB once, unlock it, and accept the USB debugging prompt for this computer.
4. Create the V4L2 loopback device used by the embedded feed.
5. Open the panel.

If ADB or the loopback feed is not ready, the plugin stays in a setup or error state and tells you what is missing instead of launching a broken mirror session.

## Base Setup

If you only want device status and KDE Connect actions:

1. Confirm `kdeconnectd` is running.
2. Enable the relevant KDE Connect phone-side plugins for battery, notifications, browse files, and remote actions.

## Embedded Mirror Setup

If you want the phone rendered inside the panel:

1. Create a V4L2 loopback device with **`exclusive_caps=0`**. This is required — see the note below.
   Example for a one-shot modprobe:

```bash
sudo modprobe -r v4l2loopback 2>/dev/null || true
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label=scrcpy-panel exclusive_caps=0 max_width=960 max_height=2160
```

To make it persist across reboots, add a config under `/etc/modprobe.d/`, for example `/etc/modprobe.d/v4l2loopback.conf`:

```text
options v4l2loopback video_nr=10 card_label="scrcpy-panel" exclusive_caps=0
```

If you already have other loopback devices (for example OBS's virtual camera), combine them into a single `options` line with comma-separated values per device, and make sure every entry in the `exclusive_caps` list is `0`:

```text
options v4l2loopback video_nr=0,10 card_label="OBS Virtual Camera,scrcpy-panel" exclusive_caps=0,0
```

After editing the config, reload the module:

```bash
sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback
```

2. Confirm `/dev/video10` exists and `scrcpy-panel` is visible to Qt Multimedia.
3. Open the panel and wait for the embedded mirror to start. It should appear roughly one second after `scrcpy` launches.
4. Use the speaker button in the header if you want embedded audio.

### Why `exclusive_caps=0` is required

With `exclusive_caps=1`, a `v4l2loopback` device advertises `V4L2_CAP_VIDEO_OUTPUT` when no consumer is attached and only flips to `V4L2_CAP_VIDEO_CAPTURE` once `scrcpy` starts writing. Qt Multimedia enumerates video-capture devices once at process startup and caches the result. If the panel opens before `scrcpy` writes, Qt sees the loopback as an output-only device, filters it out, and never re-enumerates it — the embedded mirror then stays black for the lifetime of the shell and no amount of panel reloading recovers it.

With `exclusive_caps=0`, the loopback advertises both `CAPTURE` and `OUTPUT` unconditionally, so Qt enumerates it correctly at startup regardless of whether `scrcpy` has started yet. This is the only supported configuration.

Notes:
- If the phone is already mirrored when you open the plugin, AndroidConnect sends unlock-only and does not send Home.

## Panel Controls

### Header Actions

- Device switcher when more than one phone is available
- Phone size toggle, shown when hovering the brand badge
- Embedded audio toggle
- Wireless ADB tools
- Browse files
- Send file
- Find phone

### Mirror Navigation Row

- `Back`
- `Home`
- `Recents`

Mouse and keyboard shortcuts:
- Right click on the phone view sends `Back`
- Middle click on the phone view sends `Recents`
- `Home` key sends `Home`
- Arrow keys, Enter, Tab, Escape, Delete, and Backspace are forwarded to Android when the phone view is focused
- Text typed into the focused phone view is sent to Android input

### Utility Actions

These appear in the utility action row under battery, network, and signal:

- `Take Screenshot`
- `Start / Stop Recording`
- `Keep Screen Awake`

Saved media locations:
- Screenshots: `~/Pictures/AndroidConnect`
- Screen recordings: `~/Videos/AndroidConnect`

When a screenshot or recording finishes, AndroidConnect adds the same event to notification history and includes a link to open the output folder.

## Wireless ADB Setup

Wireless ADB is optional, but it improves embedded input when USB is not available.

1. Open Android's `Wireless debugging` screen.
2. Use either:
   - `Pair with QR code`
   - `Pair with code`
3. Open the Wi-Fi button in the panel header.
4. After pairing, either:
   - click `Auto-detect` to discover the selected phone's current Wireless ADB connect port over mDNS
   - manually enter the ADB port shown on the phone and click `Connect`

The plugin stores Wireless ADB state per KDE Connect device. Android may rotate the Wireless debugging connect port whenever Wireless debugging reconnects, so saved ports are treated as history only. A saved `host:port` is used for mirroring only after `adb devices` reports that exact serial as connected.

Notes:
- Wireless ADB is optional. USB ADB is still the simplest and most reliable first setup path.
- `avahi-browse` is recommended for auto-detect. Some `adb mdns services` builds do not expose mDNS discovery reliably.

## Browse Files Notes

The Browse Files action depends on KDE Connect's SFTP support.

If it fails:
- Check that the KDE Connect SFTP feature is enabled on the phone.
- Make sure `sshfs` and FUSE support are installed.
- If your file manager is sandboxed, it may not be able to access the mounted path.

## Troubleshooting

## Known Issues

- No persistent embedded mirror corruption issue is currently tracked. If the mirror starts black, check the loopback setup below first.

### Black Screen In The Embedded Mirror

Most black-screen reports trace back to a `v4l2loopback` configuration issue. Check the following first:

- `scrcpy`, `adb`, and Qt Multimedia are installed
- `/dev/video10` exists
- The loopback label is visible as `scrcpy-panel`
- **`v4l2loopback` was created with `exclusive_caps=0`** — see the "Embedded Mirror Setup" section for why this matters and how to fix it

Quick diagnostic commands:

```bash
# Confirm the scrcpy-panel device is present and Qt-visible
v4l2-ctl --list-devices
cat /sys/module/v4l2loopback/parameters/exclusive_caps   # every entry should be "N"

# Inspect the current format on the scrcpy loopback
v4l2-ctl --device=/dev/video10 --all
```

If any `exclusive_caps` entry is `Y`, follow the "Embedded Mirror Setup" steps to recreate the loopback devices with `exclusive_caps=0`.

AndroidConnect also writes mirror diagnostics to:

```text
/tmp/androidconnect-preview-debug.log
```

The log starts with a banner showing the current `v4l2-ctl --list-devices` output and the module's `exclusive_caps` parameter, which is usually enough to diagnose loopback problems at a glance.

## Development Notes

- This repository is intended to host the plugin in a downloadable state for other users.
- Local machine state should not be committed.
- The plugin still uses KDE Connect as its transport and device integration backend. `AndroidConnect` is a renamed and extended plugin package built on top of that foundation.
