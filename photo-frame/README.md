# Photo Frame - Desktop Widget Plugin

A lightweight and customizable desktop widget plugin for Noctalia that displays images in a configurable frame. Perfect for showcasing photos on your desktop with adjustable styling options.

## Features

✨ **Image Display**
- Display any image file in a desktop widget
- Automatic aspect ratio preservation
- Smooth image loading with placeholder feedback

🎨 **Customization**
- Configurable frame styling
- Transparent background mode (display image only)
- Per-widget and global default settings
- Independent settings for multiple widget instances

⚙️ **Settings**
- Global default image configuration
- Per-widget instance configuration
- Easy image picker with file browser
- Transparent background toggle

🌐 **Internationalization**
- Multi-language support (English, Spanish)
- Fully localized UI components
- Compliant with Noctalia translation standards

## Requirements

- **Noctalia** version 4.6.6 or higher
- **Qt Quick** 2.15 or higher
- **Qt Layouts** module

## Installation

1. Clone or download this plugin to your Noctalia plugins directory:
   ```bash
   ~/.noctalia/plugins/marco-fotos/
   ```

2. The plugin will be automatically discovered and loaded by Noctalia

3. Enable it in Noctalia's plugin settings

## Quick Start

### Add a Widget to Your Desktop

1. Open Noctalia
2. Navigate to Widgets
3. Find "Photo Frame" in the available widgets
4. Click "Add Widget" to place it on your desktop
5. Click the settings icon to configure the image

### Configure Global Defaults

1. Go to Settings
2. Find "Photo Frame" in the plugins section
3. Set your default image and preferences
4. Click "Save"

New widget instances will use these defaults.

### Configure Individual Widgets

1. Right-click on any Photo Frame widget
2. Select "Settings"
3. Choose your image using the file picker
4. Toggle transparent background if desired
5. Click "Apply"

## Configuration

### Widget Settings Panel

The widget settings panel (`PhotoFrameSettings.qml`) provides:

- **Image path**: Manual input or file picker selection
- **Select image**: File browser button to choose an image
- **Transparent background**: Toggle to show only the image without frame
- **Apply**: Save changes for this widget instance

### Global Settings

The global settings panel (`Settings.qml`) provides:

- **Image path**: Default image for new widgets
- **Select image**: File browser for default image
- **Transparent background**: Default transparency setting
- **Save**: Store global defaults

## File Structure

```
photo-frame/
├── manifest.json                 # Plugin metadata
├── PhotoFrame.qml               # Main widget component
├── PhotoFrameSettings.qml       # Widget settings panel
├── Settings.qml                 # Global settings panel
├── README.md                    # This file
└── i18n/                        # Translations
    ├── en.json                  # English translations
    └── es.json                  # Spanish translations
```

### Key QML Components

- **PhotoFrame.qml**: Main widget that displays the image with frame styling
- **PhotoFrameSettings.qml**: Settings panel for individual widget instances
- **Settings.qml**: Global default settings panel

## Image Guidelines

**Supported Formats:**
- JPG/JPEG
- PNG
- GIF (static frames)
- SVG
- WebP

**Recommended Sizes:**
- Width: 300-600px for desktop use
- Height: 220-450px for desktop use
- Aspect ratio: Any (automatically fitted)

**File URLs:**
Use absolute file paths with `file://` protocol:
```
file:///home/username/Pictures/photo.jpg
```

## Translation

The plugin includes translations for:
- **English** (en.json)
- **Spanish** (es.json)

### Adding New Languages

1. Create a new JSON file in `i18n/` directory (e.g., `fr.json`)
2. Copy the structure from existing translation files
3. Translate all string values
4. Noctalia will auto-detect and use the file

### Translation Keys Structure

```json
{
  "widget": {
    "loading": "Loading...",
    "noImage": "No image"
  },
  "desktopWidgetSettings": {
    "title": "Photo Frame",
    "imagePath": {
      "label": "Image path",
      "description": "Description here"
    }
  }
}
```

## Troubleshooting

### Image Not Showing

1. Verify the file path is correct and uses `file://` protocol
2. Check that the image file is readable
3. Ensure the image format is supported
4. Try a different image to rule out format issues

### Settings Not Saving

1. Restart Noctalia to reload plugins
2. Check file permissions in the widget data directory
3. Verify the path is using `file://` protocol

### Multiple Widgets Show Same Image

- Each widget has independent settings
- Settings are stored per-instance in the widget data
- Use the widget settings panel to configure each one individually

### Transparent Background Not Working

1. Ensure the toggle is enabled in widget settings
2. Restart the widget or reload Noctalia
3. Check that the image format supports transparency if needed

## Development

### Building from Source

```bash
cd photo-frame
# No build step required - QML is interpreted
```

### Testing

1. Copy the plugin to your Noctalia plugins directory
2. Restart Noctalia
3. Add the widget and test functionality
4. Check translations with different language settings

### Modifying the Code

- QML files are hot-reloaded in development mode
- Restart Noctalia after modifying translations
- Changes to `manifest.json` require plugin reload

### Structure

- Properties use the standard Noctalia pattern with `widgetData` for per-instance settings
- Global settings use `pluginApi.pluginSettings`
- All translations go through `pluginApi.tr()` method
- Fallback values are not used (follows Noctalia standards)

## Performance

The widget is optimized for:
- Minimal memory footprint
- Efficient image scaling
- Smooth animations during resize
- Proper caching to avoid reloading images

**Image Cache Behavior:**
- Images are cached by Qt
- Disk cache is enabled for web images
- Memory cache improves performance with multiple instances

## Metadata

- **Plugin ID**: marco-fotos
- **Version**: 1.0.1
- **License**: MIT
- **Author**: Evergaster
- **Category**: Desktop, Media

## License

This plugin is licensed under the MIT License. See LICENSE file (if present) for details.

## Author

**Evergaster** - [GitHub Profile](https://github.com/noctalia-dev)

### Contributing

Contributions are welcome! Please feel free to submit pull requests or issues to:
- https://github.com/noctalia-dev/noctalia-plugins

## Changelog

### Version 1.0.1
- Fixed independent image handling for multiple widget instances
- Removed fallback translation values (Noctalia standard compliance)
- Improved widget initialization logic

### Version 1.0.0
- Initial release
- Basic photo frame widget functionality
- Settings panel with file picker
- Global and per-instance configuration

## Support

For issues, questions, or feature requests:
1. Check the [Noctalia Documentation](https://noctalia.dev)
2. Review existing issues on GitHub
3. Open a new issue with detailed information
4. Contact the author

---

**Enjoy your Photo Frame widget! 📷**
