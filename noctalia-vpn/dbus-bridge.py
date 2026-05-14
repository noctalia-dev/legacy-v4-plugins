#!/usr/bin/env python3
"""JSON ↔ DBus bridge for the Noctalia VPN plugin.

Owned by Main.qml (run as a child Process). Responsibilities:

  1. Spawn the backend daemon (~/dev/noctalia-vpn-plugin/.venv/bin/python3 -m
     backend.app) if the bus name isn't already taken.
  2. Wait until org.noctalia.VpnPlugin is on the session bus.
  3. Read newline-delimited JSON requests from stdin:
        {"id": N, "method": "GetStatus", "args": []}
  4. Write newline-delimited JSON responses to stdout:
        {"id": N, "result": ...}     on success
        {"id": N, "error":  "..."}   on failure
  5. Forward DBus signals to stdout as events:
        {"event": "StatusChanged",  "data": {...}}
        {"event": "ServerListChanged"}
        {"event": "LogMessage",     "data": {"level": "info", "message": "..."}}
        {"event": "TrafficUpdate",  "data": {...}}
        {"event": "ready"}                    (after the bus name resolves)
        {"event": "exit",  "data": {"code": N}}  (just before exit)

stdout is line-buffered. Each line is one JSON document.
"""

from __future__ import annotations

import asyncio
import json
import os
import signal
import sys
from pathlib import Path
from typing import Any

# Local venv must be on sys.path so dbus-next can be imported. The bridge is
# launched via that same venv's python from Main.qml, so dbus_next is already
# available — but if a developer runs it manually with system python, fall
# through to a helpful error.
try:
    from dbus_next import Variant
    from dbus_next.aio import MessageBus
    from dbus_next.constants import BusType
    from dbus_next.errors import DBusError
    from dbus_next.signature import SignatureTree
except ImportError as exc:  # pragma: no cover
    sys.stderr.write(
        "noctalia-vpn-bridge: missing dbus_next. Launch via the project's .venv/bin/python3.\n"
        f"({exc})\n"
    )
    sys.exit(1)


SERVICE_NAME = "org.noctalia.VpnPlugin"
OBJECT_PATH = "/org/noctalia/VpnPlugin"
INTERFACE = "org.noctalia.VpnPlugin"

PROJECT_DIR = Path(os.path.expanduser("~/dev/noctalia-vpn-plugin"))
VENV_PYTHON = PROJECT_DIR / ".venv" / "bin" / "python3"
LOG_FILE = Path("/tmp/noctalia-vpn-backend.log")


def emit(obj: dict) -> None:
    """Write one JSON line to stdout."""
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def unwrap(value: Any) -> Any:
    """Recursively strip dbus_next Variant wrappers from a value."""
    if isinstance(value, Variant):
        return unwrap(value.value)
    if isinstance(value, dict):
        return {k: unwrap(v) for k, v in value.items()}
    if isinstance(value, list):
        return [unwrap(v) for v in value]
    return value


def to_variant_dict(d: dict) -> dict:
    """Convert a JSON dict into dbus_next Variant-keyed dict (a{sv})."""
    out: dict = {}
    for k, v in d.items():
        out[str(k)] = py_to_variant(v)
    return out


def py_to_variant(value: Any) -> Variant:
    if isinstance(value, bool):
        return Variant("b", value)
    if isinstance(value, int):
        return Variant("x", value)
    if isinstance(value, float):
        return Variant("d", value)
    if isinstance(value, str):
        return Variant("s", value)
    if isinstance(value, list):
        if not value:
            return Variant("as", [])
        if all(isinstance(v, str) for v in value):
            return Variant("as", value)
        return Variant("av", [py_to_variant(v) for v in value])
    if isinstance(value, dict):
        return Variant("a{sv}", to_variant_dict(value))
    if value is None:
        return Variant("s", "")
    return Variant("s", json.dumps(value))


# --- DBus call argument coercion ----------------------------------------------

def coerce_args(method_name: str, args: list) -> list:
    """Coerce raw JSON args into the DBus types expected by each method.

    Most methods take simple strings/ints/bools — those pass through unchanged.
    The two that take dicts (AddServer, UpdateServer, AddRoutingRule) need
    their dict argument wrapped as a{sv}.
    """
    if method_name in ("AddServer", "UpdateServer") and args:
        return [to_variant_dict(args[0])] + list(args[1:])
    if method_name == "AddRoutingRule" and args:
        return [to_variant_dict(args[0])] + list(args[1:])
    if method_name == "UpdateSettings" and args:
        return [to_variant_dict(args[0])] + list(args[1:])
    return list(args)


# --- Backend lifecycle --------------------------------------------------------

async def ensure_backend_running() -> asyncio.subprocess.Process | None:
    """Spawn the backend daemon if the DBus name isn't yet owned.

    Returns the subprocess handle when we own it, or None if another instance
    already holds the name.
    """
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    try:
        owner = await bus.call(
            dbus_message(
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                "NameHasOwner",
                "s",
                [SERVICE_NAME],
            )
        )
        already = bool(owner.body[0])
    except Exception:
        already = False
    finally:
        bus.disconnect()

    if already:
        return None

    log_fh = open(LOG_FILE, "ab")
    proc = await asyncio.create_subprocess_exec(
        str(VENV_PYTHON),
        "-m",
        "backend.app",
        cwd=str(PROJECT_DIR),
        stdin=asyncio.subprocess.DEVNULL,
        stdout=log_fh,
        stderr=log_fh,
        start_new_session=True,
    )
    log_fh.close()
    return proc


