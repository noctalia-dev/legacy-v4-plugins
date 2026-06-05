# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A plugin for **Noctalia** (a Quickshell-based desktop shell, `noctalia-shell`). It is pure QML loaded at runtime by the running shell — there is **no build step, no compiler, and no test framework** in this repo. The plugin's purpose is a bar widget that shows battery indicators for connected peripherals (e.g. mouse, keyboard, headphones). Device data does **not** come from any Noctalia service — it is gathered by `scripts/scan.py` (see below).

Requires `minNoctaliaVersion: 4.6.6`.

## This implementation's architecture

The plugin is split across three entry points plus one helper script:

- **`scripts/scan.py`** — the data layer and the only place that knows how to talk to devices. It probes every supported source and prints a **normalized JSON array** on stdout: `[{ id, name, type, battery, charging, source }]`. `id` is `"<source>:<stable-key>"`. Each source is a `scan_<source>()` function that swallows its own errors (missing tool → `[]`). Current sources: `scan_openrazer()` (via the `openrazer` Python client / running `openrazer-daemon`) and `scan_solaar()` (parses `solaar show`). **To add a new device source, add a `scan_*()` and append it to `SOURCES` — nothing in the QML changes.**
- **`Main.qml`** (`main` entry point) — runs `scan.py` on a `Timer` (interval = `pluginSettings.refreshInterval`, default 60s), parses the JSON, and exposes the live list as `property var devices`. Also exposes `refresh()` and an `IpcHandler` (`plugin:battery-wireless-devices` → `refresh`).
- **`BarWidget.qml`** — reads live data from `pluginApi.mainInstance.devices` and per-device config from `pluginApi.pluginSettings.devices`. Renders one pill per device the user has **enabled**, each a device icon inside a circular battery ring (a `Canvas`). Ring colour is auto-by-level unless overridden; click runs the device's `launchCmd` via `Quickshell.execDetached`.
- **`Settings.qml`** (`settings` entry point) — lists detected + previously-configured devices (drag the handle to reorder; top = left-most / top-most in the bar) and lets the user set per device: `enabled`, `icon`, `iconColor`, `ringColor`, `launchCmd`. Settings shape: `pluginSettings.devices` is a map keyed by device `id`, `pluginSettings.deviceOrder` is an ordered array of ids; globals are `refreshInterval` and `showPercentage`. Edits apply **live** (debounced `commit()` rebuilds `devices` with fresh object identities so the bar's bindings re-fire); the popup's Apply button is redundant. `populateList()` also auto-heals stale duplicate entries (same source + name, different id).

Data flow: `scan.py` → `Main.qml.devices` → (`pluginApi.mainInstance`) → `BarWidget`. Config flow: `Settings.qml` → `pluginSettings.devices` → `BarWidget`.

## Layout & how a plugin is structured

- `manifest.json` — the contract. `id` must be unique; `entryPoints` maps roles to QML files. Each role is optional; this plugin currently only defines `barWidget`. Other available roles (see the `arch-updater` reference plugin): `main` (background singleton/logic, instantiated once), `panel`, `settings`, `controlCenterWidget`, `desktopWidget`, `launcherProvider`.
- `metadata.defaultSettings` in the manifest defines the plugin's persisted settings schema and defaults. User overrides are merged on top at load.
- Entry-point `.qml` files live at the repo root. `i18n/<lang>.json` files provide translations (`en.json` is the fallback); this plugin ships `i18n/en.json` and routes every user-facing string through `pluginApi.tr("dot.path.key")` — no inline literals or post-`tr()` fallbacks (a Noctalia plugin convention; see the repo-root `AGENTS.md`).

## Installation / runtime model

The plugin runs from `~/.config/noctalia/plugins/<id>/`. During development this is a **symlink** to this repo, so edits here are live. Enablement and source are tracked in `~/.config/noctalia/plugins.json` (`states.<id>.enabled`).

The shell itself runs as `qs -c noctalia-shell`. The Noctalia source (read-only, useful as API reference) is installed at `/etc/xdg/quickshell/noctalia-shell/` — `Commons/`, `Widgets/`, and `Services/` there define everything importable below.

## Imports available to plugin QML

```qml
import qs.Commons      // singletons: Style, Color, Settings, I18n, Logger, Icons, Time, ShellState
import qs.Widgets      // N-prefixed components: NIcon, NText, NButton, NComboBox, NColorChoice, NToggle, ...
import qs.Services.UI  // TooltipService, PanelService, BarService (used by BarWidget.qml)
```

Service singletons live in subfolders under `Services/` (UI, Networking, Control, Noctalia, SystemInfo, ...). This plugin only uses `qs.Services.UI`; it does **not** read battery data from any service (that comes from `scan.py`). Grep the shell source to find the right import path for any other service.

## Key conventions (follow these — don't reinvent)

- **Never hardcode sizes/colors.** Use `Style.*` (`marginS/M`, `barHeight`, `capsuleColor`, `radiusM`, `fontSizeS/M/L`) and `Color.*` (`mPrimary`, `mOnSurface`, `mSurface`, ...) so the widget respects the user's theme and UI scale. `NIcon`/`NText` already apply UI scaling.
- **Icons** are Tabler icon names passed to `NIcon { icon: "..." }` (e.g. `"heart"`); the full set is in `Commons/IconsTabler.qml`.
- **Bar widgets** must declare the properties the loader injects: `screen` (ShellScreen), `widgetId`, `section`, `sectionWidgetIndex`, `sectionWidgetsCount`, plus `property var pluginApi`.

## The `pluginApi` object

`PluginService` injects a `pluginApi` into every entry point. It exposes:
- `pluginId`, `pluginDir`, `manifest`
- `pluginSettings` — merged defaults + user settings. Mutate it, then call `saveSettings()` to persist (the call also replaces the object so QML bindings re-fire).
- Panel control: `openPanel(screen, buttonItem)`, `closePanel(screen)`, `togglePanel(...)`, and launcher equivalents.
- i18n: `tr(key, interpolations)`, `trp(key, count, interpolations)`, `hasTranslation(key)`; depend on `translationVersion` to react to language changes.
- Instance references once loaded: `mainInstance`, `barWidget`, `panel`, etc.

## Where device battery data comes from

**`scripts/scan.py` only** — not `BluetoothService`, `BatteryService`, or any other Noctalia service. The script probes each supported source (`scan_openrazer()` via the openrazer Python client, `scan_solaar()` by parsing `solaar show`) and prints the normalized JSON array consumed by `Main.qml`. The devices here (Razer dongle, Logitech receiver) aren't Bluetooth, so the shell's Bluetooth/UPower services don't see them — that's the whole reason the plugin shells out to vendor tools.

## Developing & verifying changes

There are no unit tests. To see changes: enable Noctalia **debug mode** (`Settings.isDebug`, or launch with `NOCTALIA_DEBUG=1`) — `PluginService` then sets up file watchers and **hot-reloads** the plugin on save. Watch the shell's stdout / `Logger` output (run `qs -c noctalia-shell` from a terminal) for QML errors and plugin load failures, which `PluginService` records in `pluginErrors`.

**Manifest changes require a full shell restart, not hot reload.** `PluginRegistry.getPluginManifest()` returns an in-memory cache (`installedPlugins`) populated by a disk scan at startup. Hot reload re-instantiates QML against that *cached* manifest, so adding/removing `entryPoints` (or changing `metadata.defaultSettings`) is invisible until the shell restarts. Symptom: a newly-added `main` entry point's `IpcHandler` returns "Target not found". Editing existing `.qml` files hot-reloads fine.

Smoke test that `Main.qml` loaded: `qs -c noctalia-shell ipc call plugin:battery-wireless-devices refresh` (returns a success string). Verify `scan.py` independently with `python3 scripts/scan.py`. The bar widget renders nothing until the user adds the widget to a bar section **and** enables at least one device in the plugin settings.
