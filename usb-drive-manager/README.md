# USB Drive Manager

A Noctalia bar widget for managing USB drives and removable storage devices.

## Features

- **Auto-detection** – Monitors udev events in real-time; the bar icon updates instantly when a USB drive is plugged in or removed
- **Mount / Unmount** – Mount and unmount partitions via `udisksctl`
- **Safe Eject** – Unmounts all mounted volumes on the removable device, then powers off the parent disk (`udisksctl power-off`) to prevent data loss
- **File Browser** – Open any mounted drive directly in your configured file manager
- **Copy Path** – Copy the mountpoint path to the clipboard
- **Storage Usage** – Visual progress bar showing used/free space per device
- **Device Info** – Shows volume label, filesystem type, size, vendor/model
- **Bulk Actions** – "Unmount All" and "Eject All" buttons in the panel
- **Auto-Mount** – Optional: automatically mount newly detected drives when plugged in
- **Notifications** – Toast notifications for all mount/unmount/eject events
- **i18n** – English and German translations included

## System Requirements

| Tool | Package (Gentoo) | Purpose |
|---|---|---|
| `udisksctl` | `sys-fs/udisks` | Mount, unmount, power-off |
| `udevadm` | `sys-fs/eudev` or `sys-apps/systemd-utils` | Real-time device monitoring |
| `lsblk` | `sys-apps/util-linux` | Device enumeration |
| `df` | `sys-apps/coreutils` | Disk usage statistics |
| `wl-copy` | `gui-apps/wl-clipboard` | Copy path to clipboard (optional) |

## Settings

| Setting | Default | Description |
|---|---|---|
| Auto-mount | `false` | Automatically mount drives when plugged in |
| File browser | `yazi` | Command to open the file manager (e.g. yazi, ranger, xdg-open, dolphin, thunar, nautilus) |
| Notifications | `true` | Show toast notifications |
| Hide when empty | `false` | Hide bar icon when no devices connected |
| Bar icon | `usb` | Icon name used for the bar widget |
| Icon color | `none` | Custom icon color |

## Usage

1. **Left-click** the bar icon to open the device panel
2. **Right-click** for quick actions (Refresh, Unmount All, Settings)
3. In the panel, each device card shows:
   - Device label, size, filesystem type
   - Mountpoint path (when mounted)
   - Storage usage bar
   - Action buttons: Open / Mount / Unmount / Eject / Copy Path

## IPC

```bash
# Refresh device list from a running Noctalia session
qs -c noctalia-shell ipc call plugin:usb-drive-manager refresh

# Unmount all devices
qs -c noctalia-shell ipc call plugin:usb-drive-manager unmountAll
```

## Notes

- Only USB and removable devices are shown (filtered via `lsblk` TRAN/RM fields)
- The "Eject" action unmounts all mounted volumes on the selected removable device before powering off the parent disk
- Auto-mount only targets newly detected, currently unmounted volumes so manual unmount/eject actions are not immediately reversed
- Disk usage is updated ~1 second after device enumeration
- udevadm events are debounced (800ms) to avoid rapid re-queries during partition table reads

## Tested & Limitations

### Tested filesystems

- `ext4`
- `btrfs`
- `vfat` / `fat32`
- `ntfs` via kernel `ntfs3` driver

For NTFS volumes:

- A working NTFS implementation is required (e.g. `CONFIG_NTFS3_FS` in the kernel, optionally `ntfs3g`).
- Volumes must be **cleanly unmounted** by Windows. If the NTFS volume is marked dirty or hibernated (Fast Startup / Sleep), `ntfs3` refuses to mount it and `udisksctl` will fail with a "wrong fs type / volume is dirty" error. The plugin intentionally does **not** force-mount such volumes; run `chkdsk` on Windows and disable Fast Startup instead.

### Not implemented (yet)

- No built-in LUKS / encrypted volume unlock flow (encrypted devices that are unlocked externally and show up in `lsblk` behave like normal mounted devices).
- No special handling for network filesystems or non-UDisks-managed devices.
