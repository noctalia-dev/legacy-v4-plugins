# Publishing to the Noctalia Plugin Registry

To make this plugin available in the official Noctalia plugin list for all users:

## 1. Fork the official registry

```bash
gh repo fork noctalia-dev/noctalia-plugins --clone=false
```

## 2. Clone your fork

```bash
gh repo clone YOUR_USER/noctalia-plugins /tmp/noctalia-plugins-fork
```

## 3. Copy plugin files into a new directory

```bash
mkdir -p /tmp/noctalia-plugins-fork/niri-auto-tile

# Copy all plugin files (QML, manifest, i18n, Python daemon, LICENSE, README)
cp manifest.json Main.qml BarWidget.qml Panel.qml Settings.qml \
   README.md LICENSE auto-tile.py settings.json \
   /tmp/noctalia-plugins-fork/niri-auto-tile/

cp -r i18n /tmp/noctalia-plugins-fork/niri-auto-tile/
```

## 4. Update manifest.json repository field

In the **copy** inside `noctalia-plugins-fork/niri-auto-tile/manifest.json`, change the `repository` field to point to the official registry:

```json
"repository": "https://github.com/noctalia-dev/noctalia-plugins"
```

## 5. Commit and push

```bash
cd /tmp/noctalia-plugins-fork
git checkout -b add-niri-auto-tile
git add niri-auto-tile/
git commit -m "feat: add niri-auto-tile plugin"
git push -u origin add-niri-auto-tile
```

## 6. Create the pull request

```bash
gh pr create --repo noctalia-dev/noctalia-plugins \
  --head YOUR_USER:add-niri-auto-tile \
  --base main \
  --title "Add niri-auto-tile plugin" \
  --body "Auto-tiling daemon for niri with Noctalia Shell integration."
```

## 7. Wait for merge

- The `assign-reviewers` GitHub Action runs automatically on PR creation
- Once merged, `registry.json` is updated automatically by GitHub Actions
- The plugin then appears in **Noctalia Settings > Plugins** for all users

## Plugin directory structure (required by noctalia-plugins)

```
niri-auto-tile/
├── manifest.json      # Plugin metadata (required)
├── Main.qml           # Daemon lifecycle management
├── BarWidget.qml      # Bar indicator widget
├── Panel.qml          # Floating panel with column selector
├── Settings.qml       # Full settings UI
├── auto-tile.py       # Python daemon
├── settings.json      # Default settings
├── i18n/              # Translations
│   ├── en.json
│   └── pt.json
├── LICENSE
└── README.md
```

> **Note:** The `registry.json` does not need to be edited manually — it is maintained automatically by GitHub Actions when `manifest.json` files are added or modified.
