#!/usr/bin/env bash

# ------------------------------
# Battery Threshold Udev Setup
# ------------------------------
# Generates udev rules and sets up permissions for battery control.
# ------------------------------
set -e

RULE_FILE="/etc/udev/rules.d/99-battery-threshold.rules"

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
	echo "Error: This script must be run as root (use sudo)"
	exit 1
fi

# Identify the target user
TARGET_USER=${SUDO_USER:-$1}

if [ -z "$TARGET_USER" ]; then
	echo "Error: No target user specified." >&2
	exit 1
fi

# Create group if it doesn't exist
if ! getent group battery_ctl >/dev/null; then
	echo "Creating battery_ctl group..."
	groupadd battery_ctl
fi

# Grant user group membership
echo "Adding $TARGET_USER to battery_ctl group..."
usermod -aG battery_ctl "$TARGET_USER"

# Generate the udev rules file directly
echo "Generating $RULE_FILE..."
cat <<EOF > "$RULE_FILE"
ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}!="?*", GROUP="battery_ctl", MODE="0664"
ACTION=="add|change", SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_end_threshold}=="?*", GROUP="battery_ctl", MODE="0664"
EOF

# Apply configuration
echo "Reloading udev rules..."
udevadm control --reload-rules && udevadm trigger

echo "Log out and back in for group changes to take effect."
echo "Done!"