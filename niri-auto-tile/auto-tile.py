#!/usr/bin/env python3
"""Auto-tile for niri: redistributes column widths evenly (max N visible).

Listens to niri's JSON event stream and automatically resizes all tiling
columns to equal widths whenever a window is opened or closed.

Supports per-workspace max-visible settings via --workspace-config.
"""

import argparse
import json
import logging
import os
import signal
import subprocess
import threading
import time

# ─── Configuration (overridable via CLI args) ───
MAX_VISIBLE = 4
MAX_COLUMNS = 20
DEBOUNCE_SECONDS = 0.3
NIRI_TIMEOUT = 5
RECONNECT_DELAY = 2.0
MAX_EVENTS_PER_SECOND = 20
PER_WORKSPACE = False
WORKSPACE_MAX_VISIBLE: dict[int, int] = {}
ONLY_AT_MAX = True
CONFIG_FILE: str = ""

# ─── Logging ───
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s auto-tile: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("auto-tile")

# ─── State ───
_prev_col_counts: dict[int, int] = {}  # workspace_id -> column count
_known_window_ids: set[int] = set()    # track known windows to detect new ones
_debounce_timer: threading.Timer | None = None
_lock = threading.Lock()
_event_count = 0
_event_window_start = 0.0
_pending_event: dict | None = None  # {"type": "open"/"close", "window_id": int}


# ─── Validation ───
def _valid_id(value) -> int | None:
    """Validate that value is a non-negative integer."""
    try:
        val = int(value)
        return val if val >= 0 else None
    except (TypeError, ValueError):
        return None


def get_max_visible(ws_id: int) -> int:
    """Get max visible columns for a workspace."""
    if PER_WORKSPACE and ws_id in WORKSPACE_MAX_VISIBLE:
        return WORKSPACE_MAX_VISIBLE[ws_id]
    return MAX_VISIBLE


# ─── Niri IPC ───
def niri_cmd(*args) -> str:
    """Run a niri msg command and return stdout."""
    try:
        result = subprocess.run(
            ["niri", "msg", *args],
            capture_output=True, text=True, timeout=NIRI_TIMEOUT,
        )
        if result.returncode != 0:
            log.warning("niri msg %s rc=%d: %s", args, result.returncode, result.stderr.strip())
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        log.warning("niri msg %s timed out", args)
        return ""
    except FileNotFoundError:
        log.error("niri binary not found")
        return ""
    except OSError as exc:
        log.error("niri msg %s error: %s", args, exc)
        return ""


def niri_action(*args) -> None:
    """Run a niri msg action."""
    try:
        result = subprocess.run(
            ["niri", "msg", "action", *args],
            capture_output=True, timeout=NIRI_TIMEOUT,
        )
        if result.returncode != 0:
            log.debug("niri action %s rc=%d", args, result.returncode)
    except subprocess.TimeoutExpired:
        log.warning("niri action %s timed out", args)
    except OSError as exc:
        log.error("niri action %s error: %s", args, exc)


# ─── Queries ───
def get_focused_workspace() -> tuple[int | None, int | None]:
    """Get (workspace_id, focused_window_id)."""
    raw = niri_cmd("-j", "focused-window")
    if not raw:
        return _get_active_workspace_id(), None
    try:
        data = json.loads(raw)
        if not isinstance(data, dict):
            return _get_active_workspace_id(), None
        ws_id = _valid_id(data.get("workspace_id"))
        win_id = _valid_id(data.get("id"))
        if ws_id is None:
            ws_id = _get_active_workspace_id()
        return ws_id, win_id
    except json.JSONDecodeError:
        log.warning("failed to parse focused-window JSON")
        return _get_active_workspace_id(), None


