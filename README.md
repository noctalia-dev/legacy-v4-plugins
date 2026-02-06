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
├── Main.qml           # Main component for IPCTarget or general logic (optional)
├── BarWidget.qml      # Bar widget component (optional)
├── Panel.qml          # Panel component (optional)
├── Settings.qml       # Settings UI (optional)
├── preview.png        # Preview image used noctalia's website, 16:9 @ 960x540 pixels
└── README.md          # Plugin documentation
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
| Tag | Description |
|-----|-------------|
| `Bar` | Adds a widget to the bar |
| `Desktop` | Adds a widget to the desktop |
| `Panel` | Has a panel |
| `Launcher` | Provides launcher results |

**Functional Tags** (what the plugin does):
| Tag | Description |
|-----|-------------|
| `Productivity` | Notes, todos, task management |
| `System` | System info, updates, hardware control |
| `Audio` | Audio visualization, media |
| `Network` | Network monitoring |
| `Privacy` | Privacy/security indicators |
| `Development` | Developer tools |
| `Fun` | Entertainment, decorative |
| `Gaming` | Gaming-related tools |
| `Indicator` | Status indicators |

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

| Repository        | Link                                                                     |
|-------------------|--------------------------------------------------------------------------|
| ThatOneCalculator | [GitHub](https://github.com/ThatOneCalculator/personal-noctalia-plugins) |
| bennypowers | [GitHub](https://github.com/bennypowers/noctalia-plugins) |
| rukh-debug | [GitHub](https://github.com/rukh-debug/noctalia-unofficial-plugins) |

## Development

```bash
# Update registry manually
node .github/workflows/update-registry.js
```

## License

MIT - See individual plugin licenses in their respective directories.
