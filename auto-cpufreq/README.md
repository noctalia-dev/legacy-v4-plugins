# auto-cpufreq

Monitor and control the [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) daemon from your Noctalia bar.

## Features

- **Bar widget** — active CPU governor and turbo state, color-coded by profile
- **Panel** — CPU usage, frequency, temperature, battery status, governor info, force override and turbo boost controls
- **Right-click menu** — quick force/turbo override without opening the panel
- Works with Intel (`intel_pstate`) and AMD (`k10temp`, `amd_pstate`) CPUs
- Reads override state directly from auto-cpufreq pickle files — always in sync with the daemon

## Requirements

- [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) installed with daemon running
- polkit setup for force override / turbo boost controls (see below)

## Polkit Setup

Force override and turbo boost buttons use `pkexec`. Run the setup script once:

```bash
cd ~/.config/noctalia/plugins/auto-cpufreq/
chmod +x setup_polkit.sh
sudo ./setup_polkit.sh
```

### NixOS

```nix
environment.etc."polkit-1/actions/org.auto-cpufreq.pkexec.policy".text = ''
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
        <allow_active>auth_admin_keep</allow_active>
      </defaults>
      <annotate key="org.freedesktop.policykit.exec.path">${pkgs.auto-cpufreq}/bin/auto-cpufreq</annotate>
    </action>
  </policyconfig>
'';
```