def _get_active_workspace_id() -> int | None:
    """Get the active workspace ID from niri workspaces list (fallback)."""
    raw = niri_cmd("-j", "workspaces")
    if not raw:
        return None
    try:
        workspaces = json.loads(raw)
        if not isinstance(workspaces, list):
            return None
        for ws in workspaces:
            if isinstance(ws, dict) and ws.get("is_active") and ws.get("is_focused"):
                return _valid_id(ws.get("id"))
        # Fallback: just active
        for ws in workspaces:
            if isinstance(ws, dict) and ws.get("is_focused"):
                return _valid_id(ws.get("id"))
        return None
    except json.JSONDecodeError:
        return None


def _get_windows() -> list[dict]:
    """Fetch all windows from niri IPC (single shared call)."""
    raw = niri_cmd("-j", "windows")
    if not raw:
        return []
    try:
        windows = json.loads(raw)
        if not isinstance(windows, list):
            log.warning("unexpected windows JSON type: %s", type(windows).__name__)
            return []
        return [w for w in windows if isinstance(w, dict)]
    except json.JSONDecodeError:
        log.warning("failed to parse windows JSON")
        return []


def count_columns(workspace_id: int) -> int:
    """Count unique tiling columns in the given workspace."""
    cols: set[int] = set()
    for w in _get_windows():
        if w.get("workspace_id") != workspace_id:
            continue
        if w.get("is_floating", False):
            continue
        layout = w.get("layout")
        if not isinstance(layout, dict):
            continue
        pos = layout.get("pos_in_scrolling_layout")
        if isinstance(pos, (list, tuple)) and len(pos) > 0:
            col_idx = _valid_id(pos[0])
            if col_idx is not None:
                cols.add(col_idx)
    return len(cols)


def get_all_window_ids() -> set[int]:
    """Get set of all current window IDs."""
    return {w["id"] for w in _get_windows() if "id" in w}


# ─── Core Logic ───
def get_active_workspaces() -> set[int]:
    """Get set of workspace IDs that have tiled windows."""
    ws_ids: set[int] = set()
    for w in _get_windows():
        if w.get("is_floating", False):
            continue
        ws = _valid_id(w.get("workspace_id"))
        if ws is not None:
            ws_ids.add(ws)
    return ws_ids


def _build_column_map(windows: list[dict], ws_id: int) -> dict[int, list[int]]:
    """Build a map of col_idx -> [window_ids] for tiled windows on a workspace.

    Returns sorted by column index.
    """
    col_map: dict[int, list[int]] = {}
    for w in windows:
        if w.get("workspace_id") != ws_id or w.get("is_floating", False):
            continue
        win_id = _valid_id(w.get("id"))
        if win_id is None:
            continue
        layout = w.get("layout")
        if not isinstance(layout, dict):
            continue
        pos = layout.get("pos_in_scrolling_layout")
        if isinstance(pos, (list, tuple)) and len(pos) > 0:
            col_idx = _valid_id(pos[0])
            if col_idx is not None:
                if col_idx not in col_map:
                    col_map[col_idx] = []
                col_map[col_idx].append(win_id)
    return col_map


def _calc_widths(col_count: int, max_vis: int) -> tuple[int, int]:
    """Calculate base percentage and remainder for even distribution."""
    visible = min(col_count, max_vis)
    base_pct = 100 // visible
    remainder = 100 - (base_pct * visible)
    return base_pct, remainder


def _set_column_width_by_id(win_id: int, pct: str) -> None:
    """Focus a window by ID and set its column width (no walking)."""
    niri_action("focus-window", "--id", str(win_id))
    niri_action("set-column-width", pct)


