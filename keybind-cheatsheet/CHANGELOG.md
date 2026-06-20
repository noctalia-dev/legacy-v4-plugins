# Changelog

## [3.7.3] - 2026-05-25

### Fixes

- **Niri: descriptions invisible on light/transparent backgrounds.** Since v3.5.0 the description text color defaulted to a hardcoded `#E0E0E0` (light gray), which is unreadable on light wallpapers shining through a transparent panel. Default is now empty → falls back to `Color.mOnSurface` (theme-aware, always readable). Existing users with a baked-in `#E0E0E0` in their `settings.json` should hit **Reset** on the Description color in Settings → Appearance to pick up the theme-aware default. Reported by @porcaror (#884)
- **MangoWC: `binds=` / `axisbinds=` / `mousebinds=` (plural) directives now parsed.** MangoWC has two directive families: singular (keycode, QWERTY-mapped) and plural (keysym, layout-aware — used by AZERTY and other non-QWERTY layouts). The parser previously only matched the singular form, so AZERTY configs showed no binds. Both forms are now recognised. Reported by @Pintjebier (#881)

## [3.7.2] - 2026-05-21

### Fixes

- **Settings panel was rendering empty**: `Settings.qml` and `ColorPairRow.qml` reference sibling files (`ColorPairRow`, `ColorPill`) but Quickshell's `NPluginSettingsPopup` loads Settings via `Loader.setSource(file://...)` without adding the plugin directory to the implicit import list. The QML engine threw `ColorPairRow is not a type`, aborting the load. Added `import "."` to both files so the sibling components resolve. Reported by @ajgringo619 (#862)
- **Hyprland Lua: split configs lost their category headers** (`require("modules.keybinds")` resolved as `modules.keybinds.lua` instead of `modules/keybinds.lua`). Lua's `require` treats dots as path separators; the parser now converts them before resolving, so configs that split binds into submodules — e.g. `hyprland.lua` -> `require("modules.keybinds")` -> `modules/keybinds.lua` — pick up their `-- N. CATEGORY` headers and binds land in the correct categories instead of all falling into "Other". Reported by @ajgringo619 (#862)

## [3.7.1] - 2026-05-20

### Fixes

- Settings: fix `ReferenceError: rootItem is not defined` in the bind-override management section — the override counter, **Restore hidden**, and **Clear all overrides** buttons were broken because of stale `rootItem` references after the `id` rename
- Settings: use the native `tr(key, interpolations)` API for the overrides summary line instead of chained `.replace()` calls (review feedback from @spiros132)

## [3.7.0] - 2026-05-17

### Features

**Hyprland Lua config support (`hyprland.lua`)**
- Hyprland 0.55+ replaces hyprlang `.conf` with a Lua config. Added a second Hyprland parsing tor that queries `hyprctl binds -j` for the authoritative, already-evaluated bind list — correctly handling `require()`, `for` loops, and multi-key chords that cannot be recovered by static text parsing
- Categories are recovered by lightly scanning `hyprland.lua` (and its `require()` modules) for `-- N. NAME` headers and `description = "..."` literals, with a prefix heuristic for loop-generated binds (e.g. `"Workspace " .. i`)
- Parser mode setting `auto` / `lua` / `conf`: `auto` uses the Lua tor when `hyprland.lua` exists, otherwise the existing `.conf` parser
- The legacy hyprlang `.conf` parser is **kept unchanged as a fallback** for users still on hyprlang configs

**Add description / hide binds without a description**
- Binds with no description are surfaced in a dedicated "Without Description" section instead of being dropped
- Each undescribed bind can be given a custom description inline, or hidden, directly from the panel
- Overrides are keyed by a stable bind identity (`submap|modmask|key|flags|dispatcher`) that excludes the unstable `__lua` registry ref, so they survive Hyprland restarts
- New settings: `showUndescribedBinds`, an override summary, "Restore hidden" and "Clear all overrides" actions

**`refresh` IPC**
- Added `refresh` to the plugin IPC handler so the cheatsheet can be re-parsed from a keybind, e.g. `qs ipc call plugin:keybind-cheatsheet refresh`

### Bug Fixes

- Fixed a `text` binding loop on the window-height settings input (now seeded once via `Component.onCompleted`)
- Replaced hardcoded `font.pointSize` in bind rows with `Style.fontSizeXS`

### Notes

- This release bundles the color-customization, MangoWC-support and Niri parser work previously tracked separately (see the 3.5.0–3.6.2 entries below) together with the Hyprland Lua support, shipped as a single 3.7.0 release.

---

## [3.6.2] - 2026-04-29

### i18n

- Translate "no description" fallback label for undescribed MangoWC binds — was hardcoded `"(no description)"`, now uses `panel.no-description` translation key across all 20 locale files (addresses review feedback from @spiros132 on PR #725).

---

## [3.6.1] - 2026-04-26

### MangoWC Parser Regression Fixes

Addresses review feedback on PR #725 from @countgitmick.

- **XF86 media keys now formatted:** `formatMangoKeyCombo` calls `formatSpecialKey`, so `XF86AudioRaiseVolume` renders as "Vol Up", `XF86AudioMute` as "Mute", brightness keys as "Bright Up/Down", etc.
- **Stray `#` comments no longer become categories:** `extractMangoCategory` restored filters — length cap of 100 chars, horizontal-rule strip (`────`, `====`, `----`), numbered-list extraction (`1. Foo` → `Foo`), paren/bracket continuation reject, flow-arrow reject (`→`, `->`, `=>`), keyword-prefixed notes reject (TODO/FIXME/NOTE/HACK/XXX/BUG/WIP).
- **Per-bind `#"description"` suffix preserved:** `findMangoUnquotedComment` skips past `#"`, and `parseMangoConfig` extracts the trailing quoted description so `bind=SUPER,T,exec,foo #"Open terminal"` keeps "Open terminal" as the rendered description.
- **Modifier aliases:** `LOGO` (= SUPER) and `MOD1` (= ALT) are now recognized as valid Mango modifier tokens.
- **Default category localized:** the fallback category for `bind=`/`axisbind=`/`mousebind=` lines without a preceding `# Category` now uses `pluginApi.tr("default-category")` instead of hardcoded "General"/"Mouse".
- **Category detection actually runs now:** moved category extraction into the pure-comment branch so `# Title` lines actually update `currentCategory` (previously dead code path).

---

## [3.5.0] - 2026-04-21

### New Features

**Full Per-Category Color Customization**
- Added background and text color pickers for every key category: `Super`, `Ctrl`, `Shift`, `Alt`, `XF86`, `Print`, numeric, mouse, and default letter keys — plus the description text color
- 9 new `keyText*` settings (`keyTextSuper`, `keyTextCtrl`, …) let the label text of every category be themed independently of the background
- `keyColorSuper`, `keyColorCtrl`, `keyColorShift` use an empty-string sentinel to mean "use Material theme accent" (`mPrimary` / `mSecondary` / `mTertiary`), so themed setups remain untouched unless the user deliberately overrides

**Redesigned Color Picker UI**
- Two-pill layout per category: left pill previews the background, right pill previews the label text on that background
- Single click anywhere on a pill opens `NColorPickerDialog`
- Pencil-icon edit affordance removed — the entire pill is the control
- Per-row reset button clears the override and restores the theme default
- New "Reset all colors" button zeroes out all 20+ color overrides in one action

**Clipboard Quick-Paste**
- When a valid `#RRGGBB` or `#RRGGBBAA` hex is detected in the clipboard (via `wl-paste`, polled every 1500 ms), a paste icon appears inside each pill
- Clicking the icon applies the clipboard hex to that pill immediately, no picker dialog required
- A new hint row above the color pickers tells the user about this behavior

**Live Preview + Revert on Cancel**
- Color changes are reflected in the preview row immediately via `_applyPreview(key, value)` instead of only after Save
- A snapshot is taken on `Component.onCompleted`; closing the Settings panel without clicking Save restores the snapshot in `Component.onDestruction`, so cancelled edits are truly reverted

### Bug Fixes

**Ctrl / Shift now actually customizable**
- Previously `keyColorCtrl` / `keyColorShift` could not be overridden; the panel always fell back to `Color.mPrimaryContainer` (which does not exist on this shell build). Fixed by consistently honoring the empty-string override sentinel and falling back to `mPrimary` / `mSecondary` / `mTertiary`
- Removed stray references to `Color.mPrimaryContainer` that produced undefined colors at runtime

**Panel opacity now matches other plugins**
- Switched the Panel from painting its own opaque background to the standard plugin panel-in-panel pattern used by `tailscale` and `hello-world`, so the keybind panel now inherits the user's shell opacity/blur settings correctly

### Code Quality

**Component extraction**
- Extracted `ColorPill.qml` (single background/text pill with clipboard paste + picker dialog) and `ColorPairRow.qml` (label + bg pill + text pill + reset) from the Settings surface. Settings.qml is now noticeably smaller and each pill row is a single declarative `ColorPairRow { ... }`

**Edit-copy discipline + i18n**
- Extended the edit-copy pattern to all 20+ color/text settings — `valueKeyColor*` / `valueKeyText*` properties are the source of truth during edit, `saveSettings()` writes them into `pluginSettings` and calls `pluginApi.saveSettings()`
- The hardcoded `qs … ipc call …` example now lives in `settings.keybind-ipc-command` so it is translation-system-backed like every other string
- Removed the last `|| "auto"` fallback strings in `ColorPairRow.qml`; the translation system handles missing keys
- New i18n keys `panel.search-placeholder`, `settings.color-auto`, `settings.color-paste-hint`, `settings.keybind-ipc-command` localized across all 20 supported languages

**Cleanup**
- Timer and Process objects (clipboard poll + `wl-paste` Process) are stopped/terminated in `Component.onDestruction`
- Unified empty-string-or-hex property types for overrides (`string` for overrides, `color` for non-optional defaults), preventing QML's implicit `color` coercion from turning `""` into `#000000`

### Manifest

- Version bumped to `3.5.0`
- `metadata.defaultSettings` gains 20+ new color defaults covering every per-category override plus `keyLabelColor` and `descriptionTextColor`
- `windowHeight` default corrected from `0` to `850` so the manual-height branch has a sensible initial value
- Tags extended with `Hyprland` and `Niri` for plugin-catalog search filtering

---

## [3.4.0] - 2026-04-07

### Bug Fixes

**Settings unreachable from panel button**
- Fixed critical bug where clicking the settings button (top-right of the keybind panel) blocked all input in the settings window
- The panel now closes before opening settings, preventing the open panel from intercepting mouse events
- Reported by Discord users: editing width/height was impossible when settings were opened this way

**Settings not saved when opened from panel**
- Fixed settings changes being silently discarded when the settings window was opened via the panel button
- `saveSettings()` was declared on an inner `ColumnLayout` instead of the root `Item`, making it invisible to the Noctalia shell
- With the previous direct-mutation approach this went unnoticed; after switching to the edit-copy pattern saves now work correctly from all entry points

### Code Quality

**Settings: edit-copy pattern**
- Replaced direct `pluginSettings` mutation in `onTextChanged` handlers with proper edit-copy properties (`editWindowWidth`, `editWindowHeight`, `editAutoHeight`, `editColumnCount`, `editModKeyVariable`, `editHyprlandConfigPath`, `editNiriConfigPath`)
- Changes are committed to `pluginSettings` only when the user clicks Save, matching Noctalia plugin conventions

**i18n: corrected structure**
- Removed `"keybind-cheatsheet"` top-level wrapper from all 20 language JSON files
- Removed `"keybind-cheatsheet."` prefix from all 50 `tr()` calls across all QML files
- Structure now matches the Noctalia plugin i18n specification

**Removed dead code**
- Deleted unused `parseNiriConfig()` function (118 lines) superseded by `parseNiriFileContent()` in v3.1.0

**Shell injection hardening**
- Glob expansion in config path resolution now passes user-provided patterns as positional shell arguments (`$1`) instead of string-concatenating them into the shell command, preventing potential injection via crafted config path values

**resizeTimer: semantic popup detection**
- Replaced fragile `toString()` string matching (`"Popup_QMLTYPE"`, `"NPluginSettingsPopup"`) with a semantic check (`typeof obj.modal === "boolean"`) that works with any QML `Popup` subclass

**Named key badge colors**
- Extracted hardcoded hex colors in `getKeyColor()` into named `readonly property color` constants (`keyColorAlt`, `keyColorXF86`, `keyColorPrint`, `keyColorNumeric`, `keyColorMouse`)

### Manifest

- Added missing `repository` field
- Added tags: `System`, `Indicator` (alongside existing `Bar`, `Panel`)

---

## [3.2.2] - 2026-02-08

### Bug Fixes

**Hyprland Parser - No Category Handling**
- Fixed parser crash when Hyprland config has no category headers (`# 1. Category Name`)
- Parser now creates default "Keybinds" category for configs without categories
- Default category name is fully translatable via i18n system
- Prevents keybind loss for users who don't organize their configs with categories

### Translations

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

### Code Quality

**Memory Leak Prevention**
- Added recursion limit tracking for parser (`hasCategories` flag)
- Improved parser robustness and error handling
- Better fallback behavior for edge cases

---

## [3.1.2] - 2026-02-08

### Translations

- Added german translations for the `error` keys

## [3.1.1] - 2026-02-03

### Smart Caching

**Compositor Change Detection**
- Plugin now detects when compositor changes (e.g., switching from Hyprland to Niri)
- Automatically re-parses config only when compositor differs from cached data
- Instant panel opening when using same compositor (uses cache)
- Saves detected compositor in settings for comparison

### Bug Fixes

**Improved Niri Parser**
- Fixed multiline bind parsing - handles binds that span multiple lines
- Added `spawn-sh` action support for shell command spawning
- Added `move-column-to-workspace` and `move-window-to-workspace` action categories
- Better handling of complex Niri config structures

**Better Error Messages**
- User-friendly messages for unsupported compositors (Sway, LabWC, MangoWC)
- Each compositor shows specific explanation why it's not supported
- All error messages are translatable via i18n

### Documentation

**README Updates**
- Fixed IPC command syntax in examples
- Updated keybind format examples to use `$mainMod` instead of `$mod`
- Clarified configuration file paths and formats

---

## [3.1.0] - 2026-02-03

### New Features

**Niri Support**
- Full Niri compositor support with KDL config parsing
- Recursive file parsing with `source` directive support
- Automatic action categorization
- Multiline bind support

**Recursive Config Parsing**
- Both Hyprland and Niri now support recursive file includes
- Memory leak prevention with recursion limits
- Glob pattern support for bulk file imports

### Improvements

**Better Error Handling**
- Graceful fallback for unsupported compositors
- User-friendly error messages
- Translation support for all error states

---

## [3.0.0] - 2026-01-30

### Initial Release

**Core Features**
- Hyprland keybind parsing
- Category organization
- Multi-language support
- Bar widget integration
- Settings UI
