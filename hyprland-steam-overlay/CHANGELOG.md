# Changelog

> **DEPRECATED — not maintained from Hyprland 0.55+.** Hyprland 0.55's move
> from hyprlang to Lua (dispatch parsing + popup/xdg handling changes) makes
> this overlay approach no longer worthwhile. 2.2.0 is the final release; no
> further updates are planned.

## [2.2.0] - 2026-05-17

### Deprecated
- **Plugin is no longer actively maintained as of Hyprland 0.55.** This is
  the final release. It still works on 0.55 via the dual-mode fix below, but
  the Hyprland 0.55 popup/xdg changes also shrink the bar widget's context
  menu (an upstream Hyprland↔Quickshell xdg-popup issue, not fixable cleanly
  at the plugin level), and the special-workspace overlay model no longer
  fits Hyprland's direction. No further updates are planned.

### Fixed
- **Hyprland 0.55+ Lua config compatibility (overlay was completely broken).**
  Hyprland 0.55 deprecated hyprlang in favour of Lua; under a Lua config
  `hyprctl dispatch <name> <args>` is parsed as Lua, so every classic
  dispatch the plugin issued (`togglespecialworkspace`, `movetoworkspacesilent`,
  `setfloating`, `alterzorder`, `resizewindowpixel`, `movewindowpixel`) errored
  out. Window detection still worked, so the overlay toggled but nothing moved.
- Plugin now auto-detects config mode at startup and emits the correct
  `hl.dsp.*` (Lua) or classic (hyprlang) dispatch syntax. Works on both.
- Corrected wrong IPC plugin id in README examples (`plugin:steam-overlay`
  → `plugin:hyprland-steam-overlay`).

### Added
- Optional `useCustomLayout` setting + `steam-layout.lua`: a Hyprland 0.55+
  custom Lua tiling layout that arranges Friends/Main/Chat columns and
  auto-reflows, replacing the floating + pixel-positioning + 150ms polling
  path. Scoped to `special:steam` via a workspace rule; graceful fallback
  when the snippet is absent.

## [2.1.1] - 2026-01-29

### Changed
- Replaced `Rectangle` + `MouseArea` with `NIconButton` component
- Replaced IPC subprocess with direct `pluginApi.mainInstance` call
- Added proper style properties (border, customRadius, hover colors)
- Added null-safe operators for multi-monitor support

### Added
- Context menu with "Toggle Overlay" and "Plugin Settings" options
- Tooltip showing Steam status
- Per-screen styling support

## [2.1.0] - 2026-01-29

### Removed
- **Notification system completely removed** to prevent memory leaks
  - Removed `enableChatNotifications` setting from manifest and Settings UI
  - Removed `hasNewMessages` property and notification dot from BarWidget
  - Removed `chatNotificationTimer` (500ms polling) that caused memory leak
  - Removed `checkNotificationToast` process that continuously checked for Steam chat notifications
  - Removed notification clearing logic from Main.qml

### Fixed
- **Memory leak fix**: Eliminated infinite animation in notification dot (SequentialAnimation with `loops: Animation.Infinite`)
- **Memory leak fix**: Removed 500ms polling timer that ran continuously in background
- **Memory leak fix**: Removed process that repeatedly checked Steam windows for notification toasts
- Syntax error in BarWidget.qml (extra closing braces after notification removal)

### Technical Details
- Notification toast windows are still filtered out (not moved to overlay workspace)
- All timers now have proper stop conditions:
  - `monitorTimer`: Checks if Steam is running (3s interval, manually controlled)
  - `newWindowMonitor`: Only runs when `overlayActive === true` (150ms interval)

## [2.0.2] - Previous version
- Had notification system with memory leaks

## [2.0.0] - Initial release
- Three-window layout (Friends, Main, Chat)
- Percentage-based responsive design
- Special workspace management