def _redistribute_incremental_open(ws_id: int, new_window_id: int) -> None:
    """Handle window open: set only the new column's width.

    Avoids scrolling to the beginning — focuses the new window directly by ID.
    """
    windows = _get_windows()
    col_map = _build_column_map(windows, ws_id)
    col_count = len(col_map)
    if col_count == 0:
        return

    if col_count > MAX_COLUMNS:
        col_count = MAX_COLUMNS

    max_vis = get_max_visible(ws_id)

    # Cache check
    cache_key = (col_count, max_vis)
    with _lock:
        if _prev_col_counts.get(ws_id) == cache_key:
            return
        _prev_col_counts[ws_id] = cache_key

    if ONLY_AT_MAX and col_count < max_vis:
        log.info("ws=%d: %d cols < max=%d, keeping default layout (open)", ws_id, col_count, max_vis)
        return

    # At threshold (col_count == max_vis): full redistribute to set all columns
    if col_count == max_vis:
        log.info("ws=%d: reached max_visible=%d, full redistribute", ws_id, max_vis)
        _redistribute_full(ws_id, col_map, col_count, max_vis)
        return

    # Above threshold: only set the new column's width (incremental)
    base_pct, remainder = _calc_widths(col_count, max_vis)
    sorted_cols = sorted(col_map.keys())

    new_col_idx = None
    for col_idx, win_ids in col_map.items():
        if new_window_id in win_ids:
            new_col_idx = col_idx
            break

    if new_col_idx is None:
        log.debug("ws=%d: new window %d not in column map, full redistribute", ws_id, new_window_id)
        _redistribute_full(ws_id, col_map, col_count, max_vis)
        return

    i = sorted_cols.index(new_col_idx)
    pct = f"{base_pct + remainder}%" if i == len(sorted_cols) - 1 and remainder > 0 else f"{base_pct}%"
    log.info("ws=%d: open window %d at col %d, setting %s (incremental)", ws_id, new_window_id, i, pct)

    _set_column_width_by_id(new_window_id, pct)
    niri_action("center-visible-columns")


def _redistribute_incremental_close(ws_id: int, original_focused: int | None) -> None:
    """Handle window close: let niri reposition, then center if needed.

    When remaining columns >= max_visible, waits for niri to settle and
    then centers visible columns around the focused window.
    """
    col_count = count_columns(ws_id)
    max_vis = get_max_visible(ws_id)
    with _lock:
        _prev_col_counts[ws_id] = (col_count, max_vis)

    if col_count >= max_vis:
        # Wait for niri to finish repositioning
        time.sleep(0.15)
        # Find the focused window's column, then focus max_vis columns back
        # to bring the leftmost needed column into view
        windows = _get_windows()
        col_map = _build_column_map(windows, ws_id)
        sorted_cols = sorted(col_map.keys())

        # Find focused window's column index
        focused_col_pos = len(sorted_cols) - 1  # default to last
        if original_focused is not None:
            for col_idx, win_ids in col_map.items():
                if original_focused in win_ids:
                    focused_col_pos = sorted_cols.index(col_idx)
                    break

        # The leftmost column that should be visible
        leftmost_pos = max(0, focused_col_pos - max_vis + 1)
        leftmost_col_idx = sorted_cols[leftmost_pos]
        leftmost_win_id = col_map[leftmost_col_idx][0]

        # Focus the leftmost column to bring it into view
        niri_action("focus-window", "--id", str(leftmost_win_id))
        niri_action("center-visible-columns")
        # Restore original focus
        if original_focused is not None:
            niri_action("focus-window", "--id", str(original_focused))
        log.info("ws=%d: close event, %d cols >= max=%d — pulled columns to fill viewport", ws_id, col_count, max_vis)
    else:
        # Fewer than max_visible: center remaining columns on screen
        time.sleep(0.15)
        niri_action("center-visible-columns")
        log.info("ws=%d: close event, %d cols < max=%d — centered remaining", ws_id, col_count, max_vis)


