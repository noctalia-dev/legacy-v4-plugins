# 2-in-1-tools

`2-in-1-tools` is a Noctalia plugin focused on practical features for convertible and detachable laptops. It is intended for devices that regularly switch between laptop, tent, stand, and tablet-style use.

The goal of this plugin is to collect small but useful tools that improve the 2-in-1 experience in Noctalia. The current release is intentionally small, and the plugin will expand over time with additional features that support touchscreen-first and tablet-style workflows.

## Current features

- Bar widget for quick display rotation
- Control Center shortcut for display rotation
- Rotation state refresh and settings access from the bar widget menu
- Per-plugin settings for icon and tooltip behavior
- Optional tablet-mode auto-rotate for the internal display
- Optional sensor auto-rotate outside tablet mode
- Configurable primary button behavior for auto-rotate lock or manual rotation
- Hyprland touchscreen transform sync after display rotation

## Current behavior

Manual rotation targets the active Noctalia screen/output and cycles through:

`normal -> 90 -> 180 -> 270 -> normal`

It uses compositor IPC:

```bash
# Niri
niri msg output <OUTPUT> transform <TRANSFORM>

# Hyprland
hyprctl keyword monitor "<OUTPUT>,<MODE>,<POSITION>,<SCALE>,transform,<ID>"

# Hyprland touch sync (per touchscreen device)
hyprctl keyword "device[<TOUCHSCREEN_NAME>]:transform" <ID>
```

On Hyprland, the plugin can automatically apply a matching touchscreen transform when rotating a display.
This behavior is enabled by default and can be changed in plugin settings (`Hyprland: sync touchscreen transform`).

## Planned direction

This plugin is meant to grow into a general utility set for 2-in-1 laptops. Future additions may include features that make orientation changes, touch interaction, and tablet-mode workflows easier to manage inside Noctalia.

## Recommended companion plugin

Use this plugin together with the `osk-toggle` plugin. On 2-in-1 hardware, display rotation and on-screen keyboard access often go together, especially when the physical keyboard is folded away or inconvenient to use.

Recommended setup:

- `2-in-1-tools` for quick rotation controls
- `osk-toggle` for fast on-screen keyboard access

## Tablet mode automation setup

Tablet-mode automation uses `/tmp/noctalia-tablet-mode` and depends on your compositor config writing `on`/`off`.
On Niri, the plugin watches this file for changes (event-driven via `inotifywait`) and also keeps low-frequency polling as a fallback.

### Niri setup

Add or adapt the following block in your Niri config:

```kdl
switch-events {
    tablet-mode-on { spawn "bash" "-c" "printf on > /tmp/noctalia-tablet-mode && gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true"; }
    tablet-mode-off { spawn "bash" "-c" "printf off > /tmp/noctalia-tablet-mode && gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false"; }
}
```

This does two things:

- writes the current tablet-mode state to `/tmp/noctalia-tablet-mode` so `2-in-1-tools` can react to it,
- keeps the GNOME on-screen keyboard setting in sync, which is useful if you also use an OSK plugin.

After editing the config, reload Niri:

```bash
niri msg action load-config-file
```

### Hyprland setup

`2-in-1-tools` listens to Hyprland's event socket (`.socket2.sock`) for `switch` events when Hyprland emits them. It also watches `/tmp/noctalia-tablet-mode` with `inotifywait`, which is the most reliable event path on hardware that exposes `Intel HID switches` without readable state. A short fallback poll remains for missed events or missing `inotifywait`.

Use Hyprland binds/switch handlers to keep the state file updated:

```ini
# Example pattern, adapt to your hardware event flow
bindl = ,switch:on:Lid Switch,exec,sh -c 'printf on > /tmp/noctalia-tablet-mode'
bindl = ,switch:off:Lid Switch,exec,sh -c 'printf off > /tmp/noctalia-tablet-mode'
```

Direct Hyprland detection expects a switch name containing `tablet`.

Then open the plugin settings in Noctalia and enable:

- `Auto-switch bar density in tablet mode`
- `Use exclusive dock in tablet mode`
- `Auto-rotate screen in tablet mode`
- `Allow auto-rotate outside tablet mode` if you want sensor rotation even while tablet mode is off
- `Bar and Control Center button behavior`
- `Flip vertical sensor orientation` if your laptop reports `left-up` and `right-up` reversed
- `Tablet mode bar density`

The plugin will save your normal bar density, switch to the configured tablet density when tablet mode is detected, and restore the previous density when tablet mode ends.
If `Use exclusive dock in tablet mode` is enabled, the plugin will also save the current dock state, enable the dock if it was off, switch it to exclusive mode during tablet mode, and restore the previous dock settings afterward.

If auto-rotate is enabled, the plugin starts `monitor-sensor --accel` while tablet mode is `on`, maps the reported orientation to output transforms, and restores the previous transform when tablet mode ends. If `Allow auto-rotate outside tablet mode` is enabled, the same sensor rotation is available even while tablet mode is `off`. Auto-rotate only targets the internal panel:

- outputs starting with `eDP`, `LVDS`, or `DSI`,
- or the only connected output if there is exactly one.

Orientation mapping:

- `normal` -> `normal`
- `bottom-up` -> `180`
- `left-up` -> `90`
- `right-up` -> `270`

If your hardware reports the portrait directions inverted, enable `Flip vertical sensor orientation` to swap only `left-up` and `right-up`.

If no eligible internal output is found, auto-rotate stays inactive without affecting manual rotation.
The first sensor read may briefly wait for `iio-sensor-proxy` to appear; that is expected as the service activates on demand.

The main bar and Control Center button can be configured in two modes:

- `Toggle auto-rotate / lock rotation` (default): while tablet-mode auto-rotate is active, clicking the button locks the current orientation or re-enables auto-rotate.
- `Rotate manually`: clicking the button cycles the current output transform directly.

When the button is set to `Toggle auto-rotate / lock rotation`, it is hidden outside tablet mode unless `Allow auto-rotate outside tablet mode` is enabled. When tablet-mode auto-rotate ends, the display is restored to `normal`.

Manual rotation remains available through the bar widget context menu either way.

## Requirements

- Noctalia
- Niri or Hyprland
- `monitor-sensor` from `iio-sensor-proxy` for auto-rotate

## Notes

- Rotation is applied at runtime through the active compositor and is not a permanent display configuration.
- If output configuration is later reloaded from disk, the temporary transform may be lost.
- Tablet-mode gating comes from the `/tmp/noctalia-tablet-mode` state file.

## Backend detection

The plugin auto-detects the compositor backend in this order:

- `HYPRLAND_INSTANCE_SIGNATURE` -> Hyprland
- `NIRI_SOCKET` -> Niri
- `XDG_CURRENT_DESKTOP` substring fallback (`hypr` or `niri`)

If neither backend is detected, rotation controls stay disabled.
