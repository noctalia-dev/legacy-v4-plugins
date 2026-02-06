# Changelog

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
- Corrected Niri spawn command format

### 🌐 Translations

**New Translation Keys**
- `error.unsupported-compositor` - header for unsupported compositor
- `error.sway-not-supported` / `error.sway-detail` - Sway messages
- `error.labwc-not-supported` / `error.labwc-detail` - LabWC messages
- `error.mango-not-supported` / `error.mango-detail` - MangoWC messages
- `error.unknown-compositor` / `error.unknown-detail` - fallback messages

### 📊 Changes Summary

| File | Changes |
|------|---------|
| Main.qml | Added `checkAndParse()`, `getCurrentCompositor()`, `getUnsupportedCompositorMessage()`, improved Niri parser |
| i18n/en.json | Added error message translations |
| README.md | Fixed IPC syntax and keybind examples |

---

## [3.1.0] - 2026-01-30

### 🔧 Code Quality Improvements

**Removed Excessive Logging**
- Removed all `logDebug()`, `logInfo()`, `logWarn()` functions and their calls from Main.qml
- Kept only `logError()` for critical error reporting
- Follows Noctalia plugin guidelines (Logger.e() only for errors)
- Reduces console noise and improves performance

**Removed console.log Statements**
- Removed `console.log` from Panel.qml settings button click handler
- Production-ready code without debug statements

### 🐛 Bug Fixes

**Fixed Refresh Functionality (Critical)**
- **Panel Refresh:** Fixed refresh not working from panel - parser state flags (`parserStarted`, `isCurrentlyParsing`) were not being reset
- **Settings Refresh:** Fixed refresh from settings causing data to disappear - now properly calls IPC refresh instead of just clearing data

**IPC Handler Improvements**
- Added `toggle()` function to IpcHandler for backward compatibility
- Both IPC call formats now work:
  - `plugin:keybind-cheatsheet toggle` (legacy format)
  - `plugin togglePanel keybind-cheatsheet` (built-in Noctalia function)
- Fixed `refresh()` function to properly reset all parser state before re-detecting compositor

### ✨ New Features

**BarWidget Modernization**
- Converted from custom `Rectangle` + `MouseArea` to `NIconButton` component
- Added right-click context menu with:
  - "Open Cheatsheet" - opens the panel
  - "Plugin Settings" - opens plugin settings
- Improved hover states and visual consistency with other Noctalia widgets
- Added proper tooltip with direction based on bar position
- Uses `NPopupContextMenu` for context menu

**Settings Process Management**
- Added `settingsRefreshProcess` for IPC communication
- Added `getConfigName()` helper function for dynamic config detection
- Proper process cleanup on component destruction

### 📊 Changes Summary

| File | Changes |
|------|---------|
| Main.qml | Removed logDebug/logInfo/logWarn (kept logError), added toggle() IPC, fixed refresh() state reset |
| Panel.qml | Removed console.log from settings button |
| Settings.qml | Added IPC refresh process, getConfigName() helper, proper cleanup |
| BarWidget.qml | Converted to NIconButton, added right-click context menu |

### 🔄 Migration Notes

- No breaking changes from v3.0.0
- Keybinds for panel toggle continue to work
- Both old and new IPC formats supported

---

## [3.0.0] - 2026-01-28

### BREAKING CHANGES

**Editor Functionality Removed**
- Removed interactive keybind editor (448 lines of code removed)
- Editor was causing severe memory leaks (500+ MB on 30 launches)
- Focus shifted to read-only keymap display with manual refresh
- Config editing should be done directly in compositor config files

**Manual Refresh Required**
- Removed all automatic config parsing triggers
- Panel no longer parses configs on open (instant display of cached data)
- Added manual "Refresh" button in panel header
- Users must click "Refresh" to update keybinds after config changes

### 🎯 Major Memory Leak Fixes

**CRITICAL: Memory Usage Reduced by 99.6%**
- **Before:** 500+ MB memory leak after 30 plugin launches
- **After:** 2-3 MB variation (normal GC activity)
- **Impact:** Plugin now suitable for long-running desktop sessions

#### High Priority Fixes (Main.qml)
1. **Process Lifecycle Management**
   - Added `Component.onDestruction` to properly cleanup Process objects
   - Implemented `cleanupProcesses()` function to stop all running processes
   - Prevents accumulation of zombie processes and file descriptors

2. **Array/Object Accumulation Prevention**
   - Implemented `clearParsingData()` function to reset parsing state
   - Clear `filesToParse`, `parsedFiles`, `accumulatedLines`, `currentLines`, `collectedBinds`
   - Called after every successful parse completion

3. **Process Buffer Cleanup**
   - Clear `expandedFiles` arrays before each glob operation
   - Enhanced `cleanupProcesses()` to clear process buffers
   - Reset `parseDepthCounter` in `clearParsingData()`

4. **Recursion Depth Limits**
   - Added `maxParseDepth: 50` to prevent infinite recursion
   - Implemented `parseDepthCounter` tracking
   - Added `isCurrentlyParsing` guard to prevent concurrent parsing

5. **Buffer Size Limits**
   - Limited `expandedFiles` arrays to 100 entries
   - Limited config file parsing to 10,000 lines
   - Added warning logs when limits are reached

#### Medium Priority Fixes (Panel.qml)
1. **Debounced Column Updates**
   - Added 100ms debounce timer for `updateColumnItems()` calls
   - Prevents rapid creation/destruction of Loader instances
   - Reduces UI thrashing on rapid setting changes

2. **Explicit Loader Cleanup**
   - Clear `columnItems` array before updating
   - Stop `columnUpdateDebounce` timer in `Component.onDestruction`
   - Stop `refreshProcess` if running on destruction

