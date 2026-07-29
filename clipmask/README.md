# ClipMask

A Noctalia v4 plugin for **privacy-first clipboard management** with **Vim-inspired navigation**.
Entries are **masked with dots (••••)** by default — only revealed on demand.

> **Best practice for clipboard security:** Never leave sensitive data visible on screen.
> ClipMask keeps your clipboard contents hidden until you explicitly choose to reveal them.

---

## Features

- 🔒 **Security-first** — entries shown as `••••••••` by default, zero visible secrets
- 👁 **Reveal on demand** — `Ctrl+A` cycles: fully masked → first 3 chars → fully revealed
- ⌨️ **Vim-style navigation** — `j`/`k` to move, `/` to search, `d` to delete
- 🖼️ **Image support** — image entries show thumbnails with an **IMG** badge
- 🔍 **Live search** — press `/` to filter entries in real-time
- 📋 **Uses cliphist** — integrates with your existing clipboard history
- 🎨 **Full Noctalia theming** — respects your colors and styles

## Why ClipMask?

### 🛡️ Security & Privacy

Clipboard content is one of the most exposed attack surfaces on a desktop.
Passwords, tokens, private keys, and personal messages all pass through the clipboard.

**ClipMask** follows the principle of **least visibility**:
- Entries are masked **by default** — no accidental exposure
- Reveal only what you need, when you need it
- Partial reveal mode shows just the first 3 characters — enough to identify an entry

### 🎯 Best Practices for Clipboard Security

1. **Never leave clipboard content visible** — masked entries prevent shoulder surfing
2. **Use partial reveal** — when scanning entries, first 3 chars + dots is enough to identify
3. **Auto-refresh** — panel always shows latest history
4. **Delete sensitive entries** — press `d` to remove any entry from history
5. **Search don't scroll** — use `/` to find entries without revealing everything

### 💡 Use Cases

| Scenario | Why ClipMask helps |
|----------|-------------------|
| **Streaming / Screen sharing** | Viewers can't accidentally see your clipboard history |
| **Public presentations** | Keep API keys, passwords, and tokens hidden |
| **Coffee shop / open office** | Shoulder surfers can't read your clipboard |
| **Developer workflow** | Quickly find and paste code snippets without exposing everything |
| **Password manager integration** | Copy passwords safely, they stay masked in history |

### ⌨️ Vim-Inspired Navigation

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate entries |
| `/` | Enter search mode |
| `Ctrl+J` / `Ctrl+K` | Navigate while searching |
| `Esc` / `Ctrl+E` | Exit search mode |
| `Ctrl+A` | Cycle mask: masked → partial → revealed |
| `Enter` | Copy selected entry |
| `d` / `Del` | Delete entry from history |
| `Esc` / `Ctrl+E` | Close panel / exit search |
| `Backspace` | Delete last character in search |

---

## Installation

1. Make sure the plugin is in your plugins directory:
   ```
   ~/.config/noctalia/plugins/clipmask/
   ```

2. Open **Noctalia Settings → Plugins**

3. Find **ClipMask** in the list and toggle it **ON**

4. Add the bar widget:
   - Right-click your bar → **Add widget**
   - Search for "ClipMask" or scroll to find the eye-off icon
   - Click to add it

5. Click the bar widget to open the masked clipboard viewer

## Requirements

- `cliphist` — the clipboard history daemon
- `wl-clipboard` — Wayland clipboard utilities

Install on Arch:
```bash
sudo pacman -S cliphist wl-clipboard
```

Make sure cliphist is running:
```bash
wl-paste --type text --watch cliphist store &
wl-paste --type image/png --watch cliphist store &
```

## IPC Commands

```bash
# Toggle the ClipMask panel
qs -c noctalia-shell ipc call plugin:clipmask "toggle"

# Open panel
qs -c noctalia-shell ipc call plugin:clipmask "open"

# Close panel
qs -c noctalia-shell ipc call plugin:clipmask "close"
```

## How it works

- `Main.qml` registers IPC handlers for the plugin
- `Panel.qml` runs `cliphist list` via Quickshell's `Process` component
- Each entry is parsed from the tab-delimited output and rendered in a `ListView`
- Text entries are masked with `•` characters until explicitly revealed
- Image entries are decoded via `cliphist decode | base64` and shown as thumbnails
- Copying pipes through `cliphist decode | wl-copy` for reliable binary/text handling

## Credits

- **Author:** x0d7x
- **Built for:** Noctalia v4 (Quickshell-based)
