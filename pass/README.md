# Password Store

Search and copy passwords and OTP codes from [pass](https://www.passwordstore.org/) directly in the Noctalia launcher.

## Features

- **Password search** — type `pass <query>` to fuzzy search your password store and copy a password to clipboard
- **OTP search** — type `po <query>` to fuzzy search your password store and copy a TOTP code to clipboard
- **Fuzzy matching** — uses Noctalia's built-in FuzzySort engine, consistent with the app launcher
- **Clipboard safety** — passwords and OTP codes are cleared from clipboard after 45 seconds (pass default)
- **XDG-aware** — respects `$PASSWORD_STORE_DIR` with fallback to `~/.password-store`

## Requirements

- **System packages:** `pass`, `pass-otp`
- **Wayland clipboard:** `wl-clipboard` (for `wl-copy` support — recommended on Wayland)

### Installing dependencies

```bash
# Arch Linux / Manjaro
sudo pacman -S pass pass-otp wl-clipboard

# Debian / Ubuntu
sudo apt install pass pass-extension-otp wl-clipboard

# Fedora
sudo dnf install pass pass-otp wl-clipboard
```

## Installation

### Manual Installation

```bash
git clone https://github.com/noctalia-dev/noctalia-plugins ~/.config/noctalia/plugins/pass
```

Then restart Noctalia:

```bash
qs kill -c noctalia-shell && qs -c noctalia-shell -d
```

## Usage

Open the launcher (`Alt+Space` by default) and type:

| Prefix | Action |
|--------|--------|
| `pass <query>` | Fuzzy search all pass entries — press Enter to copy the password |
| `po <query>` | Fuzzy search all pass entries — press Enter to copy the TOTP code |

### Examples

```
pass kortechs/aws          → finds kortechs/aws/bojan@kortechs.io
pass aws bojan             → finds any entry matching both "aws" and "bojan"
po github                  → finds OTP entry for github, copies the current TOTP code
```

Selecting an entry runs `pass -c <entry>` or `pass otp -c <entry>` respectively. If your GPG key requires a passphrase, a pinentry dialog will appear.

## File Structure

```
pass/
├── manifest.json   # Plugin metadata
├── Main.qml        # Launcher provider — search and activation logic
└── README.md       # This file
```

## Troubleshooting

**No results appear**
- Make sure `pass` is installed and `~/.password-store` exists (or `$PASSWORD_STORE_DIR` is set)
- Restart Noctalia after installing the plugin

**OTP copy fails silently**
- Verify `pass-otp` is installed: `pass otp --help`
- Test manually in a terminal: `pass otp -c <entry>`

**Password not copied on Wayland**
- Install `wl-clipboard`: `sudo pacman -S wl-clipboard`
- `pass` detects Wayland via `$WAYLAND_DISPLAY` and uses `wl-copy` automatically

## License

MIT

## Author

**Bojan Jovanovic** - [github.com/virogenesis](https://github.com/virogenesis)
