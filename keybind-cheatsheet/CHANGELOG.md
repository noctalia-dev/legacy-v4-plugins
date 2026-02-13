# Changelog

## [3.2.2] - 2026-02-08

### 🐛 Bug Fixes

**Hyprland Parser - No Category Handling**
- Fixed parser crash when Hyprland config has no category headers (`# 1. Category Name`)
- Parser now creates default "Keybinds" category for configs without categories
- Default category name is fully translatable via i18n system
- Prevents keybind loss for users who don't organize their configs with categories

### 🌍 Translations

**Complete i18n Coverage**
- Added `default-category` translations for all 19 supported languages
- Added missing `error` section translations to all language files (includes German from 3.1.2)
- All language files now have identical structure (61-62 lines each)
- Improved translation consistency across all locales

**Supported Languages:**
- English (en), Polish (pl), German (de), French (fr), Spanish (es)
- Italian (it), Portuguese (pt), Dutch (nl), Russian (ru), Japanese (ja)
- Chinese Simplified (zh-CN), Chinese Traditional (zh-TW), Korean (ko-KR)
- Turkish (tr), Ukrainian (uk-UA), Swedish (sv), Hungarian (hu)
- Kurdish (ku), Norwegian Nynorsk (nn-NO), Hindi/Nepali (hn)

### 🔧 Code Quality

**Memory Leak Prevention**
- Added recursion limit tracking for parser (`hasCategories` flag)
- Improved parser robustness and error handling
- Better fallback behavior for edge cases

---

## [3.1.2] - 2026-02-08

### 🌐 Translations

- Added german translations for the `error` keys

## [3.1.1] - 2026-02-03

### 🚀 Smart Caching

**Compositor Change Detection**
- Plugin now detects when compositor changes (e.g., switching from Hyprland to Niri)
- Automatically re-parses config only when compositor differs from cached data
- Instant panel opening when using same compositor (uses cache)
- Saves detected compositor in settings for comparison

### 🐛 Bug Fixes

**Improved Niri Parser**
- Fixed multiline bind parsing - handles binds that span multiple lines
- Added `spawn-sh` action support for shell command spawning
- Added `move-column-to-workspace` and `move-window-to-workspace` action categories
- Better handling of complex Niri config structures

**Better Error Messages**
- User-friendly messages for unsupported compositors (Sway, LabWC, MangoWC)
- Each compositor shows specific explanation why it's not supported
- All error messages are translatable via i18n

### 📝 Documentation

**README Updates**
- Fixed IPC command syntax in examples
- Updated keybind format examples to use `$mainMod` instead of `$mod`
- Clarified configuration file paths and formats

---

## [3.1.0] - 2026-02-03

### ✨ New Features

**Niri Support**
- Full Niri compositor support with KDL config parsing
- Recursive file parsing with `source` directive support
- Automatic action categorization
- Multiline bind support

**Recursive Config Parsing**
- Both Hyprland and Niri now support recursive file includes
- Memory leak prevention with recursion limits
- Glob pattern support for bulk file imports

### 🔧 Improvements

**Better Error Handling**
- Graceful fallback for unsupported compositors
- User-friendly error messages
- Translation support for all error states

---

## [3.0.0] - 2026-01-30

### 🎉 Initial Release

**Core Features**
- Hyprland keybind parsing
- Category organization
- Multi-language support
- Bar widget integration
- Settings UI
