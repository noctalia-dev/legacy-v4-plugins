# Changelog

All notable changes for this plugin are documented in this file.

## [1.0.4] - 2026-01-27

- **feat:** Add full Polish translation (`i18n/pl.json`) — all UI strings, panel interface, settings dialog, tooltips and notifications translated. ✅
- **fix:** Correct Polish translation for the target price label (was mistranslated). ✅
- **feat:** Expanded currency support (10 → 44 currencies). Added major Steam-supported currencies across regions (EUR, GBP, CHF, CZK, DKK, HUF, NOK, PLN, RON, SEK, UAH, CNY, HKD, IDR, INR, JPY, KRW, MYR, PHP, SGD, THB, TWD, VND, ILS, KWD, QAR, SAR, ARS, BRL, CAD, CLP, COP, CRC, MXN, PEN, USD, UYU, AUD, NZD, KZT, RUB, TRY, ZAR). Each currency includes a proper symbol mapping in the settings UI. ✅
- **chore:** Bump manifest version to `1.0.4` to match repository `main`. ✅
- **perf/UI:** Extend settings UI to include expanded currency selector and symbol mapping; ensured selection persists via `pluginApi.saveSettings()`.

## [1.0.3] - Previous release

- Display Steam game prices and notify when they reach your target price.
- Watchlist management with ability to add/remove games and set target prices.
- Configurable check interval and target price notifications.
- Support for multiple currencies (initial set) and configurable currency symbol.
- Localized UI strings available in multiple languages.

---
