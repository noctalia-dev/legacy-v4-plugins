# Screenshot Plugin

**This plugin currently supports Hyprland and Sway. Window selection and record may not be available on other window managers, and may cause quickshell crash in Niri.**

This plugin implements screen region selection, window selection, text recognition, Google Lens, and screen recording functionality based on Quickshell.

## Installation

Install from the plugin marketplace. You also need to install the following packages:

| Feature | Packages |
| :-: | :-: |
| Screenshot | `grim` (screen capture), `wl-copy`, `satty`/`swappy` (editor) |
| Text Recognition | `tesseract` (OCR, also install language packages, e.g., `tesseract-data-chi_sim`) |
| Google Lens | `xdg-open`, `jq` |
| Screen Recording | `wf-recorder` |

## Usage

First, you need to disable animations for windows with the class name `noctalia-shell:regionSelector` in your window manager configuration file. Taking Hyprland as an example:

```txt
layerrule = match:namespace noctalia-shell:regionSelector, no_anim on
```

All functions can be accessed through the status bar buttons. However, the author recommends using keyboard shortcuts via IPC binding to avoid the status bar menu blocking the screen.

- Screenshot: select a region. Left-click release copies to clipboard, right-click release opens the editor flow (`swappy`/`satty`).
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
| `enableWindowsSelection` | `true` | Enable window selection (Hyprland only) |
| `enableCross` | `true` | Enable crosshair overlay |
| `screenshotEditor` | `swappy` | Screenshot editor tool, possible values: `swappy` and `satty` |
| `savePath` | `$HOME/Pictures/Screenshots` | Folder where edited screenshots are saved |
| `recordingSavePath` | `$HOME/Videos` | Folder where screen recordings are saved |
| `recordingNotifications` | `true` | Show notifications when recording starts/stops or errors occur |

## Acknowledgements

Thanks to [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) for inspiration and the `record.sh` script.

Contributor: [Mathew-D](https://github.com/Mathew-D) (Sway support, recording/settings improvements).
