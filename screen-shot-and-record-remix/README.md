> **Note:** Niri is currently not supported.

# Screenshot, OCR & Record Remix


This plugin lets you take screenshots, perform text recognition (OCR), use Google Lens on screen regions, and record your screen. It supports Sway, Hyprland, and MangoWM/MangoWC (region-only).

**Note:** This remix keeps region-based selection as the default flow, and also supports compositor-based window detection where available.

**Original author:** Pulsar  
**Remix author:** Mathew-D

## What's Changed from the Original
- **Compositor support focus**: Designed for Sway, Hyprland, and MangoWM/MangoWC (region-only)
- **Shared selector architecture**: Common capture/overlay logic with compositor-specific window providers

## Features
- Select a region of the screen to screenshot, copy, or edit
- OCR: recognize text in a selected region and copy to clipboard
- Google Lens: search a selected region with Google Lens
- Screen recording: record a region of your screen (with or without audio)
- Choose where screenshots and recordings are saved (customizable save paths)
- Works on Sway, Hyprland, and MangoWM/MangoWC (region-only)

## Window Detection
On Sway and Hyprland, you can click a window to select it for screenshot or recording. The plugin detects the window's location at the moment you click.

On MangoWM/MangoWC, only region selection is available (window detection is not supported).

This feature can be disabled in the plugin settings ("Enable window detection").

- If another window or overlay is above your target, it will be included in the capture.
- For recording, the region does not follow the window if you move it after starting the recording (it records the area where the window was at the start).

## Installation
Install from the Noctalia plugin marketplace. You will also need these packages:

| Feature           | Packages                                                                 |
|-------------------|--------------------------------------------------------------------------|
| Screenshot        | `grim`, `wl-copy`, `satty`/`swappy`, `magick` (ImageMagick, optional)    |
| Text Recognition  | `tesseract` (plus language packs, e.g. `tesseract-data-chi_sim`)         |
| Google Lens       | `xdg-open`, `jq`                                                         |
| Screen Recording  | `wf-recorder`                                                            |

## Usage
- Use the bar widget or assign keyboard shortcuts via IPC for quick access.
- Left-click to copy a screenshot to clipboard; right-click to open in the editor.
- OCR copies recognized text to clipboard.
- Google Lens opens the selected region in your browser.
- Start/stop screen recording with the same button; recordings are saved to your Videos folder.

## IPC
This plugin provides the following IPC interfaces:

```
target plugin:screen-shot-and-record-remix
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


## Credits
- Original plugin by Pulsar (with permission)
- Remix by Mathew-D

## Acknowledgements
Thanks to [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) for inspiration and the `record.sh` script foundation.

---