def dbus_message(dest: str, path: str, iface: str, member: str, sig: str, body: list):
    from dbus_next import Message
    return Message(
        destination=dest,
        path=path,
        interface=iface,
        member=member,
        signature=sig,
        body=body,
    )


async def wait_for_name(bus, timeout: float = 15.0) -> bool:
    deadline = asyncio.get_event_loop().time() + timeout
    while asyncio.get_event_loop().time() < deadline:
        try:
            reply = await bus.call(
                dbus_message(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    "org.freedesktop.DBus",
                    "NameHasOwner",
                    "s",
                    [SERVICE_NAME],
                )
            )
            if reply.body[0]:
                return True
        except Exception:
            pass
        await asyncio.sleep(0.25)
    return False


# --- Main protocol loop -------------------------------------------------------

async def stdin_reader() -> asyncio.StreamReader:
    loop = asyncio.get_event_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)
    return reader


async def run() -> int:
    backend_proc = await ensure_backend_running()

    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    if not await wait_for_name(bus):
        emit({"event": "error", "data": {"message": "backend DBus name never appeared"}})
        return 1

    introspection = await bus.introspect(SERVICE_NAME, OBJECT_PATH)
    obj = bus.get_proxy_object(SERVICE_NAME, OBJECT_PATH, introspection)
    iface = obj.get_interface(INTERFACE)

    # --- Signal wiring -------------------------------------------------------

    def on_status_changed(payload):
        try:
            emit({"event": "StatusChanged", "data": unwrap(payload)})
        except Exception:
            pass

    def on_server_list_changed():
        emit({"event": "ServerListChanged"})

    def on_log_message(level, message):
        emit({"event": "LogMessage", "data": {"level": level, "message": message}})

    def on_traffic_update(payload):
        try:
            emit({"event": "TrafficUpdate", "data": unwrap(payload)})
        except Exception:
            pass

    try:
        iface.on_status_changed(on_status_changed)
    except Exception:
        pass
    try:
        iface.on_server_list_changed(on_server_list_changed)
    except Exception:
        pass
    try:
        iface.on_log_message(on_log_message)
    except Exception:
        pass
    try:
        iface.on_traffic_update(on_traffic_update)
    except Exception:
        pass

    emit({"event": "ready"})

    # --- Stdin command loop --------------------------------------------------

    reader = await stdin_reader()

    async def call(method: str, args: list) -> Any:
        # dbus-next exposes camelCase method foo as call_method on the proxy iface
        snake = "call_" + camel_to_snake(method)
        fn = getattr(iface, snake, None)
        if fn is None:
            raise RuntimeError(f"unknown method: {method}")
        coerced = coerce_args(method, args)
        result = await fn(*coerced)
        return unwrap(result)

    async def process_line(line: str) -> None:
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            return
        rid = req.get("id")
        method = req.get("method", "")
        args = req.get("args") or []
        try:
            result = await call(method, args)
            emit({"id": rid, "result": result})
        except DBusError as exc:
            emit({"id": rid, "error": exc.text or str(exc)})
        except Exception as exc:
            emit({"id": rid, "error": f"{type(exc).__name__}: {exc}"})

    pending: set = set()
    try:
        while True:
            raw = await reader.readline()
            if not raw:
                break
            line = raw.decode("utf-8", errors="replace").strip()
            if not line:
                continue
            t = asyncio.create_task(process_line(line))
            pending.add(t)
            t.add_done_callback(pending.discard)
    except asyncio.CancelledError:
        pass
    finally:
        if pending:
            await asyncio.gather(*pending, return_exceptions=True)
        try:
            bus.disconnect()
        except Exception:
            pass
        if backend_proc is not None:
            try:
                backend_proc.terminate()
                try:
                    await asyncio.wait_for(backend_proc.wait(), timeout=3.0)
                except asyncio.TimeoutError:
                    backend_proc.kill()
                    await backend_proc.wait()
            except ProcessLookupError:
                pass
        emit({"event": "exit", "data": {"code": 0}})

    return 0


def camel_to_snake(name: str) -> str:
    out = []
    for i, c in enumerate(name):
        if c.isupper() and i > 0 and not name[i - 1].isupper():
            out.append("_")
        out.append(c.lower())
    return "".join(out)


def main() -> int:
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    stop = asyncio.Event()

    def _stop(*_):
        if not stop.is_set():
            stop.set()
            for t in asyncio.all_tasks(loop):
                t.cancel()

    for sig in (signal.SIGTERM, signal.SIGINT):
        try:
            loop.add_signal_handler(sig, _stop)
        except (NotImplementedError, RuntimeError):
            pass

    try:
        return loop.run_until_complete(run())
    except KeyboardInterrupt:
        return 0
    finally:
        loop.close()


if __name__ == "__main__":
    sys.exit(main())
