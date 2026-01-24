# Overlay Widgets

A plugin that provides an overlay system for placing and pinning widgets on your screen. Similar to a game bar, you can drag widgets from a library and pin them to stay on top of all applications.

## Features

- **Overlay Interface**: Open a full-screen overlay via IPC command to manage widgets
- **Widget Library**: Browse and drag available widgets (Clock, CPU Monitor, Memory Monitor, Network Stats, System Info)
- **Drag & Drop**: Intuitive drag and drop interface for placing widgets
- **Pinning System**: Pin widgets to create floating windows that stay on top of all applications
- **Persistent Widgets**: Pinned widgets are saved and restored on restart
- **Always On Top**: Pinned widgets remain visible above all other windows
- **Customizable**: Move and position widgets anywhere on your screen

## Usage

### Opening the Overlay

Use the IPC command to toggle the overlay:

```bash
qs -c noctalia-shell ipc call plugin:overlay-widgets toggle
```

### Adding Widgets

1. Open the overlay using the IPC command
2. Browse the widget library on the left side
3. Drag a widget from the library to the placement area on the right
4. Position the widget where you want it
5. Click the pin button to pin the widget (creates a floating window)
6. Close the overlay - pinned widgets remain visible

### Managing Pinned Widgets

- **Move**: Click and drag the header of a pinned widget to move it
- **Unpin**: Click the X button in the header to remove the widget
- Pinned widgets persist across restarts

## Available Widgets

- **Clock**: Displays current time and date
- **CPU Monitor**: Shows CPU usage with a progress bar
- **Memory Monitor**: Displays memory usage and statistics
- **Network Stats**: Shows network download/upload speeds
- **System Info**: Displays system information (hostname, kernel, CPU, memory)

## IPC Commands

### Toggle Overlay

```bash
qs -c noctalia-shell ipc call plugin:overlay-widgets toggle
```

Opens or closes the overlay interface.

### Integration with Keybindings

Add this to your window manager or keybinding configuration:

```bash
# Example for Hyprland
bind = SUPER, G, exec, qs -c noctalia-shell ipc call plugin:overlay-widgets toggle
```

## Technical Details

- **Widget Storage**: Pinned widgets are stored in plugin settings as JSON
- **Window Management**: Uses Qt Quick Window with `Qt.WindowStaysOnTopHint` flag
- **Component Loading**: Widgets are loaded dynamically from the `widgets/` directory
- **Registry System**: Widget definitions are managed in `WidgetRegistry.js`

## Requirements

- **Noctalia 4.0.0 or later**
- Qt Quick Window support
- System statistics service (for CPU, Memory, Network widgets)

## Widget Development

To add custom widgets:

1. Create a new QML file in the `widgets/` directory
2. Add the widget definition to `WidgetRegistry.js`:
   ```javascript
   {
       id: "my-widget",
       name: "My Widget",
       component: "widgets/MyWidget.qml",
       icon: "icon-name",
       defaultWidth: 200,
       defaultHeight: 100,
       description: "Widget description"
   }
   ```
3. The widget component should accept a `pluginApi` property for accessing plugin services

## Notes

- Pinned widgets are independent floating windows
- Widget positions are saved automatically when moved
- The overlay can be closed by clicking outside the main content area or using the close button
- Widgets use the Noctalia design system (colors, styles, etc.)