def _redistribute_full(ws_id: int, col_map: dict[int, list[int]] | None = None,
                       col_count: int | None = None, max_vis: int | None = None) -> None:
    """Full redistribute using direct window ID focus (no focus-column-first walk).

    Used as fallback and for close events. Much less disruptive than the old
    approach because it uses focus-window --id instead of walking columns.

    When col_map/col_count/max_vis are passed, cache was already checked by caller.
    """
    caller_checked_cache = col_map is not None

    if col_map is None:
        windows = _get_windows()
        col_map = _build_column_map(windows, ws_id)

    if col_count is None:
        col_count = len(col_map)
    if col_count == 0:
        return

    if col_count > MAX_COLUMNS:
        col_count = MAX_COLUMNS

    if max_vis is None:
        max_vis = get_max_visible(ws_id)

    # Cache check only when called directly (not from incremental callers)
    if not caller_checked_cache:
        cache_key = (col_count, max_vis)
        with _lock:
            if _prev_col_counts.get(ws_id) == cache_key:
                return
            _prev_col_counts[ws_id] = cache_key

    if ONLY_AT_MAX and col_count < max_vis:
        log.info("ws=%d: %d cols < max=%d, keeping default layout", ws_id, col_count, max_vis)
        return

    base_pct, remainder = _calc_widths(col_count, max_vis)
    sorted_cols = sorted(col_map.keys())

    log.info("ws=%d: %d cols, max=%d -> %d%% each (+%d%% last) [direct ID]",
             ws_id, col_count, max_vis, base_pct, remainder)

    # Set each column width by focusing a window in it directly (no walking)
    for i, col_idx in enumerate(sorted_cols):
        win_id = col_map[col_idx][0]
        pct = f"{base_pct + remainder}%" if i == len(sorted_cols) - 1 and remainder > 0 else f"{base_pct}%"
        _set_column_width_by_id(win_id, pct)

    niri_action("center-visible-columns")


def _redistribute_workspace(ws_id: int, focused_id: int | None,
                            event_type: str | None = None,
                            event_window_id: int | None = None) -> None:
    """Redistribute columns on a single workspace (dispatch to incremental or full)."""
    if event_type == "open" and event_window_id is not None:
        _redistribute_incremental_open(ws_id, event_window_id)
    elif event_type == "close":
        _redistribute_incremental_close(ws_id, focused_id)
    else:
        _redistribute_full(ws_id)


def redistribute() -> None:
    """Redistribute workspaces, using incremental mode when possible."""
    global _pending_event
    original_ws, original_focused = get_focused_workspace()

    # Consume pending event context
    with _lock:
        event = _pending_event
        _pending_event = None

    event_type = event.get("type") if event else None
    event_window_id = event.get("window_id") if event else None

    if event_type == "open" and event_window_id is not None:
        # Incremental: only handle the workspace of the new window
        windows = _get_windows()
        target_ws = None
        for w in windows:
            if _valid_id(w.get("id")) == event_window_id:
                target_ws = _valid_id(w.get("workspace_id"))
                break
        if target_ws is not None:
            _redistribute_workspace(target_ws, original_focused, "open", event_window_id)
        else:
            # Window not found yet, full redistribute
            for active_ws in get_active_workspaces():
                _redistribute_workspace(active_ws, original_focused)
    elif event_type == "close":
        # Incremental close: redistribute with direct ID focus, no focus change
        for active_ws in get_active_workspaces():
            _redistribute_workspace(active_ws, original_focused, "close", event_window_id)
        # Close handler restores focus itself — skip global restore
        return
    else:
        # Full redistribute (startup, batch events)
        for active_ws in get_active_workspaces():
            _redistribute_workspace(active_ws, original_focused)

    # Restore focus to the original window (open + full only)
    if original_focused is not None:
        niri_action("focus-window", "--id", str(original_focused))
        niri_action("center-visible-columns")
    elif original_ws is not None:
        for w in _get_windows():
            if w.get("workspace_id") == original_ws and not w.get("is_floating", False):
                win_id = _valid_id(w.get("id"))
                if win_id is not None:
                    niri_action("focus-window", "--id", str(win_id))
                    niri_action("center-visible-columns")
                    break


def debounced_redistribute() -> None:
    """Debounce + rate limit before redistributing."""
    global _debounce_timer, _event_count, _event_window_start

    now = time.monotonic()

    with _lock:
        # Rate limiter: sliding window
        if now - _event_window_start > 1.0:
            _event_window_start = now
            _event_count = 0
        _event_count += 1
        if _event_count > MAX_EVENTS_PER_SECOND:
            log.debug("rate limit exceeded, dropping event")
            return

        # Cancel previous timer, start new one
        if _debounce_timer is not None:
            _debounce_timer.cancel()
        _debounce_timer = threading.Timer(DEBOUNCE_SECONDS, redistribute)
        _debounce_timer.start()


