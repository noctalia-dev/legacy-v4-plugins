# noctalia-calculator

A theme-aware calculator plugin for Noctalia on Niri, with a bar widget, floating panel, keyboard support, and a clean UI that follows the active shell colors.

## Features

- Basic operations: `+`, `-`, `*`, `/`, `%`, sign toggle, clear, and delete
- Mouse and keyboard input
- Optional live value in the bar
- Theme-aware colors and spacing
- English and Portuguese translations

## Requirements

- Noctalia / Quickshell
- `bash`
- `python3`
- `git` for `update.sh`

## Install

Clone the repository anywhere you want and run:

```bash
./install.sh
```

The installer will:

- link the plugin into `~/.config/noctalia/plugins/noctalia-calculator`
- enable the plugin in `~/.config/noctalia/plugins.json`
- add `plugin:noctalia-calculator` to the right side of the bar in `~/.config/noctalia/settings.json`
- add a `Mod+Shift+C` bind in `~/.config/niri/cfg/keybinds.kdl` when that file exists and the shortcut is free

After that, restart Noctalia / Quickshell if it is not reloaded automatically.

## Update

```bash
./update.sh
```

This pulls the latest git changes and reapplies the installation.

## Remove

```bash
./remove.sh
```

This removes the plugin from Noctalia settings and unlinks it from the local plugin directory. The repository checkout itself is kept in place.

## Usage

- Left click the bar widget to open the calculator
- Right click the bar widget for the context menu
- `Mod+Shift+C` toggles the panel from Niri and opens it next to the calculator icon when the bar widget is available
- Keyboard:
  - `0-9` for digits
  - `+ - * /` for operators
  - `.` or `,` for decimal input
  - `Enter` for equals
  - `Backspace` for delete
  - `Esc` or `Delete` for clear
  - `F9` for sign toggle

## Files

- `Main.qml`: calculator logic and translations
- `BarWidget.qml`: bar widget entry point
- `Panel.qml`: floating calculator panel
- `Settings.qml`: plugin settings UI
- `install.sh`: install and register the plugin
- `update.sh`: update from git and reinstall
- `remove.sh`: unregister and unlink the plugin

## Author

Pir0c0pter0  
`pir0c0pter0000@gmail.com`
