# Noctalia Main Plugins Registry

Main plugin registry for [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell).

## Overview

This repository hosts community and official plugins for Noctalia Shell.
The `registry.json` file is automatically maintained and provides a centralized index of all available plugins.

## Plugin Structure

Each plugin must have the following structure:

```
plugin-name/
├── manifest.json      # Plugin metadata (required)
├── preview.png        # Preview image used noctalia's website, 16:9 @ 960x540 pixels (required)
├── README.md          # Plugin documentation (required)
├── Main.qml           # Main component for IPCTarget or general logic (optional)
├── BarWidget.qml      # Bar widget component (optional)
├── DesktopWidget.qml  # Desktop widget component (optional)
├── Panel.qml          # Panel component (optional)
└── Settings.qml       # Settings UI (optional)
```

### manifest.json

Every plugin must include a `manifest.json` file with the following fields:

```json
{
  "id": "plugin-id",
  "name": "Plugin Name",
  "version": "1.0.0",
  "minNoctaliaVersion": "3.6.0",
  "author": "Your Name",
  "license": "MIT",
  "repository": "https://github.com/noctalia-dev/noctalia-plugins",
  "description": "Brief plugin description",
  "tags": ["Bar", "Panel"],
  "entryPoints": {
    "main": "Main.qml",
    "barWidget": "BarWidget.qml",
    "panel": "Panel.qml",
    "settings": "Settings.qml"
  },
  "dependencies": {
    "plugins": []
  },
  "metadata": {
    "defaultSettings": {}
  }
}
```

### Tags

Plugins can include tags to help users find them. The following tags are currently in use:

**Widget Type Tags** (based on entry points):

| Tag        | Description                  |
| ---------- | ---------------------------- |
| `Bar`      | Adds a widget to the bar     |
| `Desktop`  | Adds a widget to the desktop |
| `Panel`    | Has a panel                  |
| `Launcher` | Provides launcher results    |

**Functional Tags** (what the plugin does):

| Tag            | Description                            |
| -------------- | -------------------------------------- |
| `AI`           | AI-features, AI-tools                  |
| `Audio`        | Audio visualization, media             |
| `Development`  | Developer tools                        |
| `Fun`          | Entertainment, decorative              |
| `Gaming`       | Gaming-related tools                   |
| `Indicator`    | Status indicators                      |
| `Music`        | Lyrics, music related                  |
| `Network`      | Network monitoring                     |
| `Privacy`      | Privacy/security indicators            |
| `Productivity` | Notes, todos, task management          |
| `System`       | System info, updates, hardware control |
| `Theming`      | Theming helper tools                   |
| `Utility`      | General utility tools                  |

**Compositor Tags** (which compositor the plugin is made for):

| Tag        | Description       |
| ---------- | ----------------- |
| `Hyprland` | Works on Hyprland |
| `Labwc`    | Works on Labwc    |
| `Mangowc`  | Works on Mangowc  |
| `Niri`     | Works on Niri     |
| `Sway`     | Works on Sway     |

New tags can be added on a case-by-case basis. If your plugin doesn't fit the existing tags, feel free to propose a new one in your pull request.

## Adding a Plugin

1. **Fork this repository**

2. **Create your plugin directory**

   ```bash
   mkdir your-plugin-name
   cd your-plugin-name
   ```

3. **Create manifest.json** with all required fields

4. **Implement your plugin** using QML components

5. **Test your plugin** with Noctalia Shell

6. **Submit a pull request**
   - The `registry.json` will be automatically updated by GitHub Actions
   - Ensure your manifest.json is valid and complete

## Registry Automation

The plugin registry is automatically maintained using GitHub Actions:

- **Automatic Updates**: Registry updates when manifest.json files are modified
- **PR Validation**: Pull requests show if registry will be updated

See [.github/workflows/README.md](.github/workflows/README.md) for technical details.

## Available Plugins

Check [registry.json](registry.json) or the [plugin overview](https://noctalia.dev/plugins/) on the Noctalia homepage for the complete list of available plugins.

## Custom Repositories

In addition to this main plugin registry, Noctalia Shell supports loading plugins from custom repositories.

This allows the community to share and use plugins outside the main registry.

| Repository  | Link                                                                |
| ----------- | ------------------------------------------------------------------- |
| bennypowers | [GitHub](https://github.com/bennypowers/noctalia-plugins)           |
| rukh-debug  | [GitHub](https://github.com/rukh-debug/noctalia-unofficial-plugins) |
| ajunca      | [GitHub](https://github.com/ajunca/noctalia-dropdown-terminal)      |
| phanindra   | [GitHub](https://github.com/pahnin/noctalia-unofficial-plugins)     |

## AI Development

If using AI tools to contribute, see [AGENTS.md](./AGENTS.md) for plugin patterns and guidelines.

## License

MIT - See individual plugin licenses in their respective directories.
