# Changelog

All notable changes to this project will be documented in this file.

### Changed

- Persist settings using Noctalia plugin settings API; removed example `settings.json` file.

## [1.0.2] - 2026-01-26

### Added

- Configuration defaults (update interval, max items per feed, mark-as-read behavior).

### Improvements

- Panel: Settings button now closes the panel and opens plugin settings using `BarService.openPluginSettings(...)`; added fallbacks for older environments.
- Panel: Added a visual unread badge in the header and centralized unread count calculation.
- Panel/BarWidget: Propagate unread count via `pluginApi.unreadCount` to ensure the bar widget updates promptly.
- BarWidget: Avoid creating `pluginApi.sharedData` when not available to prevent runtime errors.
- Settings: Removed redundant title from `Settings.qml`.
- Added a 250ms debounce to panel header and bar widget badge pulses to avoid multiple pulse animations when many items arrive simultaneously.
- Settings are persisted via `pluginApi.saveSettings()` (Noctalia plugin storage). Writing a local `settings.json` in the plugin root was removed in favor of using the plugin storage only.

### Fixed

- Fixed ReferenceError caused by an undefined `unreadCount` in `Panel.qml`.
- Fixed warning/error when attempting to assign `pluginApi.sharedData` on environments where the property is not writable.
- Panel: Update unread badge immediately when marking items as read so the bar widget reflects the new count without delay.

## [1.0.1] - 2025-12-01

### Added

- Initial plugin: RSS/Atom feed monitoring and reading UI components (`BarWidget.qml`, `Panel.qml`, `Settings.qml`).
- Default configuration: `updateInterval`, `maxItemsPerFeed`, `markAsReadOnClick`, and `readItems` tracked in `manifest.json`.
- Minimum Noctalia version: `3.6.0`.

### Notes

- Minimum Noctalia version: `3.6.0`.
