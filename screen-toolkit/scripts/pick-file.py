#!/usr/bin/env python3
"""XDG desktop portal file picker — called by pick-file.sh"""
import sys, random, string
try:
    import gi
    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib
except Exception:
    sys.exit(1)

loop   = GLib.MainLoop()
result = []

def on_response(conn, sender, path, iface, signal, params, *_):
    code, results = params
    if code == 0:
        uris = results.get("uris")
        if uris:
            result.append(uris[0].replace("file://", "").replace("%20", " "))
    loop.quit()

bus   = Gio.bus_get_sync(Gio.BusType.SESSION, None)
token = ''.join(random.choices(string.ascii_lowercase, k=8))
uid   = bus.get_unique_name()[1:].replace('.', '_')
handle = f"/org/freedesktop/portal/desktop/request/{uid}/{token}"

bus.signal_subscribe(
    "org.freedesktop.portal.Desktop",
    "org.freedesktop.portal.Request",
    "Response", handle, None,
    Gio.DBusSignalFlags.NONE,
    on_response, None
)

# FIX: build the variant correctly without double-unpacking
opts = GLib.Variant("a{sv}", {
    "handle_token": GLib.Variant("s", token),
    "filters": GLib.Variant("a(sa(us))", [
        ("Images & Videos", [
            (1, "*.png"), (1, "*.jpg"), (1, "*.jpeg"),
            (1, "*.webp"), (1, "*.gif"), (1, "*.bmp"),
            (1, "*.mp4"), (1, "*.webm"), (1, "*.mkv"), (1, "*.mov")
        ])
    ])
})

try:
    bus.call_sync(
        "org.freedesktop.portal.Desktop",
        "/org/freedesktop/portal/desktop",
        "org.freedesktop.portal.FileChooser",
        "OpenFile",
        GLib.Variant("(ssa{sv})", ("", "Pin image", opts)),  # FIX: pass opts directly
        None, Gio.DBusCallFlags.NONE,
        10_000,   # FIX: 10 second timeout instead of -1 (infinite)
        None
    )
except Exception:
    sys.exit(1)

# FIX: safety timeout so loop.run() can never hang forever
def _timeout():
    loop.quit()
    return GLib.SOURCE_REMOVE

GLib.timeout_add_seconds(30, _timeout)
loop.run()

if result:
    print(result[0])
    sys.exit(0)
sys.exit(1)
