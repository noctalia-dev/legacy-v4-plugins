#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

GROUP="vantage"
RULE_SRC="$SCRIPT_DIR/99-vantage.rules"
RULE_DST="/etc/udev/rules.d/99-vantage.rules"

# ---- checks ----
if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo"
  exit 1
fi

TARGET_USER=${SUDO_USER:-$1}

if [ -z "$TARGET_USER" ]; then
  echo "Usage: sudo ./setup.sh OR ./setup.sh <username>"
  exit 1
fi

if [ ! -f "$RULE_SRC" ]; then
  echo "Error: $RULE_SRC not found in current directory"
  exit 1
fi

echo "→ Using user: $TARGET_USER"

# ---- create group ----
if ! getent group "$GROUP" >/dev/null; then
  echo "→ Creating group: $GROUP"
  groupadd "$GROUP"
fi

# ---- add user ----
echo "→ Adding user to group"
usermod -aG "$GROUP" "$TARGET_USER"

# ---- install rule ----
echo "→ Installing udev rule"
install -Dm644 "$RULE_SRC" "$RULE_DST"

# ---- reload udev ----
echo "→ Reloading udev rules"
udevadm control --reload-rules
udevadm trigger

echo ""
echo "✅ Setup complete"
echo "⚠️  Log out and log back in (or reboot) for group changes to apply"
