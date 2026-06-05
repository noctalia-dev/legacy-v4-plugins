#!/usr/bin/env python3
"""Scan all supported sources for device battery levels and print a normalized
JSON array on stdout.

Output schema (one object per detected device that reports a battery level):

    {
      "id":       "<source>:<stable-key>",   # stable across runs
      "name":     "Human readable name",
      "type":     "mouse|keyboard|headset|...",  # used to pick a default icon
      "battery":  0-100,
      "charging": true|false,
      "source":   "openrazer|solaar"
    }

To add a new battery source, write a scan_<source>() that returns a list of
dicts in this schema (swallowing all its own errors so a missing tool yields an
empty list), then add it to SOURCES at the bottom. Nothing else needs to change:
Main.qml polls this script, and the settings UI lists whatever it reports.
"""

import json
import re
import subprocess
import sys


def _norm_type(raw: str) -> str:
    """Map a vendor 'kind' string onto a small set of known device types."""
    raw = (raw or "").lower()
    if "mouse" in raw:
        return "mouse"
    if "keyboard" in raw or "keypad" in raw:
        return "keyboard"
    if "headset" in raw or "headphone" in raw:
        return "headset"
    if "trackball" in raw:
        return "mouse"
    if "gamepad" in raw or "joystick" in raw:
        return "gamepad"
    return "device"


# --------------------------------------------------------------------------- #
# OpenRazer (mice, keyboards, ... via the running openrazer-daemon)
# --------------------------------------------------------------------------- #
def scan_openrazer():
    devices = []
    try:
        from openrazer.client import DeviceManager
    except Exception:
        return devices

    try:
        dm = DeviceManager()
    except Exception:
        return devices

    for dev in getattr(dm, "devices", []):
        try:
            if not dev.has("battery"):
                continue
            # Identify by USB vendor:product id. The daemon's serial is
            # unreliable — it frequently reports a placeholder like
            # "UNKNOWN_153200B7_0000" (notably when started via the systemd
            # user service), which would otherwise mint an unstable id. vid:pid
            # is stable regardless and only collides between two identical
            # devices.
            vid = getattr(dev, "_vid", None)
            pid = getattr(dev, "_pid", None)
            if vid is not None and pid is not None:
                key = "%04x:%04x" % (int(vid), int(pid))
            else:
                key = str(dev.serial)
            devices.append({
                "id": "openrazer:" + key,
                "name": dev.name,
                "type": _norm_type(getattr(dev, "type", "")),
                "battery": int(round(dev.battery_level)),
                "charging": bool(dev.is_charging),
                "source": "openrazer",
            })
        except Exception:
            # One bad device shouldn't drop the rest.
            continue
    return devices


# --------------------------------------------------------------------------- #
# Solaar (Logitech Unifying / Bolt / Lightspeed devices)
# --------------------------------------------------------------------------- #
# Match the aligned top-level fields (a space before the colon) so we don't pick
# up nested lines like "Kind: None" under the DEVICE NAME feature.
_SOLAAR_BATTERY_RE = re.compile(r"Battery:\s*(\d+)%")
_SOLAAR_KIND_RE = re.compile(r"^\s+Kind\s+:\s*(\S.*?)\s*$")
_SOLAAR_SERIAL_RE = re.compile(r"^\s+Serial number\s+:\s*(\S.*?)\s*$")


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def scan_solaar():
    devices = []
    try:
        out = subprocess.run(
            ["solaar", "show"],
            capture_output=True, text=True, timeout=30,
        ).stdout
    except Exception:
        return devices

    # `solaar show` prints one block per device/receiver. A new block starts at
    # a line with no leading whitespace; lines inside a block are indented.
    block = []
    blocks = []
    for line in out.splitlines():
        if line and not line[0].isspace():
            if block:
                blocks.append(block)
            block = [line]
        elif block:
            block.append(line)
    if block:
        blocks.append(block)

    for block in blocks:
        text = "\n".join(block)
        bm = _SOLAAR_BATTERY_RE.search(text)
        if not bm:
            continue  # receivers and battery-less devices are skipped
        name = block[0].strip()
        if not name or name.lower().startswith("solaar version"):
            continue

        kind = ""
        serial = ""
        for line in block[1:]:
            km = _SOLAAR_KIND_RE.match(line)
            if km:
                kind = km.group(1)
            sm = _SOLAAR_SERIAL_RE.match(line)
            if sm and sm.group(1):
                serial = sm.group(1)

        key = serial or _slug(name)
        devices.append({
            "id": "solaar:" + key,
            "name": name,
            "type": _norm_type(kind or name),
            "battery": int(bm.group(1)),
            "charging": "CHARGING" in text and "DISCHARGING" not in text,
            "source": "solaar",
        })
    return devices


SOURCES = [scan_openrazer, scan_solaar]


def main():
    results = []
    for scan in SOURCES:
        try:
            results.extend(scan())
        except Exception:
            continue
    json.dump(results, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
