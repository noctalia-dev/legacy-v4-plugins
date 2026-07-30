# Screen Recorder Plugin

Hardware-accelerated screen recording for Noctalia using [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/about/).

## Features

- Hardware-accelerated screen recording
- **Replay buffer** — continuously capture and save the last N seconds on demand
- Configurable bar widget button action
- Customizable video codecs (H264, HEVC, AV1, VP8, VP9, HDR variants)
- Audio recording with multiple sources (system output, microphone, both, or none)
- Adjustable frame rates
- Configurable output resolution (Full HD, WUXGA, 4K, QHD, HD, or original)
- Configurable output directory
- Optional post-recording script
- Optional clipboard copy after recording
- Optional cursor recording
- Multiple quality presets

## Requirements

- **gpu-screen-recorder** - The screen recording backend
  - Install via package manager: `gpu-screen-recorder`
- **xdg-desktop-portal** and a compositor portal backend (wlr/hyprland/gnome etc)

## Installation

1. Copy this plugin to your Noctalia plugins directory:
   ```bash
   cp -r screen-recorder ~/.config/noctalia/plugins/
   ```

2. Add the widget to your bar through Noctalia settings

## Usage

### Bar Widget

- **Left Click**: Configurable action (toggle recording by default)
- **Right Click**: Context menu with recording/replay controls, panel, and settings

### Settings

Configure the plugin through the settings panel:

#### General

- **Button Action**: Action performed when clicking the bar widget (toggle recording, toggle replay, save replay, or open panel)
- **Hide When Inactive**: Hide the bar indicator when not recording
- **Output Folder**: Where recordings will be saved (defaults to `~/Videos`)
- **Post-recording Script**: Optional script to run after a recording saves
- **Show Cursor**: Include mouse cursor in recording
- **Copy to Clipboard**: Automatically copy file after recording
- **Restore Portal Session**: Skip the screen selection dialog on subsequent recordings

#### Video

- **Video Source**: Portal (recommended) or Screen
- **Resolution**: Output resolution (Original, 1920x1080, 1920x1200, 2560x1440, 3840x2160, or 1280x720)
- **Frame Rate**: Target FPS (30, 60, 120, or custom)
- **Rate Control**: QP, VBR, or CBR
- **Video Quality**: Medium, High, Very High, or Ultra (QP and VBR only)
- **Bitrate**: Target bitrate in kbps (CBR only)
- **Video Codec**: H264, HEVC, AV1, VP8, VP9 (+ HDR variants for screen source)
- **Color Range**: Limited (recommended) or Full

#### Audio

- **Audio Source**: None, System Output, Microphone, or Both
- **Audio Codec**: Opus (recommended) or AAC

#### Replay

- **Replay Duration**: Buffer length (15s, 30s, 60s, 2 min, 5 min, or custom)
- **Replay Storage**: Store buffer in RAM (faster, recommended) or Disk
- **Replay Notifications**: Show notifications when the replay buffer starts, stops, or saves
- **Auto-start Replay**: Automatically start the replay buffer when the plugin loads

### IPC Commands

Control the screen recorder via IPC for keybindings or scripts:

```bash
# Toggle recording on/off
qs -c noctalia-shell ipc call plugin:screen-recorder toggleRecording

# Explicitly start recording
qs -c noctalia-shell ipc call plugin:screen-recorder startRecording

# Explicitly stop recording
qs -c noctalia-shell ipc call plugin:screen-recorder stopRecording

# Toggle replay buffer on/off
qs -c noctalia-shell ipc call plugin:screen-recorder toggleReplay

# Start the replay buffer
qs -c noctalia-shell ipc call plugin:screen-recorder startReplay

# Save the replay buffer (last N seconds)
qs -c noctalia-shell ipc call plugin:screen-recorder saveReplay

# Stop the replay buffer
qs -c noctalia-shell ipc call plugin:screen-recorder stopReplay
```

## Video Codecs

- **H264**: Most compatible, good quality, works everywhere
- **HEVC (H.265)**: Better compression than H264, smaller files
- **AV1**: Best compression, smallest files, newer codec
- **VP8/VP9**: Open-source alternatives
- **HDR variants**: Available when using "Screen" source for high dynamic range content

## Audio Sources

- **None**: No audio recording
- **System Output**: Capture system sounds (what you hear)
- **Microphone Input**: Capture from microphone
- **Both**: Record both system and microphone audio

## Troubleshooting

### "Screen recorder not installed" error
Install gpu-screen-recorder:
```bash
# Arch Linux
sudo pacman -S gpu-screen-recorder

# Or via Flatpak
flatpak install com.dec05eba.gpu_screen_recorder
```

### "Desktop portals not running" error
Ensure xdg-desktop-portal and a compositor portal are running:
```bash
# Check if portals are running
pidof xdg-desktop-portal
pidof xdg-desktop-portal-wlr  # or -hyprland, -gnome, -kde

# Install if needed (example for Arch)
sudo pacman -S xdg-desktop-portal xdg-desktop-portal-wlr
```

### Recording fails with artifacts
Try changing the video source from "Portal" to "Screen" in settings.

### Recording stops immediately
- Check if the output directory exists and is writable
- Ensure gpu-screen-recorder has necessary permissions
- Check Noctalia logs for detailed error messages

## License

MIT License

## Credits

- Uses [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/about/) by dec05eba
- Part of the [Noctalia](https://github.com/noctalia-dev/noctalia-shell) plugin ecosystem
