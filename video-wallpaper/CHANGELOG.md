# Changelog

Here I'll try to document all changes for the video-wallpaper plugin.

## 1.2.1 - 2026-02-10

- feat: Added support for orientation with mpvpaper.
- fix: Fixed a bug where color gen wasn't started correctly with the enabled toggle.

## 1.2.0 - 2026-02-09

- feat: Added support to use mpvpaper as a backend renderer.
- feat: Added advanced settings page for more advanced settings, more specified to the renderer.
- feat: Added the ability to have custom times for automatic wallpaper updates.
- fix: Fixed thumbnails with weird names not being supported.
- fix: Fixed warnings that might appear in the logs because of wrongly created variables.

## 1.1.3 - 2026-02-08

- feat: Added IPC call to open the panel.
- fix: Rewrote a lot of the backend code to make it more stable.
- fix: Fixed a lot of bugs.

## 1.1.2 - 2026-02-07

- i18n: Added german translations.

## 1.1.1 - 2026-02-07

- fix: Fixed some bugs with the color generation and the thumbnail generation.

## 1.1.0 - 2026-02-07

- feat: Added control of the fill mode.
- feat: Added control of the orientation.
- feat: Added settings button in the bar widget.

## 1.0.0 - Initial commit

- feat: Moved over from mpvpaper to this plugin.
- feat: Added a bar widget.
- feat: Added a panel.
- feat: Added a settings menu.
- feat: Added support for automatic wallpaper change.
- feat: Added color generation based on thumbnails.
- feat: Added the ability to control the volume of the video wallpaper, both with IPC and from the settings.
- feat: Added the ability to manipulate both audio and play/pause.
- feat: Added so that a user can use both the video and the picture default wallpaper.
- feat: Added thumbnail generation for all the videos inside of the wallpaper folder.
- feat: Added IPC handlers for toggling, setting and getting active state.
- feat: Added IPC handler for getting the current wallpaper.