# ─── Event Processing ───
def should_redistribute(event: dict) -> bool:
    """Determine if an event warrants redistribution.

    Only triggers on actual window open/close, NOT title changes.
    Stores event context in _pending_event for incremental redistribution.
    """
    global _known_window_ids, _pending_event

    if "WindowClosed" in event:
        closed = event["WindowClosed"]
        if isinstance(closed, dict):
            win_id = closed.get("id")
            if win_id is not None:
                with _lock:
                    _known_window_ids.discard(win_id)
                    _pending_event = {"type": "close", "window_id": win_id}
        return True

    if "WindowOpenedOrChanged" in event:
        payload = event["WindowOpenedOrChanged"]
        if not isinstance(payload, dict):
            return False
        window = payload.get("window") or {}
        if not isinstance(window, dict):
            return False
        win_id = window.get("id")
        if win_id is not None:
            with _lock:
                if win_id not in _known_window_ids:
                    _known_window_ids.add(win_id)
                    _pending_event = {"type": "open", "window_id": win_id}
                    return True
            return False
        return False

    if "WindowsChanged" in event:
        # Batch event (startup) — sync known IDs, full redistribute
        changed = event["WindowsChanged"]
        if not isinstance(changed, dict):
            return False
        windows = changed.get("windows") or []
        if not isinstance(windows, list):
            return False
        new_ids = {w["id"] for w in windows if isinstance(w, dict) and "id" in w}
        with _lock:
            if new_ids != _known_window_ids:
                _known_window_ids = new_ids
                _pending_event = None  # full redistribute
                return True
        return False

    return False


def run_event_loop() -> None:
    """Connect to niri event stream and process events."""
    global _known_window_ids, _debounce_timer, _event_count, _event_window_start

    # Cancel any pending timer from previous cycle and reset rate limiter
    with _lock:
        if _debounce_timer is not None:
            _debounce_timer.cancel()
            _debounce_timer = None
        _event_count = 0
        _event_window_start = 0.0
        # Initialize known windows under lock
        _known_window_ids = get_all_window_ids()
    log.info("tracking %d existing windows", len(_known_window_ids))

    # Force immediate redistribution on startup
    with _lock:
        _prev_col_counts.clear()
    redistribute()

    proc = subprocess.Popen(
        ["niri", "msg", "-j", "event-stream"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
    )

    try:
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            if not isinstance(event, dict):
                continue

            if should_redistribute(event):
                debounced_redistribute()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()


# ─── CLI ───
def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Auto-tile daemon for niri — redistributes column widths evenly.",
    )
    parser.add_argument(
        "--max-visible", type=int, default=None,
        help=f"max columns visible on screen (default: {MAX_VISIBLE})",
    )
    parser.add_argument(
        "--debounce", type=float, default=None,
        help=f"debounce delay in seconds (default: {DEBOUNCE_SECONDS})",
    )
    parser.add_argument(
        "--max-events", type=int, default=None,
        help=f"max events per second (default: {MAX_EVENTS_PER_SECOND})",
    )
    parser.add_argument(
        "--only-at-max", action="store_true",
        help="only redistribute when column count reaches max-visible",
    )
    parser.add_argument(
        "--per-workspace", action="store_true",
        help="use per-workspace max-visible settings",
    )
    parser.add_argument(
        "--workspace-config", type=str, default=None,
        help='JSON map of workspace_id -> maxVisible, e.g. \'{"3":2,"1":4}\'',
    )
    parser.add_argument(
        "--config-file", type=str, default=None,
        help="path to runtime config file for hot-reload via SIGUSR1",
    )
    parser.add_argument(
        "--debug", action="store_true",
        help="enable debug logging",
    )
    return parser.parse_args()


