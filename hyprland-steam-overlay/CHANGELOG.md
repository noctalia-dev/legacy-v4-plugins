# Changelog

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
