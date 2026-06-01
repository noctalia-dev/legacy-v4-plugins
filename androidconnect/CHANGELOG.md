# Changelog

## v1.6.1

- Allow embedded mirroring and input with a single safe ADB target even when KDE Connect is not paired yet.
- Rebuild the embedded preview path only after the V4L2 loopback format matches the expected `scrcpy` output, fixing distorted colors and stretched frames when switching between phone aspect ratios.
- Keep the phone frame visible while the live feed reloads during device switches.
- Use long-edge display scaling for embedded full-frame output so common tall phone aspect ratios stay aligned without device-specific patches.
- Shorten the preview attach and retry delays without changing the mirror readiness checks.

## v1.6.0

- Improve embedded mirror compatibility across phone display sizes by probing Android display geometry before launching `scrcpy`.
- Prefer full-frame mirroring with computed `--max-size` values and keep crop handling as a fallback path only.
- Wait for the V4L2 loopback format to match the expected `scrcpy` output before locking it, and restart the feed once if the format is stale.
- Strip stale `--max-size` and `--crop` options from configured embedded mirror commands before applying the computed launch shape.
- Add a conservative one-time `h265` retry for codec/encoder launch failures.
- Preserve correct embedded touch mapping if crop fallback is ever used.
- Move the phone size control into the header brand badge hover state and use a clearer resize icon.
- Add a Motorola brand badge for device names that identify as Motorola or Moto.

## v1.5.1

- Silently try Wireless ADB mDNS auto-detect once for a selected KDE Connect phone before showing the ADB missing state.
- Keep the embedded panel mirror orientation locked while allowing detached scrcpy windows to follow device rotation.

## v1.5.0

- Tie embedded `scrcpy` sessions to the selected KDE Connect device so the panel does not show another phone's mirror.
- Add per-device Wireless ADB profiles keyed by KDE Connect device ID.
- Add Wireless ADB auto-detect for the selected phone's current mDNS connect port.
- Add diagnostics details for selected KDE host, resolved ADB serial, Wireless ADB profile state, and a compact connection verdict.
- Hide the decorative phone home indicator while the live embedded mirror is connected.
- Polish the connected-device switcher selected state.

## v1.4.0

- Stabilize first-run embedded mirror startup with `v4l2loopback exclusive_caps=0`.
- Keep Android navigation, screenshot, screen recording, keep-awake, and embedded audio controls in the panel.