# ─── Hot Reload ───
def reload_config() -> None:
    """Reload configuration from CONFIG_FILE and trigger redistribution."""
    global MAX_VISIBLE, PER_WORKSPACE, WORKSPACE_MAX_VISIBLE, ONLY_AT_MAX

    if not CONFIG_FILE or not os.path.isfile(CONFIG_FILE):
        log.warning("no config file to reload")
        return

    try:
        with open(CONFIG_FILE) as f:
            cfg = json.load(f)
    except (OSError, json.JSONDecodeError) as exc:
        log.warning("failed to read config file: %s", exc)
        return

    if not isinstance(cfg, dict):
        return

    old_max = MAX_VISIBLE
    if "maxVisible" in cfg:
        MAX_VISIBLE = max(1, int(cfg["maxVisible"]))
    if "onlyAtMax" in cfg:
        ONLY_AT_MAX = bool(cfg["onlyAtMax"])
    if "perWorkspace" in cfg:
        PER_WORKSPACE = bool(cfg["perWorkspace"])
    if "workspaceMaxVisible" in cfg:
        raw = cfg["workspaceMaxVisible"]
        if isinstance(raw, dict):
            WORKSPACE_MAX_VISIBLE = {
                int(k): max(1, int(v))
                for k, v in raw.items()
                if str(k).isdigit() and str(v).isdigit()
            }

    log.info("config reloaded (max_visible=%d)", MAX_VISIBLE)

    # Clear cached state so redistribution runs with new config
    with _lock:
        _prev_col_counts.clear()
    redistribute()


# ─── Main ───
def main() -> None:
    """Main entry point with reconnection loop."""
    global MAX_VISIBLE, DEBOUNCE_SECONDS, MAX_EVENTS_PER_SECOND
    global PER_WORKSPACE, WORKSPACE_MAX_VISIBLE, ONLY_AT_MAX, CONFIG_FILE

    args = parse_args()

    # Apply CLI overrides
    if args.max_visible is not None:
        MAX_VISIBLE = max(1, args.max_visible)
    if args.debounce is not None:
        DEBOUNCE_SECONDS = max(0.05, args.debounce)
    if args.max_events is not None:
        MAX_EVENTS_PER_SECOND = max(1, args.max_events)
    if args.only_at_max:
        ONLY_AT_MAX = True
    if args.per_workspace:
        PER_WORKSPACE = True
    if args.workspace_config:
        try:
            raw = json.loads(args.workspace_config)
            if isinstance(raw, dict):
                WORKSPACE_MAX_VISIBLE = {
                    int(k): max(1, int(v))
                    for k, v in raw.items()
                    if str(k).isdigit() and str(v).isdigit()
                }
        except (json.JSONDecodeError, ValueError) as exc:
            log.warning("invalid --workspace-config: %s", exc)
    if args.config_file:
        CONFIG_FILE = args.config_file
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    # Handle SIGTERM for graceful shutdown
    def _shutdown(signum, frame):
        # Timer.cancel() is thread-safe; avoid _lock here to prevent deadlock
        t = _debounce_timer
        if t is not None:
            t.cancel()
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, _shutdown)

    # Handle SIGUSR1 for hot config reload (no restart needed)
    def _reload(signum, frame):
        reload_config()
    signal.signal(signal.SIGUSR1, _reload)

    mode = "per-workspace" if PER_WORKSPACE else "global"
    ws_cfg = f", ws_config={WORKSPACE_MAX_VISIBLE}" if WORKSPACE_MAX_VISIBLE else ""
    log.info("starting (max_visible=%d, mode=%s, debounce=%gms%s)",
             MAX_VISIBLE, mode, DEBOUNCE_SECONDS * 1000, ws_cfg)

    while True:
        try:
            run_event_loop()
            log.warning("event stream ended, reconnecting in %gs", RECONNECT_DELAY)
        except KeyboardInterrupt:
            log.info("shutting down")
            break
        except Exception as exc:
            log.error("event loop crashed: %s, reconnecting in %gs", exc, RECONNECT_DELAY)
        time.sleep(RECONNECT_DELAY)


if __name__ == "__main__":
    main()
