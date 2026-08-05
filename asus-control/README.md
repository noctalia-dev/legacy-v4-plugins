# ASUS Control

A comprehensive Noctalia Shell plugin for managing ASUS laptops via [asusctl](https://asus-linux.org/wiki/). Provides a bar widget and a full-featured control panel with tabs for power profiles, keyboard LED, battery charge limit, fan curves, and aura lighting zones.

## Features

### Power Profiles
Switch between your laptop's performance modes directly from the bar or panel. The plugin auto-detects available profiles from your system (e.g. Quiet, Balanced, Performance) and shows separate AC and Battery profile assignments.

### Keyboard LED Brightness
Cycle through brightness levels — Off, Low, Medium, High — with a single click. No need to remember `asusctl leds` commands.

### Battery Charge Limit
Set a charge threshold (20–100%) using a slider to extend battery lifespan. Includes a one-shot charge button that temporarily charges to 100% once — useful before unplugging for a long session.

### Fan Curves
View and toggle per-fan (CPU, GPU) fan curves for the active profile. Displays the current temperature-to-PWM mapping as data point chips. Reset curves to factory defaults with one click.

### Aura Lighting Zones
Dynamically detects which aura zones your laptop supports (keyboard, logo, lightbar, lid, rear-glow, ally) and lets you toggle power states (awake, sleep, boot, shutdown) per zone. Also supports setting static colors and cycling through effect modes.

### Noctalia Integration
- **Power Profile Sync** (enabled by default) — automatically syncs ASUS power profiles with Noctalia Shell's power profiles in both directions (e.g. switching to "Performance" in Noctalia also sets the ASUS profile).
- **Keyboard Color Sync** — automatically applies a chosen Noctalia theme color (Primary, Secondary, or Tertiary) to the keyboard aura after theme transitions. When enabled, the manual color picker is disabled.

## Dynamic Detection

The plugin does not hardcode any laptop-specific values. Everything is detected at runtime:

| Feature | Detection method |
|---|---|
| Power profiles | `asusctl profile list` — reads available profile names |
| Fan types | `asusctl fan-curve --get-enabled` — parses `CPU: ...`, `GPU: ...` lines |
| Fan curve data | `asusctl fan-curve --mod-profile <name>` — parses `pwm: (...)` / `temp: (...)` |
| Aura zones | Probes `asusctl aura power <zone> --help` for each known zone |
| LED brightness | `asusctl leds get` — parses current level |
| Battery limit | `asusctl battery info` — parses charge limit percentage |
| Device info | `asusctl info` — reads version, product family, board name |

## Requirements

- `asusctl` installed and available in `$PATH`
- An ASUS laptop with supported hardware (ROG, TUF, ZenBook, Vivobook, etc.)

## Installation

Copy the `asus-control` folder to your Noctalia plugins directory:

```bash
cp -r asus-control ~/.config/noctalia/plugins/
```

Then reload Noctalia Shell or enable the plugin from Settings > Plugins.

## Usage

- **Bar widget** shows the current power profile icon and name, plus a battery icon when charge limit is active.
- **Left-click** the bar widget to open the control panel.
- **Right-click** for a context menu with Settings and Refresh.
- **Panel** has 4 tabs: Profile, LED (with aura controls), Battery, Fan.
- **Settings** page allows configuring icon color, polling interval, power profile sync, and keyboard color sync.

## IPC Commands

Control the plugin via `qs ipc`:

```bash
# Toggle the panel
qs ipc call asus-control toggle

# Set power profile
qs ipc call asus-control setProfile Performance

# Set LED brightness
qs ipc call asus-control setLedBrightness high

# Set battery charge limit
qs ipc call asus-control setBatteryLimit 80

# Refresh all status
qs ipc call asus-control refresh
```

## Compatibility

Uses only standard Noctalia Shell Plugin API and `Quickshell.Io` for process execution. Works on any supported compositor — Niri, Hyprland, Sway, Labwc, MangoWC.

## License

MIT
