# Niri Outputs

A plugin for Noctalia Shell to manage Niri window compositor outputs. Control display scale, mode, transform, and position through an intuitive visual interface.

## Features

- **Bar Widget**: Quick access to display configuration from the bar
- **Control Center Widget**: One-click access to display panel from the control center
- **Panel**: Visual layout preview and detailed output configuration
  - Drag-and-drop display positioning with smart snapping
  - Scale adjustment (0.5x - 2.5x)
  - Rotation (0°, 90°, 180°, 270°)
  - Transform (horizontal/vertical flip)
  - Mode selection (resolution and refresh rate)

## Requirements

- **Niri**: The Niri window compositor must be installed and running
- **Noctalia Shell**: Version 4.1.2 or higher

## Usage

Add the bar widget to your bar or the control center widget to your control center. Click to open the display configuration panel.

### Panel Controls

- **Layout Preview**: Drag display rectangles to reposition them
  - Displays snap to each other's edges (edge snapping)
  - Snap to grid lines (toggle with grid button)
  - Snap to origin (0,0) and center alignment
  - Zoom with mouse wheel, pan with drag
- **Snap Controls**: Toggle grid and display snapping, or reset view
- **Output Settings**: Click the chevron to expand settings for each display:
  - Scale slider (0.5x - 2.5x)
  - Rotation buttons (0°, 90°, 180°, 270°)
  - Flip buttons (Horizontal, Vertical)
  - Mode selection (resolution and refresh rate)

## License

MIT - See plugin license details in manifest.json
