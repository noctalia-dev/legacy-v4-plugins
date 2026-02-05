# Changelog

All notable changes for this plugin are documented in this file.

## [1.0.2] - 2026-01-26

- **feat:** Open the panel anchored to the widget when the `BarWidget` is clicked (improves interaction flow). ✅
- **feat:** Add a **Settings** button to the panel header that closes the panel and opens the plugin settings using `BarService.openPluginSettings(...)`. ✅
- **fix:** Ensure settings are persisted via `pluginApi.saveSettings()` where applicable.

## [1.0.1] - Initial release

- Display time from multiple timezones with automatic rotation.
- Configurable rotation interval (in seconds).
- Configurable time format (24h/12h, optional seconds).
- Add/remove timezones (max 5) and toggle each entry on/off.
- Popular timezones list with localized names (i18n).
- Persistence of settings (timezones, rotationInterval, timeFormat) via `pluginApi.pluginSettings`.
- Shows city and current time in the bar widget; supports vertical and horizontal layouts.
- Uses the system `date` command per timezone for accurate displayed times.
- Default timezones included: New York, London, Tokyo.

---
