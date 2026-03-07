# Screenshot Plugin

**This plugin currently only supports Hyprland. Window selection and record may not be available on other window managers, and may cause quickshell crash in Niri.**

This plugin implements screen region selection, window selection, text recognition, Google Lens, and screen recording functionality based on Quickshell.

## Installation

Install from the plugin marketplace. You also need to install the following packages:

| Feature | Packages |
| :-: | :-: |
| Screenshot | `grim` (screen capture), `magick` (ImageMagick), `wl-copy`, `satty`/`swappy` (editor) |
| Text Recognition | `tesseract` (OCR, also install language packages, e.g., `tesseract-data-chi_sim`) |
| Google Lens | `xdg-open`, `jq` |
| Screen Recording | `wf-recorder` |

## Usage

First, you need to disable animations for windows with the class name `noctalia-shell:regionSelector` in your window manager configuration file. Taking Hyprland as an example:

```txt
layerrule = match:namespace noctalia-shell:regionSelector, no_anim on
```

All functions can be accessed through the status bar buttons. However, the author recommends using keyboard shortcuts via IPC binding to avoid the status bar menu blocking the screen.

For screenshot functionality, left-click selection copies to clipboard, right-click opens the editor interface.
For other functions, left and right clicks have the same effect.
For OCR functionality, text recognition is performed after selection and the result is copied to the clipboard.
For Google Lens, it directly opens the Google Lens webpage.
For screen recording, triggering it again will stop the recording, saved to `$HOME/Videos/recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4`.

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

This plugin has the following configuration options::

| Name | Default | Description |
| :-: | :-: | :-: |
| `enableWindowsSelection` | `true` | Enable window selection (Hyprland only) |
| `enableCross` | `true` | Enable crosshair overlay |
| `screenshotEditor` | `swappy` | Screenshot editor tool, possible values: `swappy` and `satty` |

## Acknowledgements

Thanks to [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) for inspiration and the `record.sh` script.
