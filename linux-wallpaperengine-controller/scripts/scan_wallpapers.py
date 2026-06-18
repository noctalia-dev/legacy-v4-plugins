#!/usr/bin/env python3
"""
Scan a Wallpaper Engine workshop directory and emit wallpaper metadata.

Called by scan-wallpapers.sh (see that file for full documentation).

Usage:
    python3 scan_wallpapers.py <wallpaper_engine_workshop_dir>
"""

import sys
import os
import json
import re


def extract_resolution(name: str) -> str:
    name_lower = name.lower()
    match = re.search(r"([0-9]{3,4}x[0-9]{3,4})", name_lower)
    if match:
        return match.group(1)
    if "4k" in name_lower:
        return "3840x2160"
    if "2k" in name_lower:
        return "2560x1440"
    if "1080p" in name_lower:
        return "1920x1080"
    if "720p" in name_lower:
        return "1280x720"
    return "unknown"


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(10)

    dir_path = sys.argv[1]
    try:
        items = os.listdir(dir_path)
    except Exception:
        sys.exit(10)

    for item in items:
        d = os.path.join(dir_path, item)
        if not os.path.isdir(d):
            continue

        # Default metadata
        id_val = item
        name = id_val
        dynamic = 0
        embedded_audio = 0
        audio_reactive = 0
        approved = 0
        type_val = "unknown"
        resolution = "unknown"
        description = ""
        bytes_val = 0
        mtime = 0

        try:
            mtime = int(os.stat(d).st_mtime)
            for root_dir, dirs, files in os.walk(d):
                for name_ in files:
                    bytes_val += os.path.getsize(os.path.join(root_dir, name_))
        except Exception:
            pass

        project_json_path = os.path.join(d, "project.json")
        if os.path.isfile(project_json_path):
            try:
                with open(project_json_path, "r", encoding="utf-8") as f:
                    data = json.load(f)

                    title = data.get("title", "")
                    if title:
                        name = str(title)

                    desc = data.get("description", "")
                    if desc:
                        description = (
                            str(desc)
                            .replace("\r", "")
                            .replace("\n", "\\n")
                            .replace("\t", " ")
                        )

                    t = data.get("type")
                    if t:
                        type_val = str(t).lower()
                        if type_val in ("video", "web"):
                            dynamic = 1

                    if data.get("supportsaudioprocessing"):
                        audio_reactive = 1

                    if data.get("approved"):
                        approved = 1

                    resolution = extract_resolution(name)
            except Exception:
                pass

        # Fast guessing if resolution is still unknown
        if resolution == "unknown":
            resolution = extract_resolution(name)

        thumb = ""
        motion = ""
        for f in (
            "preview.jpg",
            "preview.png",
            "preview.jpeg",
            "screenshot.jpg",
            "screenshot.png",
            "screenshot.jpeg",
        ):
            p = os.path.join(d, f)
            if os.path.isfile(p):
                thumb = p
                break

        for m in ("preview.gif", "preview.webm", "preview.mp4"):
            p = os.path.join(d, m)
            if os.path.isfile(p):
                motion = p
                dynamic = 1
                break

        scene_pkg_path = os.path.join(d, "scene.pkg")
        if os.path.isfile(scene_pkg_path):
            try:
                with open(scene_pkg_path, "rb") as f:
                    data = f.read()

                    # Basic embedded audio heuristic
                    if (
                        b"sounds/" in data
                        or b".mp3" in data
                        or b".ogg" in data
                        or b".wav" in data
                        or b".flac" in data
                        or b'"sound"' in data
                    ):
                        embedded_audio = 1

                    # Basic audio reactive heuristic
                    if (
                        b"registerAudioBuffers" in data
                        or b"g_AudioSpectrum" in data
                        or b"audio_response" in data
                        or b"AUDIOPROCESSING" in data
                    ):
                        audio_reactive = 1
            except Exception:
                pass

        print(
            f"{d}\t{name}\t{thumb}\t{motion}\t{dynamic}\t{id_val}\t"
            f"{type_val}\t{resolution}\t{embedded_audio}\t{audio_reactive}\t"
            f"{bytes_val}:{mtime}\t{approved}\t{description}"
        )


if __name__ == "__main__":
    main()
