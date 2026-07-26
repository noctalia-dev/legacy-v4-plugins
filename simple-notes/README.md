# Simple Notes Plugin

A simple note-taking plugin for [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell).

## Features
- **Quick Notes**: Create, edit, and delete notes quickly from your desktop panel.
- **Persistence**: Notes are automatically saved.
- **Bar Widget**: Shows an icon and the current note count in your status bar.
- **Customizable Icon**: Change the bar widget icon via the built-in icon picker.
- **Hide Bar Widget**: Toggle to hide the bar widget with a smooth animation.
- **IPC Toggle**: Open/close the notes panel from a terminal command or keybinding.
- **File Export**: Optionally export notes as `.md` files to a directory of your choice.

## Installation

1. Clone or download this repository into your Noctalia plugins directory.
2. Restart Noctalia Shell.
3. Enable "Simple Notes" in the Noctalia settings if not enabled by default.
4. Add the widget to your bar or desktop.

## Usage

- **Bar Widget**: Click the note icon to open the panel.
- **Panel**:
    - Click "New Note" to start writing.
    - Click an existing note to edit it.
    - Use the "Save" button to persist changes.
    - Use the "Delete" button to remove a note.
- **IPC Command**: Toggle the panel from a terminal:
  ```
  qs -c noctalia-shell ipc call plugin:simple-notes togglePanel
  ```
- **File Export**: Set a notes directory in Settings to automatically export each note as a `.md` file when saved.
