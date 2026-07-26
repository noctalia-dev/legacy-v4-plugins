#!/usr/bin/env bash
# gpu-detect.sh — shared helpers for the noctalia nvidia-optimus plugin.
# Sourced by gpu-stat and gpu-toggle. Detects the iGPU (Intel/AMD) and the NVIDIA
# dGPU from sysfs ONLY — never lspci — so detection never resumes a suspended GPU.

# Populates IGPU_PCI and DGPU_PCI (e.g. 0000:00:02.0). Empty if not present.
detect_gpus() {
  IGPU_PCI=""; DGPU_PCI=""
  local d cls ven pci
  for d in /sys/bus/pci/devices/*; do
    cls=$(cat "$d/class" 2>/dev/null) || continue   # cached attr, does not wake device
    case "$cls" in
      0x0300*|0x0302*) ;;                            # VGA or 3D controller
      *) continue ;;
    esac
    ven=$(cat "$d/vendor" 2>/dev/null)
    pci=$(basename "$d")
    case "$ven" in
      0x10de) [ -z "$DGPU_PCI" ] && DGPU_PCI="$pci" ;;   # NVIDIA
      0x8086|0x1002) [ -z "$IGPU_PCI" ] && IGPU_PCI="$pci" ;; # Intel / AMD
    esac
  done
}

# Resolve the /dev/dri/cardN node for a PCI address (cardN numbering is not stable).
card_for() { # $1=pci -> cardN
  local c p
  for c in /dev/dri/card[0-9]*; do
    p=$(basename "$(readlink -f "/sys/class/drm/$(basename "$c")/device" 2>/dev/null)")
    [ "$p" = "$1" ] && { basename "$c"; return; }
  done
}

# Marketing name of the dGPU WITHOUT waking it: reads the device ID from sysfs and
# resolves it against the pci.ids database (plain file reads). Falls back to lspci
# (a one-time config-space read) only if pci.ids is unavailable.
gpu_name() { # uses $DGPU_PCI
  local vid did f raw=""
  vid=$(cat "/sys/bus/pci/devices/$DGPU_PCI/vendor" 2>/dev/null); vid=${vid#0x}
  did=$(cat "/sys/bus/pci/devices/$DGPU_PCI/device" 2>/dev/null); did=${did#0x}
  for f in /usr/share/hwdata/pci.ids /usr/share/misc/pci.ids; do
    [ -r "$f" ] || continue
    raw=$(awk -v v="$vid" -v d="$did" '
      /^[0-9a-fA-F]{4}  / { invend = ($1 == v) }
      invend && index($0, "\t" d "  ") == 1 { sub(/^\t[0-9a-fA-F]{4}  /, ""); print; exit }
    ' "$f")
    [ -n "$raw" ] && break
  done
  [ -z "$raw" ] && raw=$(lspci -s "$DGPU_PCI" 2>/dev/null | sed -E 's/^.*: //')
  # Prefer the bracketed marketing name, e.g. "GB205M [GeForce RTX 5070 Ti Mobile]".
  case "$raw" in *\[*\]*) raw=$(printf '%s' "$raw" | sed -E 's/.*\[([^]]*)\].*/\1/') ;; esac
  raw=$(printf '%s' "$raw" | sed -E 's/GeForce +//; s/ +\(rev.*//; s/ +$//')
  [ -n "$raw" ] && printf '%s' "$raw" || printf 'NVIDIA dGPU'
}

# Path of the mesa EGL vendor JSON (used to force mesa-only EGL in Battery mode).
mesa_egl_json() {
  local f
  for f in /usr/share/glvnd/egl_vendor.d/*mesa*.json \
           /usr/local/share/glvnd/egl_vendor.d/*mesa*.json; do
    [ -e "$f" ] && { echo "$f"; return; }
  done
  echo "/usr/share/glvnd/egl_vendor.d/50_mesa.json"   # sensible default
}

# Hyprland env file that holds the AQ_DRM_DEVICES / EGL lines.
env_file() { echo "${HYPR_ENV_FILE:-$HOME/.config/hypr/env.conf}"; }
