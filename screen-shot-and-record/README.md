# Screenshot Plugin

This plugin implements screen region selection, text recognition, Google Lens, and screen recording functionality based on Quickshell.

Supports: **Niri**, **Sway**, **Hyprland**

## Installation

Install from the plugin marketplace. You also need to install the following packages:

| Feature | Packages |
| :-: | :-: |
| Screenshot | `grim` (screen capture), `wl-copy`, `satty`/`swappy` (editor), `imagemagick` (`magick`/`convert`, used for frozen-frame crop when available) |
| Text Recognition | `tesseract` (OCR, also install language packages, e.g., `tesseract-data-chi_sim`) |
| Google Lens | `xdg-open`, `jq` |
| Screen Recording | `wf-recorder` |

## Usage

If your compositor supports layer animation rules, disable animations for windows with the class name `noctalia-shell:regionSelector` to make region selection feel snappier.

All functions can be accessed through the status bar buttons. However, the author recommends using keyboard shortcuts via IPC binding to avoid the status bar menu blocking the screen.

- Screenshot: select a region. Left-click release copies to clipboard and right-click release opens the editor flow (`swappy`/`satty`).
- OCR: select a region, recognized text is copied to clipboard (with notification on success/failure/no text).
- Google Lens: select a region and open Google Lens for that capture.
- Screen recording: select a region to start recording. Trigger recording again to stop.
- While recording is active, the bar icon turns red.
- Bar icon right-click opens a context menu with Open Settings.

## IPC

This plugin provides the following IPC interfaces:

```txt
target plugin:screen-shot-and-record
  function ocr(): void               // OCR
  function search(): void            // Google Lens
  function record(): void            // Screen recording
  function screenshot(): void        // Screenshot
  function recordsound(): void       // Screen recording (with system audio)
```

## Settings

This plugin has the following configuration options:

| Name | Default | Description |
| :-: | :-: | :-: |
| `enableCross` | `true` | Enable the crosshair cursor and guide lines during region selection |
| `screenshotEditor` | `swappy` | Screenshot editor tool for right-click edit mode, possible values: `swappy` and `satty` |
| `keepSourceScreenshot` | `false` | Keep the temporary `*_source.png` file after saving an edited screenshot |
| `savePath` | `$HOME/Pictures/Screenshots` | Folder where edited screenshots are saved |
| `recordingSavePath` | `$HOME/Videos` | Folder where screen recordings are saved |
| `recordingNotifications` | `true` | Show notifications when recording starts/stops or errors occur |

## Changelog

- v1.0.0: Initial release with Hyprland-only support.
- v1.2.0: Added Niri and Sway Support.  Refactored Hyprland support.

## Acknowledgements

Thanks to [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) for inspiration and the `record.sh` script.

Contributor: [Mathew-D](https://github.com/Mathew-D) (Sway, Niri support, recording/settings improvements).
