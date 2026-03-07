# Special Workspaces (Hyprland)

A simple widget that shows Hyprland special workspaces.

### Requirements

* Hyprland
* Noctalia (duh.)

## Features

- The widget appears as a single dimmed button while any special workspace isn't active. It restores its opacity when a special workspace is active, focused or not.
- It expands and shows special workspaces when a special workspace is focused.
- Inactive special workspaces are shown dimmed.
- Fully customizable. Options are still WIP, they'll contain these:
 * Expanding direction (top/down for vertical, left/right for horizontal)
 * Pill toggle
 * Symbol color (Primary/Secondary)
 * Symbol size (Primary/Secondary)
 * Pill color (Primary/Secondary)
 * Pill size (Primary/Secondary)
 * Add/remove special workspaces
 * Assign different symbols to special workspaces
 
**The widget doesn't actually add/remove special workspaces to Hyprland. The add/remove function only changes if a special workspace has a button on the widget or not. The widget expands even if a special workspace isn't added to it but is focused. I recommend adding all of the special workspaces defined in Hyprland config to the widget to avoid any confusion.**
 
*Primary button: The main that's shown at the bar at all times.*
*Secondary button: The special workspace buttons shown when the widget is expanded.*

### Usage

The widget expands when a special workspace is focused. The buttons also function as special workspace focus toggles.
