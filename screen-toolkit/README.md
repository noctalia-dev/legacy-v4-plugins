# Screen Toolkit

A comprehensive collection of screen utilities for the Noctalia Shell, bundled into a single panel.

## 🛠️ Tools Included

| Tool | Description |
| :--- | :--- |
| **Color Picker** | Pick any pixel and get HEX, RGB, HSV, and HSL values instantly. |
| **Annotate** | Draw on screenshots with pencils, highlight, arrows, shapes, text, and blur effects. |
| **Measure** | Draw lines to measure exact pixel distances on the screen. |
| **Pin** | Capture a region or local image and keep it pinned as a floating, interactive overlay. |
| **Palette** | Extract the dominant color palette from any selected screen region. |
| **OCR** | Extract text from images with support for multiple languages and translation. |
| **QR Scanner** | Scan QR codes and barcodes from any screen area. |
| **Google Lens** | Upload a selected region directly to Google Lens for reverse image search. |
| **Screen Recorder** | Record specific regions as MP4 or GIF (with audio support). |
| **Webcam Mirror** | A floating, resizable webcam preview window with flip and aspect ratio controls. |

---

## 📦 Requirements

Ensure the following dependencies are installed on your system.

### Core Dependencies
*   `grim` (Screenshot)
*   `slurp` (Region selection)
*   `wl-clipboard` (Clipboard)
*   `tesseract` (OCR engine)
*   `imagemagick` (Image processing)
*   `zbar` (QR/Barcode scanning)
*   `curl` (Network uploads)
*   `ffmpeg` (Video processing)
*   `jq` (JSON parsing)
*   `wl-screenrec` (Preferred recorder) or `wf-recorder` (Fallback)

### Optional / Feature-Specific
*   `translate-shell` (Required for OCR translation)
*   `gifski` (High-quality GIF encoding)

---

## 💻 Installation

### Arch Linux
```bash
sudo pacman -S grim slurp wl-clipboard tesseract tesseract-data-eng imagemagick zbar curl translate-shell ffmpeg jq wl-screenrec
yay -S gifski
```

### Debian / Ubuntu
```bash
sudo apt install grim slurp wl-clipboard tesseract-ocr tesseract-ocr-eng imagemagick zbar-tools curl translate-shell ffmpeg jq
cargo install gifski
# Note: wl-screenrec may need to be built from source or substituted with wf-recorder
```

### Fedora
```bash
sudo dnf install grim slurp wl-clipboard tesseract tesseract-langpack-eng ImageMagick zbar curl translate-shell ffmpeg jq wl-screenrec
cargo install gifski
```

### NixOS
Add the following to your `configuration.nix` or `home.nix`:
```nix
environment.systemPackages = with pkgs; [
  grim slurp wl-clipboard tesseract imagemagick zbar curl
  translate-shell wl-screenrec ffmpeg gifski jq
];
# Enable extra languages if needed:
# programs.tesseract.languages = [ "eng" "deu" "fra" ];
```

---

## ⚙️ Compatibility

| Compositor | Status | Notes |
| :--- | :--- | :--- |
| **Hyprland** | ✅ Fully Supported | All features enabled. |
| **Niri** | ✅ Fully Supported | "Annotate Active Window" is disabled (unsupported by Niri API). |
| **Other** | ⚠️ Untested | Basic features should work; compositor-specific tools may fail. |

---
## ⚙️ Settings & Customization

Configure paths and filename formats directly in the plugin settings panel:

| Setting | Description | Default |
| :--- | :--- | :--- |
| **Screenshot Path** | Custom directory for saved screenshots/annotations. Supports `~/` shorthand. | `~/Pictures/Screenshots` |
| **Video Path** | Custom directory for saved recordings. Supports `~/` shorthand. | `~/Videos` |
| **Filename Format** | Template for generated filenames.  | `{prefix}-{date}_{time}` |

The tools automatically add the correct file extensions (like .png .gif or .mp4) 

---
##  IPC Commands

Control Screen Toolkit via scripts or keybindings using:
`qs -c noctalia-shell ipc call plugin:screen-toolkit <command>`

### General Controls
| Command | Description |
| :--- | :--- |
| `toggle` | Open or close the main panel. |


###  Annotation
| Command | Description |
| :--- | :--- |
| `annotate` | Start region annotation. |
| `annotateFullscreen` | Capture and annotate the entire screen. |
| `annotateWindow` | Capture and annotate the active window (Hyprland only). |

### Pin
| Command | Description |
| :--- | :--- |
| `pin` | Pin a selected region to the screen. |
| `pinImage` | Choose an existing image to pin. |

### Recording
| Command | Description |
| :--- | :--- |
| `record` | Start recording a region as GIF. |
| `recordMp4` | Start recording a region as MP4. |
| `recordStop` | Stop the current recording session. |

###  Other
| Command | Description |
| :--- | :--- |
| `mirror` | Toggle the webcam mirror overlay. |
| `colorPicker` | Launch the color picker tool. |
| `ocr` | Run Optical Character Recognition on a region. |
| `qr` | Scan for QR codes or barcodes in a region. |
| `palette` | Extract a color palette from a region. |
| `lens` | Upload a region to Google Lens. |
| `measure` | Start the measurement overlay. |

---

## 📄 License

MIT License

## 🤝 Contributing

Issues and pull requests are welcome at the [Noctalia Plugins Repository](https://github.com/noctalia-dev/noctalia-plugins).
