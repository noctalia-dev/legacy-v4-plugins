# Changelog

Here I'll try to document all changes for the mpvpaper plugin.

## 1.6.1 - 2026-02-07

- feat: Added the ability to set the fill mode.
- feat: Added widget setting in the context menu of bar widget.

## 1.6.0 - 2026-02-06

- feat: Added the ability to set the mpv profile, there is a fast profile for better optimization.
- feat: Added the ability to enable hardware acceleration for less cpu usage.
- feat: Added support for setting up automatic wallpaper change.
- fix: Fixed so that the thumbnails don't regenerate every time the shell is restarted.
- fix: Reformatted a lot of the code to make the code more readable.

## 1.5.0 - 2026-02-04

- feat: Added the ability to control the volume of the video wallpaper, both with IPC and from the settings.
- fix: Fixed the settings to make it more clear what is what.
- fix: Added specific tool row for both the settings and the panel.
- fix: Added some more comments and made the code more readable.

## 1.4.0 - 2026-02-03

- feat: Added the ability to manipulate both audio and play/pause.
- feat: Added so that a user can use both the video and the picture default wallpaper.
- fix: Fixed a bug where the thumbnail folder wasn't created correctly on startup.
- fix: Fixed UI issues.
- fix: Fixed other minor bugs.

## 1.3.0 - 2026-02-02

- feat: Added color generation by utilizing the thumbnails.
- feat: Added a context menu for the bar widget, for easier toggling of the wallpaper.
- fix: Fixed some bugs that gave a lot of warnings to the debug logs.

## 1.2.0 - 2026-02-01

- feat: Added thumbnail generation for all the videos inside of the wallpaper folder, scaled down to save space.
- feat: Added a panel for selecting a wallpaper with some buttons to choose the wallpaper folder, refresh the thumbnails, choose a random wallpaper and clear the current wallpaper.
- feat: Added a bar widget for opening the panel.
- fix: Fixed a bug where if the active setting was turned off and you restarted the computer mpvpaper would start automatically.
- fix: Fixed a bug so that it doesn't try to run the process while current wallpaper is empty.

## 1.1.0 - 2026-01-31

- feat: Added IPC handlers for toggling, setting and getting active state.
- feat: Added IPC handler for getting the current wallpaper.
- fix: Fixed some debug logs for better error debugging.

## [1.0.0] - Initial Release

- feat: Added mpvpaper process creation and destruction
- feat: Added socket for handling changing the wallpaper
- feat: Added settings menu to be able to change current wallpaper, wallpapers folder, mpvpaper socket location and a random and clear button.
