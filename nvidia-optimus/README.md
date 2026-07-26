# NVIDIA Optimus — Noctalia plugin

A bar widget + panel for **[Noctalia](https://github.com/noctalia-dev/noctalia-shell)** (Quickshell)
that monitors and controls an **NVIDIA Optimus dGPU on Hyprland**.

The NVIDIA "eye" in your bar is **tinted to your theme** — accent colour when the dGPU is
awake or driving a display, neutral when it's asleep — so at a glance you know whether the
discrete GPU is burning battery. Click it for a panel with a **Battery ⇄ HDMI-Ready toggle**,
live power/temp/VRAM, and a list of exactly what's holding the GPU awake (including
container/root processes that `lsof` can't see).

> **Why this exists:** on Hyprland, an NVIDIA Optimus dGPU often refuses to enter RTD3
> runtime-suspend even when nothing is using it, quietly draining battery — while the HDMI
> port is frequently wired to the dGPU, so you *can't* just disable it. This plugin gives you
> a one-click way to switch between "let the dGPU sleep" and "I need the external display,"
> and shows you the truth about its power state.

## What it does

- **Bar icon**: theme-tinted NVIDIA mark. Accent = dGPU awake, neutral = asleep. Hidden if no
  NVIDIA dGPU is present. Hover for state + mode; click to open the panel.
- **Battery mode**: drops the dGPU from Hyprland's `AQ_DRM_DEVICES` **and** forces the session
  onto mesa-only EGL, so the compositor stops pinning the dGPU — it can finally RTD3-suspend.
  (Excluding it from `AQ_DRM_DEVICES` alone is *not* enough; Hyprland + hyprpaper still open the
  nvidia nodes via EGL.) No external output in this mode.
- **HDMI-Ready mode**: adds the dGPU back so external displays wired to it work.
- **Live panel**: power draw, temperature, utilisation, VRAM, external-display readout, and the
  full list of processes on the GPU (compute *and* graphics, with PID).
- **Zero-overhead monitoring**: the 2-second background poll is **sysfs-only** — it never runs
  `nvidia-smi` or `lspci`, so it can never wake or hold-awake a sleeping dGPU. `nvidia-smi` runs
  only while the panel is open, and only when the GPU is already awake.

## Requirements

- **Hyprland** (uses `AQ_DRM_DEVICES`, an aquamarine/Hyprland env var)
- **Noctalia** ≥ 4.0 (Quickshell)
- An **NVIDIA Optimus laptop** with the proprietary driver and `nvidia-drm.modeset=1`
- Any iGPU (Intel or AMD) — the plugin auto-detects both GPUs from sysfs
- `bash`, `python3`, `lsof`, and (for the panel's live stats) `nvidia-smi`

## Install

```bash
git clone https://github.com/joniler/noctalia-nvidia-optimus \
  ~/.config/noctalia/plugins/nvidia-optimus
```

Then in Noctalia: **Settings → Plugins**, enable **NVIDIA Optimus**, and add its widget to your
bar (**Settings → Bar**). No execute bit needed — the helper scripts run via `bash`.

Optional keybind (Hyprland), matching the panel toggle:

```
bind = $mod CTRL SHIFT, G, exec, qs -c noctalia-shell ipc call nvidiaOptimus toggle
```

## Usage

- **Click the eye** → panel. The header toggle flips **Battery ⇄ HDMI-Ready**.
- Mode changes are written to `~/.config/hypr/env.conf` (backed up next to it) and **apply on the
  next login** — `AQ_DRM_DEVICES` is only read at session start. The panel shows a red
  **"Apply now (log out)"** button while a change is pending.
- IPC: `qs -c noctalia-shell ipc call nvidiaOptimus toggle` (open panel) /
  `... nvidiaOptimus mode` (flip mode).

If your Hyprland env file lives somewhere other than `~/.config/hypr/env.conf`, set
`HYPR_ENV_FILE` in that file's own environment before the plugin's scripts run (or edit the
`env_file` helper in `scripts/gpu-detect.sh`).

## How the modes look in `env.conf`

```ini
# Battery — dGPU sleeps, no HDMI
env = AQ_DRM_DEVICES,/dev/dri/cardN                      # iGPU only
env = __EGL_VENDOR_LIBRARY_FILENAMES,/usr/share/glvnd/egl_vendor.d/50_mesa.json

# HDMI-Ready — external outputs work, dGPU stays awake
env = AQ_DRM_DEVICES,/dev/dri/cardN:/dev/dri/cardM       # iGPU + dGPU
```

Card nodes are resolved from **PCI addresses** on every switch, so this survives the
`/dev/dri/cardN` renumbering that happens when GPU modes change.

## Notes & caveats

- **Hyprland-only.** The mode toggle is built on `AQ_DRM_DEVICES`; it won't do anything on other
  compositors. The monitoring half (icon + power state) is harmless everywhere but only useful
  with an NVIDIA dGPU.
- **A running CUDA/GL client keeps the dGPU awake** — that's correct behaviour. The panel's
  "GPU processes" row tells you which one (e.g. a stray ComfyUI/Ollama container). Battery mode
  can't sleep a GPU that something is actively using.
- Opening the panel wakes the dGPU (to read `nvidia-smi`); the **bar icon** is the honest at-rest
  indicator, since it never touches the GPU.

## Credits

- NVIDIA "eye" glyph derived from the [Papirus icon theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) (GPLv3), recoloured to a single silhouette and tinted at runtime.
- Built for [Noctalia](https://github.com/noctalia-dev/noctalia-shell).

## License

MIT © Jon Iler ([@joniler](https://github.com/joniler))
