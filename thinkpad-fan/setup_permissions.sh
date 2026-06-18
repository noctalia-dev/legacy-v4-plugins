#!/bin/bash

echo "=== ThinkPad ACPI Fan Permissions Configuration ==="

# 1. Enable manual control in the kernel module if not already enabled
if [ -f /sys/module/thinkpad_acpi/parameters/fan_control ]; then
    STATUS=$(cat /sys/module/thinkpad_acpi/parameters/fan_control)
    if [ "$STATUS" = "N" ]; then
        echo "[*] Enabling fan_control=1 parameter in modprobe.d..."
        echo "options thinkpad_acpi fan_control=1" | sudo tee /etc/modprobe.d/thinkpad_acpi.conf
        echo "[!] Kernel module requires a reboot (or reload) to apply fan_control=1."
    else
        echo "[✔] Fan control is already enabled in the kernel."
    fi
fi

# 2. Create the permanent udev rule to apply chmod on every boot
echo "[*] Creating udev rule in /etc/udev/rules.d/99-thinkpad-fan.rules..."
echo 'SUBSYSTEM=="platform", DRIVERS=="thinkpad_acpi", RUN+="/bin/chmod 0666 /proc/acpi/ibm/fan"' | sudo tee /etc/udev/rules.d/99-thinkpad-fan.rules

# 3. Reload udev rules to register the changes
echo "[*] Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

# 4. Force permissions immediately for the current session (avoids immediate reboot)
if [ -f /proc/acpi/ibm/fan ]; then
    echo "[*] Applying immediate chmod 0666 to /proc/acpi/ibm/fan..."
    sudo chmod 0666 /proc/acpi/ibm/fan
    
    # Final verification test running as normal user
    echo "[*] Verifying write permissions (testing write command without sudo)..."
    if echo level auto > /proc/acpi/ibm/fan 2>/dev/null; then
        echo "[✔] Success! You can now control the fan without root privileges."
    else
        echo "[❌] Error: File still returns Permission Denied. If you had to create the modprobe.d file, a system reboot might be required."
    fi
else
    echo "[❌] Error: /proc/acpi/ibm/fan not found. Is the thinkpad_acpi module loaded?"
fi