#!/usr/bin/env bash
# screencast-gif.sh — toggle screen recording, convert to GIF, copy to clipboard.
#
# Designed to be invoked twice as a toggle: first call selects a region with slurp
# and starts wf-recorder; second call stops the recorder, runs ffmpeg + gifski to
# produce a .gif, copies it to the Wayland clipboard as image/gif, and saves the
# file to OUTDIR.
#
# Environment variables (all optional):
#   FPS                       GIF frame rate. Default: 20.
#   MAX_SECS                  Auto-stop after this many seconds. 0 disables. Default: 120.
#   OUTDIR                    Where to save the GIF. Tilde is expanded. Default: ~/Screenshots.
#   SCREENCAST_GIF_REGION     Skip slurp and use this region (format: "X,Y WxH"). For tests.
#   SCREENCAST_GIF_LOG        Log file path. Default: /tmp/screencast-gif.log.
#   SCREENCAST_GIF_PIDFILE    PID file path. Default: /tmp/screencast-gif.pid.
#   SCREENCAST_GIF_LOCKFILE   Lock file path. Default: /tmp/screencast-gif.lock.
#   SCREENCAST_GIF_WORKDIR    Working directory for per-recording mp4/frames. Default: /tmp/screencast-gif.

set -euo pipefail

LOGFILE=${SCREENCAST_GIF_LOG:-/tmp/screencast-gif.log}
exec >> "$LOGFILE" 2>&1
echo "=== $(date +%T.%N) invoked pid=$$ args='$*' ==="

LOCKFILE=${SCREENCAST_GIF_LOCKFILE:-/tmp/screencast-gif.lock}
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "  another instance holds lock, exiting"
    exit 0
fi

PIDFILE=${SCREENCAST_GIF_PIDFILE:-/tmp/screencast-gif.pid}
WORKDIR=${SCREENCAST_GIF_WORKDIR:-/tmp/screencast-gif}
OUTDIR=${OUTDIR:-$HOME/Screenshots}
OUTDIR=${OUTDIR/#\~/$HOME}
FPS=${FPS:-20}
MAX_SECS=${MAX_SECS:-120}

notify() { notify-send -a screencast-gif "$@"; }

# Close every fd above stderr in the *current* shell. Used right before
# spawning long-lived background processes so they don't keep parent-inherited
# pipes alive — notably fd 3, which test harnesses such as bats use to capture
# output. A leaked writer prevents the harness from reaching EOF and makes it
# hang for as long as the watchdog/recorder lives.
close_extra_fds() {
    local d fd
    for d in /proc/self/fd/*; do
        fd=${d##*/}
        case $fd in 0|1|2) ;; *) eval "exec $fd>&-" 2>/dev/null ;; esac
    done
}

if [[ -f $PIDFILE ]] && kill -0 "$(awk '{print $1}' "$PIDFILE")" 2>/dev/null; then
    read -r PID RUNDIR < "$PIDFILE"
    echo "  STOP branch, PID=$PID rundir=$RUNDIR"
    rm -f "$PIDFILE"
    flock -u 9
    exec 9>&-

    kill -INT "$PID"
    while kill -0 "$PID" 2>/dev/null; do sleep 0.1; done

    notify "Converting to GIF…"
    FRAMES="$RUNDIR/frames"
    mkdir -p "$FRAMES"
    ffmpeg -loglevel error -i "$RUNDIR/rec.mp4" -vf "fps=$FPS" "$FRAMES/%05d.png"

    mkdir -p "$OUTDIR"
    OUT="$OUTDIR/screencast_$(date +%Y%m%d_%H%M%S).gif"
    gifski -o "$OUT" --fps "$FPS" "$FRAMES"/*.png >/dev/null
    rm -rf "$RUNDIR"

    # wl-copy forks a daemon that serves the clipboard data until it's
    # replaced; the daemon inherits all parent fds, which would keep test
    # harness pipes alive and make `bats` hang. Strip extras first.
    ( close_extra_fds; exec wl-copy --type image/gif < "$OUT" )
    notify "GIF in clipboard" "$OUT"
else
    echo "  START branch"
    if [[ -n ${SCREENCAST_GIF_REGION:-} ]]; then
        REGION=$SCREENCAST_GIF_REGION
        echo "  region=$REGION (from env)"
    else
        echo "  calling slurp"
        REGION=$(slurp) || { echo "  slurp cancelled/failed (rc=$?)"; exit 0; }
        echo "  region=$REGION (from slurp)"
    fi
    # h264/yuv420p requires even dimensions; round X,Y down and W,H up to even.
    if [[ $REGION =~ ^([0-9]+),([0-9]+)\ ([0-9]+)x([0-9]+)$ ]]; then
        x=$(( BASH_REMATCH[1] & ~1 ))
        y=$(( BASH_REMATCH[2] & ~1 ))
        w=$(( (BASH_REMATCH[3] + 1) & ~1 ))
        h=$(( (BASH_REMATCH[4] + 1) & ~1 ))
        REGION="${x},${y} ${w}x${h}"
        echo "  region rounded to $REGION"
    fi

    RUN_ID=$(date +%s%N)
    RUNDIR="$WORKDIR/$RUN_ID"
    mkdir -p "$RUNDIR" "$OUTDIR"

    # -D / --no-damage: capture every compositor frame, not just damage events.
    # Without this, static regions yield single-frame GIFs because wf-recorder
    # waits for screen changes before requesting frames.
    (
        close_extra_fds
        exec wf-recorder --no-dmabuf -D --pixel-format yuv420p \
            -g "$REGION" -f "$RUNDIR/rec.mp4"
    ) </dev/null >>"$LOGFILE" 2>&1 &
    PID=$!
    disown
    echo "$PID $RUNDIR" > "$PIDFILE"

    SELF="$(readlink -f "$0")"
    if (( MAX_SECS > 0 )); then
        (
            close_extra_fds
            sleep "$MAX_SECS"
            if [[ -f $PIDFILE ]] && [[ "$(awk '{print $1}' "$PIDFILE" 2>/dev/null)" == "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
                "$SELF"
            fi
        ) </dev/null >/dev/null 2>&1 &
        disown
    fi
fi