#### Medium Priority Fixes (Settings.qml)
1. **Timer Cleanup**
   - Stop `resizeTimer` in `Component.onDestruction`
   - Prevents timer firing after component destruction

#### Low Priority Fixes (BarWidget.qml)
1. **Removed Unused Signal Connections**
   - Removed empty `Connections` block to `Color` signals
   - Reduces memory overhead from unused signal handlers

### ✨ New Features

**Panel Header Display**
- Panel now displays compositor-specific title: "Hyprland Keymap" or "Niri Keymap"
- Cleaner, more informative header that shows active compositor

**Manual Refresh Button**
- Added "Refresh" icon button in panel header (next to Settings button)
- Tooltip: "Refresh keybinds from config files"
- Triggers IPC `refresh` command to parse configs on-demand
- Panel opens instantly with cached data, user controls when to refresh

**Dynamic Config Path Detection**
- Settings window now detects config directory via `QS_CONFIG_NAME` environment variable
- Falls back to `"noctalia-shell"` if not set
- Supports custom Noctalia installations

**Improved Settings Window**
- Fixed window width to 600px with proper text wrapping
- All text elements now wrap correctly with `Layout.fillWidth` and `wrapMode: Text.WordWrap`
- Timer-based Popup width override for consistent sizing
- Better UX for long configuration paths and descriptions

### 🔧 Technical Improvements

**Architecture Changes**
- Removed automatic parsing on `Component.onCompleted`
- Removed automatic parsing on `pluginApi` loaded
- Removed `triggerToggle` watcher that caused parsing on panel open
- BarWidget click now only opens panel without triggering parse
- Panel opens instantly (<50ms) showing cached keybinds

**Code Quality**
- Removed 448 lines of editor code (simplified codebase)
- Added comprehensive Component.onDestruction handlers
- Implemented proper resource cleanup patterns
- Added recursion depth and buffer size guards
- Improved error handling and warning logs

**Performance**
- Panel opens instantly with cached data
- No file I/O or process spawning on panel toggle
- Parsing only happens when user explicitly clicks "Refresh"
- Reduced file descriptor churn by 99%+
- Eliminated UI freezing during config parsing

### 🐛 Bug Fixes

**Settings Window**
- Fixed syntax error: `function "noctalia"` → `function getConfigName()`
- Fixed window width not respecting `implicitWidth` setting
- Fixed text overflow and wrapping issues
- Implemented proper parent tree walking for Popup width override

**Config Path Handling**
- Removed hardcoded paths to config directories
- Dynamic detection based on runtime environment
- Works with both standard and custom Noctalia installations

### 📊 Verification Results

All success criteria met:
- ✅ File descriptor count stable after 100 toggle cycles
- ✅ Memory RSS growth < 1MB after 100 toggles (baseline ~520MB)
- ✅ Panel opens instantly with cached data (< 50ms)
- ✅ Manual "Refresh" button visible and functional
- ✅ No "Max parse depth" or "Config file too large" errors
- ✅ Panel opens/closes smoothly without parsing overhead
- ✅ No QML warnings about destroyed objects in console
- ✅ First-time users see empty state with clear "Refresh" button

### 📝 Migration Guide

**For Users Upgrading from v2.x:**

1. **No reinstallation required** - Plugin ID remains `keybind-cheatsheet`
2. **Settings preserved** - All existing settings will be kept
3. **First launch:** Click "Refresh" button in panel to reload keybinds
4. **Normal usage:** Click "Refresh" whenever you edit compositor config files

**IPC Commands (Unchanged):**
```bash
# Toggle panel
qs -c "noctalia-shell" ipc call plugin togglePanel keybind-cheatsheet

# Refresh keybinds
qs -c "noctalia-shell" ipc call plugin:keybind-cheatsheet refresh
```

**Settings Location (Unchanged):**
```bash
~/.local/share/noctalia/plugins/keybind-cheatsheet/
```

**What Changed:**
- Panel header now shows "Hyprland Keymap" or "Niri Keymap" instead of "Keybind Cheatsheet"
- Editor removed (will be replaced by separate "Keymapper" plugin in the future)
- Memory leaks fixed (99.6% reduction)
- Manual refresh required instead of automatic parsing

### ⚠️ Known Limitations

- **No Editor:** Config editing must be done manually in compositor config files
- **Manual Refresh:** Keybinds won't auto-update when config changes (by design)
- **Cache Only:** Panel shows last cached parse result until "Refresh" is clicked
- **First Launch:** Panel will be empty until first manual refresh

### 🔮 Future Improvements

**Keymapper Plugin (Planned)**
- Separate plugin called "Keymapper" is planned to replace the removed editor functionality
- Will provide dedicated, stable keybind editing capabilities
- Focus on proper architecture without memory leaks
- Expected as a future release

**Other Improvements**
- Consider adding file watcher for automatic cache invalidation (optional)
- Explore ListView with cached delegates for further optimization
- Add visual indicator when cached data is stale
- Add "Last Refreshed" timestamp in panel header

---

## [2.1.2] - Previous Release (GitHub)

Last version with editor functionality and automatic parsing. Suffered from severe memory leaks (500+ MB on 30 launches). Not recommended for production use.

### Features (v2.1.2)
- ✅ Interactive keybind editor
- ✅ Automatic config parsing on panel open
- ✅ Multi-screen support
- ❌ Memory leaks causing 500+ MB growth
- ❌ UI freezing during parsing
- ❌ File descriptor accumulation
- ❌ Process zombie accumulation

---

## Links

- **Repository:** https://github.com/noctalia-dev/noctalia-plugins
- **Plugin Path:** `/keybind-cheatsheet` (unchanged)
- **License:** MIT
- **Author:** blacku
- **Minimum Noctalia Version:** 3.6.0
