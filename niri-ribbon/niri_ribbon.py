#!/usr/bin/env python3
import json
import subprocess
import sys
import os

# Log file for debugging
DEBUG_LOG = os.path.expanduser("~/noctalia_niri_ribbon.log")

def log(msg):
    with open(DEBUG_LOG, "a") as f:
        f.write(f"{msg}\n")

def get_niri_state():
    """Fetches the current windows, workspaces and outputs from niri."""
    try:
        # Get windows
        res_win = subprocess.run(["niri", "msg", "-j", "windows"], capture_output=True, text=True)
        if res_win.returncode != 0: return None, None, None
        windows = json.loads(res_win.stdout)
        
        # Get workspaces
        res_ws = subprocess.run(["niri", "msg", "-j", "workspaces"], capture_output=True, text=True)
        if res_ws.returncode != 0: return None, None, None
        workspaces = json.loads(res_ws.stdout)

        # Get outputs
        res_out = subprocess.run(["niri", "msg", "-j", "outputs"], capture_output=True, text=True)
        if res_out.returncode != 0: return None, None, None
        outputs = json.loads(res_out.stdout)
        
        return windows, workspaces, outputs
    except Exception as e:
        log(f"Error fetching state: {e}")
        return None, None, None

def calculate_ribbon(last_view_data=None):
    """Calculates the ribbon viewport ratios."""
    windows, workspaces, outputs = get_niri_state()
    if not windows or not workspaces or not outputs:
        print("0|0|0|1", flush=True)
        return

    # Find the focused workspace (active interaction), fallback to first active
    focused_ws = next((ws for ws in workspaces if ws.get("is_focused")), None)
    if not focused_ws:
        focused_ws = next((ws for ws in workspaces if ws.get("is_active")), None)
        
    if not focused_ws:
        print("0|0|0|1", flush=True)
        return

    ws_id = focused_ws.get("id")
    output_name = focused_ws.get("output")
    active_win_id = focused_ws.get("active_window_id")
    
    output_data = outputs.get(output_name, {})
    view_width = output_data.get("logical", {}).get("width", 1920)

    ws_windows = [w for w in windows if w.get("workspace_id") == ws_id and not w.get("is_floating")]
    
    if not ws_windows:
        print("0|0|0|1", flush=True)
        return

    columns = {}
    for w in ws_windows:
        layout = w.get("layout", {})
        pos = layout.get("pos_in_scrolling_layout")
        if pos:
            col_idx = pos[0]
            width = layout.get("tile_size", [0])[0]
            if col_idx not in columns:
                columns[col_idx] = width
    
    sorted_col_indices = sorted(columns.keys())
    total_width = sum(columns.values())
    
    # Logic for proportions: 
    # If there is only one column, it should fill the whole track.
    # Otherwise, it should be view_width / total_width.
    if len(sorted_col_indices) <= 1:
        ratio_start = 0.0
        ratio_width = 1.0
    else:
        canvas_width = max(total_width, view_width)
        
        view_x = 0
        # Use real-time view data if available and for the correct workspace
        if last_view_data and last_view_data.get("workspace_id") == ws_id:
            view_x = last_view_data.get("x", 0)
        else:
            # Fallback: Use the workspace's active window or globally focused window
            target_win_id = active_win_id
            if target_win_id is None:
                f_win = next((w for w in windows if w.get("is_focused")), None)
                if f_win and f_win.get("workspace_id") == ws_id:
                    target_win_id = f_win.get("id")
            
            target_win = next((w for w in ws_windows if w.get("id") == target_win_id), None)
            if not target_win and ws_windows:
                target_win = ws_windows[0]

            if target_win:
                f_layout = target_win.get("layout", {})
                f_idx = f_layout.get("pos_in_scrolling_layout", [0])[0]
                start_px_from_first = sum(columns[idx] for idx in sorted_col_indices if idx < f_idx)
                f_width = columns.get(f_idx, 0)
                # niri centers focused window, so offset view center to screen center
                view_x = -(start_px_from_first + f_width/2 - view_width/2)
            else:
                view_x = 0

        ratio_start = -view_x / canvas_width
        ratio_width = view_width / canvas_width
    
    # Clamp to [0, 1]
    ratio_start = max(0.0, min(1.0, ratio_start))
    ratio_width = max(0.01, min(1.0, ratio_width))
    
    if ratio_start + ratio_width > 1.0:
        ratio_start = 1.0 - ratio_width

    print(f"0|0|{ratio_start:.4f}|{ratio_width:.4f}", flush=True)

def main():
    if os.path.exists(DEBUG_LOG):
        os.remove(DEBUG_LOG)
    
    calculate_ribbon()
    
    try:
        process = subprocess.Popen(
            ["niri", "msg", "-j", "event-stream"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
        
        last_view = None
        
        # Events that should trigger a full recalculation
        for line in process.stdout:
            try:
                event = json.loads(line)
                
                # Check for explicit view scroll
                if "WorkspaceViewChanged" in event:
                    last_view = event["WorkspaceViewChanged"]
                    calculate_ribbon(last_view)
                    continue

                # Check for workspace change - invalidate view data
                if "WorkspaceActivated" in event:
                    last_view = None
                    calculate_ribbon()
                    continue

                # Check for other structural changes
                if any(k in event for k in [
                    "WindowOpenedOrChanged", 
                    "WindowClosed", 
                    "WorkspaceActiveWindowChanged",
                    "WindowFocusChanged",
                    "WindowsChanged",
                    "WorkspacesChanged"
                ]):
                    calculate_ribbon(last_view)
            except Exception:
                continue
                
    except KeyboardInterrupt:
        pass
    finally:
        if 'process' in locals():
            process.terminate()

if __name__ == "__main__":
    main()
