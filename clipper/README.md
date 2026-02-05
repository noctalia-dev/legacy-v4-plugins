# Clipper

Advanced clipboard manager plugin for Noctalia Shell with history, search, filtering, full keyboard navigation, and ToDo integration.

![Preview](Assets/preview.png)

## Features

### Clipboard Management
- **Clipboard History** - Stores and displays clipboard history using cliphist backend
- **Content Type Detection** - Automatically detects and categorizes content as Text, Image, Color, Link, Code, Emoji, or File
- **Image Preview** - Displays image thumbnails directly in cards
- **Color Preview** - Shows color swatches for hex/rgb color codes
- **Incognito Mode** - Temporarily disable clipboard tracking

### User Interface
- **Card-based Layout** - Each clipboard entry displayed as a styled card
- **Type-specific Coloring** - Different accent colors for each content type
- **Filter Buttons** - Quick filter by content type (All, Text, Image, Color, Link, Code, Emoji, File)
- **Search** - Full-text search through clipboard history
- **Selection Highlight** - Visual indication of currently selected card
- **Add to ToDo Button** - Quick add text content to ToDo plugin (Text, Link, Code types)

### Keyboard Navigation
| Key | Action |
|-----|--------|
| `←` / `→` | Navigate between cards |
| `↑` | Focus search input |
| `↓` | Focus cards (from search) |
| `Enter` | Copy selected item and close panel |
| `Delete` | Delete selected item |
| `Tab` | Cycle to next filter |
| `Shift+Tab` | Cycle to previous filter |
| `0-7` | Direct filter selection (0=All, 1=Text, 2=Image, etc.) |
| `Escape` | Close panel |

### ToDo Integration

Clipper can integrate with the ToDo plugin to quickly add selected text to your todo lists.

#### Setup
1. Enable "ToDo Integration" in Clipper settings (Features tab)
2. Configure keybinds in your window manager to call the IPC commands

#### IPC Commands for ToDo
```bash
# Add selected text to ToDo page 1 (pageId 0)
qs -c noctalia-shell ipc call plugin:clipper addToTodo1

# Add selected text to ToDo page 2 (pageId 1)
qs -c noctalia-shell ipc call plugin:clipper addToTodo2

# ... through addToTodo9 for pages 1-9

# Add selected text to specific page (0-indexed)
qs -c noctalia-shell ipc call plugin:clipper addToTodo 0

# Add specific text to ToDo (used internally by card button)
qs -c noctalia-shell ipc call plugin:clipper addTextToTodo "my task" 0
```

#### How it works
1. Select text anywhere (primary selection)
2. Trigger keybind (e.g., `Super+Ctrl+Shift+1` for page 1)
3. Selected text is added to the specified ToDo page
4. Text is also copied to clipboard

#### Keybind Examples

**Hyprland** (`~/.config/hypr/hyprland.conf`):
```ini
bind = $mainMod CTRL SHIFT, 1, exec, qs -c noctalia-shell ipc call plugin:clipper addToTodo1
bind = $mainMod CTRL SHIFT, 2, exec, qs -c noctalia-shell ipc call plugin:clipper addToTodo2
bind = $mainMod CTRL SHIFT, 3, exec, qs -c noctalia-shell ipc call plugin:clipper addToTodo3
```

**Niri** (`~/.config/niri/config.kdl`):
```kdl
binds {
    Mod+Ctrl+Shift+1 { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:clipper" "addToTodo1"; }
    Mod+Ctrl+Shift+2 { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:clipper" "addToTodo2"; }
    Mod+Ctrl+Shift+3 { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:clipper" "addToTodo3"; }
}
```

**Sway** (`~/.config/sway/config`):
```ini
bindsym $mod+Ctrl+Shift+1 exec qs -c noctalia-shell ipc call plugin:clipper addToTodo1
bindsym $mod+Ctrl+Shift+2 exec qs -c noctalia-shell ipc call plugin:clipper addToTodo2
bindsym $mod+Ctrl+Shift+3 exec qs -c noctalia-shell ipc call plugin:clipper addToTodo3
```

### Customization

![Settings](Assets/settings.png)

#### Appearance Tab
- **Per-type Card Colors** - Customize background, separator, and foreground colors for each card type
- **Color Scheme Integration** - Choose from Noctalia color scheme or set custom hex colors
- **Live Preview** - See changes in real-time before applying
- **Reset to Defaults** - One-click restore of default color scheme

#### Features Tab
- **ToDo Integration Toggle** - Enable/disable ToDo plugin integration
- **IPC Command Reference** - Quick reference for available commands

### IPC Commands
Control the plugin via command line:
```bash
# Panel control
qs -c noctalia-shell ipc call plugin:clipper openPanel
qs -c noctalia-shell ipc call plugin:clipper closePanel
qs -c noctalia-shell ipc call plugin:clipper togglePanel

# ToDo integration (requires ToDo plugin)
qs -c noctalia-shell ipc call plugin:clipper addToTodo1    # Add selection to page 1
qs -c noctalia-shell ipc call plugin:clipper addToTodo2    # Add selection to page 2
# ... through addToTodo9

qs -c noctalia-shell ipc call plugin:clipper addToTodo 0   # Add selection to specific page (0-indexed)
```

### Bar Widget
- Clipboard icon in the bar
- Click to open panel
- Right-click context menu with "Clear History" option
- Per-screen sizing support

## Installation

1. Clone this repository to your Noctalia plugins directory:
   ```bash
   git clone https://github.com/blackbartblues/noctalia-clipper.git ~/.config/noctalia/plugins/clipper
   ```

2. Enable the plugin in Noctalia settings

3. Ensure `cliphist` is installed on your system:
   ```bash
   # Arch Linux
   pacman -S cliphist wl-clipboard

   # Or build from source
   go install go.senan.xyz/cliphist@latest
   ```

## Requirements

- Noctalia Shell >= 4.1.2
- cliphist (clipboard history manager)
- wl-clipboard (for Wayland clipboard access)
- ToDo plugin (optional, for ToDo integration feature)

## Changelog

### v1.1.0
- Added ToDo plugin integration
- Added "Add to ToDo" button on clipboard cards (Text, Link, Code types)
- Added IPC commands `addToTodo1` through `addToTodo9` for keybind support
- Added `addToTodo` and `addTextToTodo` IPC commands
- Added Features tab in Settings with ToDo integration toggle
- Settings now use tabbed interface (Appearance / Features)

### v1.0.0
- Initial release
- Clipboard history with cliphist backend
- Content type detection and filtering
- Full keyboard navigation
- Customizable card colors
- Bar widget with context menu

## License

MIT

## Authors

- blackbartblues
- rscipher001
