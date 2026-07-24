# Screenshot Plugin

**This plugin currently supports Sway, Hyprland, MangoWM and Niri. Window selection is available in Sway, Hyprland and Niri. MangoWM/MangoWC only supports region selection.  

> **Niri Prerequisites and Limitations:** Window detection requires Niri with [PR #3305](https://github.com/YaLTeR/niri/pull/3305) (not yet merged). Due to f64 rounding in the PR, window borders may have up to 1px of offset. Niri builds without `window-geometries` (from #3305) will silently disable window detection — screenshot capture still works normally.

This plugin implements screen region selection, window selection, text recognition, Google Lens, and screen recording functionality based on Quickshell.

## Installation

Install from the plugin marketplace. You also need to install the following packages:

| Feature           | Packages                                                                 |
|-------------------|--------------------------------------------------------------------------|
| Screenshot        | `grim`, `wl-copy`, `satty`/`swappy`, `magick` (ImageMagick, optional)    |
| Text Recognition  | `tesseract` (plus language packs, e.g. `tesseract-data-chi_sim`)         |
| Google Lens       | `xdg-open`, `jq`                                                         |
| Screen Recording  | `wf-recorder`                

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
For screen recording, triggering it again will stop the recording, saved to `recordingSavePath/recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4`.

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
You can configure these options in the plugin settings:

| Name                   | Default                        | Description                                      |
|------------------------|--------------------------------|--------------------------------------------------|
| `enableCross`          | `true`                         | Enable crosshair overlay for region selection     |
| `enableWindowsSelection` | `true`                       | Enable window detection and click-to-window region selection on supported compositors |
| `screenshotEditor`     | `swappy`                       | Screenshot editor tool (`swappy` or `satty`)      |
| `keepSourceScreenshot` | `false`                        | Keep the *_source.png file after editing          |
| `savePath`             | `~/Pictures/Screenshots`        | Folder for saving screenshots                     |
| `recordingSavePath`    | `~/Videos`                     | Folder for saving screen recordings               |
| `recordingNotifications`| `true`                        | Show notifications for recording events           |


## Acknowledgements
Sway and MangoWM support added by: Mathew-D
Thanks to [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) for inspiration and the `record.sh` script.
