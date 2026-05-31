# Repository Guidelines

## Project Structure & Module Organization

AndroidConnect is a Noctalia QML plugin. Root-level QML files are plugin entry points: `Main.qml`, `BarWidget.qml`, `ControlCenterWidget.qml`, `Panel.qml`, `PhoneDisplay.qml`, and `Settings.qml`. Shared service logic lives in `Services/`, with `Services/qmldir` declaring QML modules. Static artwork is under `Assets/`, screenshots and user-facing documentation are under `Docs/`, and translations live in `i18n/*.json`. `manifest.json` defines plugin metadata, entry points, defaults, and the release version. `settings.json` is local runtime state and must remain untracked.

## Build, Test, and Development Commands

There is no compile step or package manager for this repository. Develop in place under `~/.config/noctalia/plugins/androidconnect`, then reload or restart Noctalia to test UI changes.

- `jq . manifest.json` validates plugin metadata JSON.
- `for f in i18n/*.json; do python3 -m json.tool "$f" >/dev/null; done` validates translation files.
- `git diff --check` catches trailing whitespace before committing.
- `qmlformat -n *.qml Services/*.qml` checks QML formatting when `qmlformat` is installed.
- `adb devices`, `kdeconnect-cli --list-devices`, and `v4l2-ctl -D -d /dev/video10` help verify the Android, KDE Connect, and mirror dependencies used at runtime.

## Coding Style & Naming Conventions

Follow the existing QML style: two-space indentation, braces on the same line, semicolons in JavaScript blocks, and explicit `id` values for important objects. Use lower camelCase for properties, functions, and signals. Keep user-visible strings in `i18n/en.json` and mirror new keys across other locale files when possible. Prefer existing Noctalia imports, `Style` tokens, and helper components over one-off UI code.

## Testing Guidelines

No automated test suite is currently present. For changes, run the JSON and whitespace checks above, then manually verify the affected panel path in Noctalia. For mirror or input changes, test with a paired KDE Connect device, `adb`, `scrcpy`, and the `/dev/video10` loopback feed. Include before/after screenshots for visual changes.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects matching the history, such as `Add screen timeout controls for panel mirroring` or `Fix translation issues`. Release commits use `Release vX.Y.Z`, and published release tags must match `manifest.json` as `v<version>` because the sync workflow enforces that. Pull requests should describe behavior changes, list manual test coverage, note dependency assumptions, link relevant issues, and include screenshots or recordings for UI work.

## Security & Configuration Tips

Do not commit secrets, device-specific paths, ADB pairing details, or local `settings.json`. Keep GitHub release sync configuration in `.github/` aligned with `manifest.json` version changes.
