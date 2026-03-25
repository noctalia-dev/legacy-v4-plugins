# Screen Toolkit

Screen Toolkit is a Noctalia plugin that groups several screen utilities in one panel.

Tools included:
- Color Picker
- Annotate
- Measure
- Pin
- Palette Extractor
- OCR (with optional translation)
- QR / Barcode Scanner
- Google Lens uploader
- Screen Recorder
- Webcam Mirror

## Features:

Color Picker:
Pick any pixel and get HEX, RGB, HSV, and HSL values. Includes copy buttons and color history.

Annotate:
Select a region and draw on it (pencil, arrows, rectangles, text, blur). Save or copy the result.

Measure:
Draw lines to measure pixel distances on screen.

Pin:
Capture a region and keep it pinned as a floating overlay.

Palette:
Extract dominant colors from a selected region.

OCR:
Select a region and extract text. Optional translation is supported.

QR Scanner:
Scan QR codes or barcodes from a selected region.

Google Lens:
Upload a selected region to Google Lens.

Screen Recorder:
Record a selected region as MP4 or GIF (GIF limited to ~15s). Optional system audio or microphone.

Webcam Mirror:
Floating webcam preview window. Can be moved, resized, and flipped horizontally.

## Requirements:
grim, slurp, wl-clipboard, tesseract, imagemagick, zbar, curl, translate-shell, wf-recorder, ffmpeg

For GIF recording: gifski

## Install packages:

Arch Linux:
```bash
sudo pacman -S grim slurp wl-clipboard tesseract tesseract-data-eng imagemagick zbar curl translate-shell wf-recorder ffmpeg
yay -S gifski
```

Debian / Ubuntu:
```bash
sudo apt install grim slurp wl-clipboard tesseract-ocr tesseract-ocr-eng imagemagick zbar-tools curl translate-shell wf-recorder ffmpeg
cargo install gifski
```

Fedora:
```bash
sudo dnf install grim slurp wl-clipboard tesseract tesseract-langpack-eng ImageMagick zbar curl translate-shell wf-recorder ffmpeg
cargo install gifski
```

openSUSE:
```bash
sudo zypper install grim slurp wl-clipboard tesseract-ocr tesseract-ocr-traineddata-english ImageMagick zbar curl translate-shell wf-recorder ffmpeg
cargo install gifski
```

## Compatibility:
NixOS:
Add to your configuration.nix or home.nix:
```bash
environment.systemPackages = with pkgs; [
  grim slurp wl-clipboard tesseract imagemagick zbar curl
  translate-shell wf-recorder ffmpeg gifski
];
```

For additional OCR languages, use e.g. ```(pkgs.tesseract.override { enableLanguages = [ "eng" "deu" ]; })```

Compatibility:
Tested on Hyprland and Niri.

IPC commands:

## Screen Toolkit Commands

plugin:screen-toolkit

toggle        → Open or close the panel  
colorPicker   → Launch color picker  
ocr           → Run OCR on a region  
qr            → Scan QR / barcode  
lens          → Upload region to Google Lens  
annotate      → Open annotation tool  
measure       → Start measuring overlay  
pin           → Pin a region to screen  
palette       → Extract colors  
record        → Start screen recording  
mirror        → Toggle webcam mirror  

## Example:
```bash
qs -c noctalia-shell ipc call plugin:screen-toolkit toggle
```
