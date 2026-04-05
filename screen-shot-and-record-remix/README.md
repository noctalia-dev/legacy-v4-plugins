# Screenshot, OCR & Record Remix


This plugin lets you take screenshots, perform text recognition (OCR), use Google Lens on screen regions, and record your screen. It now works on Sway and Niri, in addition to Hyprland, with all Hyprland-only code removed for maximum compatibility.

**Note:** This remix specifically removes the Hyprland-only window detection code. All screenshot and recording actions are now based on region selection, ensuring full support for Sway and Niri as well as Hyprland.

**Original author:** Pulsar  
**Remix author:** Mathew-D

## What's Changed from the Original
- **Removed window detection**: No more `hyprctl` calls or Hyprland-specific APIs
- **Region-based selection only**: All actions (screenshot, OCR, recording) use manual region selection

## Features
- Select a region of the screen to screenshot, copy, or edit
- OCR: recognize text in a selected region and copy to clipboard
- Google Lens: search a selected region with Google Lens
- Screen recording: record a region of your screen (with or without audio)
- Choose where screenshots and recordings are saved (customizable save paths)
- Works on Sway, Niri, and Hyprland

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
