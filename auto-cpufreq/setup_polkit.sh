#!/usr/bin/env bash
# Setup polkit rules for auto-cpufreq plugin
# Run once with: sudo ./setup_polkit.sh
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Error: run as root: sudo ./setup_polkit.sh"
    exit 1
fi

AUTO_CPUFREQ_BIN="$(which auto-cpufreq 2>/dev/null || true)"

if [ -z "$AUTO_CPUFREQ_BIN" ]; then
    echo "Error: auto-cpufreq not found in PATH"
    exit 1
fi

# Resolve real path (handles symlinks like /run/current-system/sw/bin on NixOS)
AUTO_CPUFREQ_REAL="$(readlink -f "$AUTO_CPUFREQ_BIN")"
echo "Found auto-cpufreq at: $AUTO_CPUFREQ_REAL"

# Detect wheel or sudo group
if getent group wheel > /dev/null 2>&1; then
    GROUP="wheel"
elif getent group sudo > /dev/null 2>&1; then
    GROUP="sudo"
else
    echo "Error: neither 'wheel' nor 'sudo' group found"
    exit 1
fi
echo "Using group: $GROUP"

# Write polkit policy
POLICY_DIR="/usr/share/polkit-1/actions"
mkdir -p "$POLICY_DIR"
cat > "$POLICY_DIR/org.auto-cpufreq.pkexec.policy" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.auto-cpufreq.pkexec">
    <description>Run auto-cpufreq</description>
    <message>Authentication is required to run auto-cpufreq</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">$AUTO_CPUFREQ_REAL</annotate>
  </action>
</policyconfig>
EOF
echo "Written: $POLICY_DIR/org.auto-cpufreq.pkexec.policy"

# Write polkit rules (passwordless for wheel/sudo group)
RULES_DIR="/etc/polkit-1/rules.d"
mkdir -p "$RULES_DIR"
cat > "$RULES_DIR/49-auto-cpufreq.rules" << EOF
polkit.addRule(function(action, subject) {
  if (action.id === "org.auto-cpufreq.pkexec" &&
      subject.isInGroup("$GROUP")) {
    return polkit.Result.YES;
  }
});
EOF
echo "Written: $RULES_DIR/49-auto-cpufreq.rules"

# Reload polkit
if systemctl reload polkit 2>/dev/null; then
    echo "polkit reloaded"
else
    echo "Note: restart your session for polkit changes to take effect"
fi

echo "Done! Force override and turbo boost controls are now enabled."
