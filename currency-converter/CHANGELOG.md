# Changelog

All notable changes to this project will be documented in this file.

## [1.0.4] - 2026-01-26

### Changed

- Current patch release: various small fixes and improvements leading up to 1.0.2.

### Added

- Settings button on the panel header to open plugin settings directly (closes panel first and uses `BarService.openPluginSettings(...)` with fallbacks).
- Bar widget: clicking the widget now opens the converter panel anchored to the widget (panel opens next to the button), with robust fallbacks for different host APIs.
- Panel: repositioned the swap button so it is visually centered between the From and To inputs for better ergonomics.

## [1.0.2/1.0.3] - 2026-01-06

* Added dark background wrapper with Color.mSurfaceVariant
* Fixed hardcoded Portuguese string "Sem dados disponíveis"
* Added "no-data" translation key to all 12 language files
* Restructured panel layout with proper NBox hierarchy
* Moved exchange rate badge outside main card for better visual separation
* Fixed multiple bracket syntax errors and indentation issues
* Normalized spacing between form elements (From, Swap, To)
* Adjusted margins to prevent elements from touching card edges

## [1.0.1] - 2026-01-04

### Added

- Real-time Exchange Rates: Automatic updates at configurable intervals.
- Multiple Currencies: Support for major world currencies.
- Quick Swap: Instantly swap between source and target currencies.
- Configurable Settings: update interval, display mode, source/target currencies.
- Internationalization: Fully translated to 12 languages.
- Clean UI: Compact bar widget with detailed converter panel.
- Efficient: Smart caching and minimal network usage.

---
