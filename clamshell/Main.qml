// Main.qml — clamshell plugin background logic.
//
// Responsibilities:
//  - Watch niri's `event-stream` for output-related events.
//  - On any output-related event, query `niri msg --json outputs` and recompute
//    `externalPresent` against `internalConnectorRegex`.
//  - Maintain reconnection with exponential backoff if the event-stream dies.
//  - Detect at startup whether `systemd-inhibit` is available on PATH.
//  - Own the single `systemd-inhibit` Process and plugin IPC target.
//  - Expose state to widgets through Noctalia's pluginApi.mainInstance.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    // ───── Plugin API injection ──────────────────────────────────────────
    // Noctalia's PluginService injects this. Settings are read with the
    // standard cfg/defaults fallback chain documented in AGENTS.md.
    property var pluginApi: null

    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings
        || pluginApi?.manifest?.defaultSettings
        || ({})

    readonly property string internalConnectorRegex: cfg.internalConnectorRegex
        ?? defaults.internalConnectorRegex
        ?? "^(eDP|LVDS|DSI)"
    readonly property bool notifyEnabled: cfg.notify !== undefined
        ? cfg.notify
        : (defaults.notify !== undefined ? defaults.notify : true)
    readonly property string inhibitorWho: cfg.inhibitorWho
        ?? defaults.inhibitorWho
        ?? "noctalia-clamshell"

    // ───── Public state (consumed by widgets via mainInstance) ───────────
    // `enabled` is the user-facing toggle. Writes are immediately persisted
    // because widgets and IPC mutate this property directly.
    property bool enabled: (cfg.enabled !== undefined)
        ? cfg.enabled
        : (defaults.enabled !== undefined ? defaults.enabled : true)

    // `externalPresent` reflects whether at least one non-internal output is
    // physically connected (modes array non-empty), regardless of whether
    // the user has disabled it via `niri msg output ... off`.
    property bool externalPresent: false

    readonly property bool inhibitorActive: inhibitorProc.running

    // `inhibitorAvailable` is set by the `which systemd-inhibit` probe
    // below. While the probe is in flight we optimistically assume true.
    property bool inhibitorAvailable: true

    // `outputs` is the canonical, deduplicated list of monitor descriptors
    // that the IPC `status` call (Task 4) and Settings UI consume. Each
    // entry is { name, internal, connected, active }.
    property var outputs: []
    property var lastOutputsPayload: null

    readonly property int inhibitorPid: inhibitorProc.processId ? Number(inhibitorProc.processId) : 0
    property bool componentReady: false

    // Emitted whenever any of the three primary state-bools change. This is
    // part of the public mainInstance contract (spec §8).
    signal stateChanged

    onEnabledChanged: {
        persistEnabled();
        stateChanged();
    }
    onExternalPresentChanged: stateChanged()
    onInhibitorActiveChanged: stateChanged()

    // ───── Backoff state for event-stream reconnection ───────────────────
    // We start at 2 s and double up to 30 s; reset to 2 s on any successful
    // connect (i.e. when the process emits `started`). During downtime we
    // deliberately preserve the last-known `externalPresent` so that a
    // transient niri restart doesn't drop the inhibitor (spec §4.4).
    readonly property int backoffMinMs: 2000
    readonly property int backoffMaxMs: 30000
    property int currentBackoffMs: backoffMinMs

    // ───── Logging tag ───────────────────────────────────────────────────
    readonly property string logTag: "Clamshell"

    // ─────────────────────────────────────────────────────────────────────
    // Public methods (spec §8).
    function enable() {
        if (!root.inhibitorAvailable) {
            root.enabled = false;
            return "error:no-systemd-inhibit";
        }
        root.enabled = true;
        return "ok";
    }

    function disable() {
        root.enabled = false;
        return "ok";
    }

    function toggle() {
        if (root.enabled) {
            root.disable();
        } else {
            root.enable();
        }
        return root.enabled ? "on" : "off";
    }

    function refresh() {
        fetchOutputs();
        return "ok";
    }

    function applySettings() {
        root.enabled = (cfg.enabled !== undefined)
            ? cfg.enabled
            : (defaults.enabled !== undefined ? defaults.enabled : true);
        if (root.lastOutputsPayload) {
            classifyOutputs(root.lastOutputsPayload);
        }
    }

    function persistEnabled() {
        if (!pluginApi || !pluginApi.pluginSettings) return;
        if (pluginApi.pluginSettings.enabled === root.enabled) return;
        pluginApi.pluginSettings.enabled = root.enabled;
        pluginApi.saveSettings();
    }

    function status() {
        var out = [];
        for (var i = 0; i < root.outputs.length; ++i) {
            var o = root.outputs[i];
            out.push({
                name: o.name,
                internal: !!o.internal,
                active: !!o.active
            });
        }
        return JSON.stringify({
            enabled: root.enabled,
            externalPresent: root.externalPresent,
            inhibitorActive: root.inhibitorActive,
            inhibitorAvailable: root.inhibitorAvailable,
            inhibitorPid: root.inhibitorPid,
            outputs: out
        });
    }

    function stateLabel() {
        if (!root.enabled) return pluginApi?.tr("state.disabled");
        if (root.externalPresent) return pluginApi?.tr("state.active");
        return pluginApi?.tr("state.standby");
    }

    function outputSummary() {
        var parts = [];
        for (var i = 0; i < root.outputs.length; ++i) {
            var o = root.outputs[i];
            parts.push(o.name + (o.internal ? " (internal)" : " (external)"));
        }
        return parts.join(", ");
    }

    IpcHandler {
        target: "plugin:clamshell"

        function enable() {
            return root.enable();
        }

        function disable() {
            return root.disable();
        }

        function toggle() {
            return root.toggle();
        }

        function refresh() {
            return root.refresh();
        }

        function status() {
            return root.status();
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Output classification.
    //
    // niri's `Outputs` response is a JSON object keyed by output name
    // (HashMap<String, Output> in niri-ipc). Each Output has at minimum:
    //   { name, modes: [...], current_mode: int|null, ... }
    //
    // Connected: a monitor is physically present iff `modes` is a non-empty
    // array. Disabled-by-user (`niri msg output X off`) yields current_mode
    // = null but modes is still populated.
    //
    // External: name does not match the internalConnectorRegex. We compile
    // the regex once per fetch (cheap, and accounts for Settings changes).
    function classifyOutputs(outputsObj) {
        root.lastOutputsPayload = outputsObj;

        var rx;
        try {
            rx = new RegExp(root.internalConnectorRegex);
        } catch (e) {
            Logger.w(root.logTag, "Invalid internalConnectorRegex:", root.internalConnectorRegex, "— treating all outputs as external. Error:", e);
            rx = null;
        }

        var list = [];
        var hasExternal = false;

        // Outputs response may legally be either an object map (current
        // niri-ipc) or an array (older niri builds / fixtures). Handle both.
        if (Array.isArray(outputsObj)) {
            for (var i = 0; i < outputsObj.length; ++i) {
                var entry = outputsObj[i];
                if (!entry || typeof entry.name !== "string") continue;
                var rec = makeOutputRecord(entry, entry.name, rx);
                list.push(rec);
                if (!rec.internal && rec.connected) hasExternal = true;
            }
        } else if (outputsObj && typeof outputsObj === "object") {
            var names = Object.keys(outputsObj);
            for (var j = 0; j < names.length; ++j) {
                var name = names[j];
                var data = outputsObj[name] || {};
                var rec2 = makeOutputRecord(data, name, rx);
                list.push(rec2);
                if (!rec2.internal && rec2.connected) hasExternal = true;
            }
        }

        // Stable order — consumers (Settings UI) expect a deterministic list.
        list.sort(function(a, b) { return a.name.localeCompare(b.name); });

        root.outputs = list;
        root.externalPresent = hasExternal;
    }

    function makeOutputRecord(data, name, rx) {
        var modes = Array.isArray(data.modes) ? data.modes : [];
        var connected = modes.length > 0;
        var active = data.current_mode !== null && data.current_mode !== undefined;
        var internal = rx ? rx.test(name) : false;
        return {
            name: name,
            internal: internal,
            connected: connected,
            active: active
        };
    }

    // ─────────────────────────────────────────────────────────────────────
    // niri-related processes.
    //
    // `outputsProc` — one-shot. Fetches the full outputs map; uses
    // StdioCollector since the response is a single JSON document.
    //
    // `eventStreamProc` — long-lived. Each line is one Event JSON object;
    // SplitParser delivers one signal per newline-delimited chunk.
    //
    // `inhibitProbeProc` — one-shot at startup, checks `which systemd-inhibit`
    // and flips inhibitorAvailable based on exit code.

    function fetchOutputs() {
        if (outputsProc.running) {
            // Coalesce: a fetch is already in flight. The active fetch will
            // reflect the most recent state once it returns. niri events are
            // edge-triggered and we always re-query on the next event anyway.
            return;
        }
        outputsProc.running = true;
    }

    Process {
        id: outputsProc
        command: ["niri", "msg", "--json", "outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text;
                if (!raw) {
                    Logger.w(root.logTag, "niri outputs returned empty payload");
                    return;
                }
                try {
                    var parsed = JSON.parse(raw);
                    classifyOutputs(parsed);
                    Logger.d(root.logTag, "Outputs refreshed; externalPresent=" + root.externalPresent + ", count=" + root.outputs.length);
                } catch (e) {
                    Logger.w(root.logTag, "Failed to parse niri outputs JSON:", e, "raw[0..200]=", raw.substring(0, 200));
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Logger.w(root.logTag, "niri msg outputs exited with code", exitCode);
            }
        }
    }

    // ───── Event-stream consumer ─────────────────────────────────────────
    // niri-ipc Event variants of interest are anything containing "Output"
    // in the top-level key (see niri-ipc::Event). Unknown event variants
    // are silently ignored — niri documents that consumers must tolerate
    // future additions.
    Process {
        id: eventStreamProc
        command: ["niri", "msg", "--json", "event-stream"]

        // Don't auto-start: Component.onCompleted starts it after the
        // inhibitor-availability probe schedules so that startup ordering
        // is deterministic.
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleEventLine(data)
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.length > 0) {
                    Logger.w(root.logTag, "event-stream stderr:", data);
                }
            }
        }

        onStarted: {
            Logger.i(root.logTag, "niri event-stream connected");
            // Successful connect — reset backoff and refresh outputs.
            // We don't trust the stream's initial frames to carry output
            // state (current niri-ipc has no Outputs* event), so we always
            // do an explicit one-shot fetch on (re)connect.
            root.currentBackoffMs = root.backoffMinMs;
            root.fetchOutputs();
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.componentReady) {
                return;
            }
            Logger.w(root.logTag, "niri event-stream exited; code=" + exitCode + " status=" + exitStatus + " — reconnect in " + root.currentBackoffMs + "ms");
            // Preserve last-known externalPresent during downtime — see
            // spec §4.4: do NOT drop the inhibitor on a transient stream
            // failure.
            backoffTimer.interval = root.currentBackoffMs;
            backoffTimer.restart();
            // Double the next delay (clamped). Reset happens in onStarted.
            root.currentBackoffMs = Math.min(root.currentBackoffMs * 2, root.backoffMaxMs);
        }
    }

    function handleEventLine(line) {
        var trimmed = (line || "").trim();
        if (!trimmed) return;

        var parsed;
        try {
            parsed = JSON.parse(trimmed);
        } catch (e) {
            Logger.w(root.logTag, "Failed to parse event-stream line:", e, "raw=", trimmed.substring(0, 200));
            return;
        }
        if (!parsed || typeof parsed !== "object") return;

        var keys = Object.keys(parsed);
        for (var i = 0; i < keys.length; ++i) {
            if (keys[i].indexOf("Output") !== -1) {
                // Fast path: known output-related event — fetch immediately.
                Logger.d(root.logTag, "Output-related event:", keys[i]);
                root.fetchOutputs();
                return;
            }
        }

        // §4.2 fallback: niri-ipc currently has no Output* Event variants.
        // Re-fetch outputs on any event so real-time hotplug is detected
        // (niri generates WorkspacesChanged etc. when monitor topology changes).
        // The debounce timer coalesces rapid bursts into a single fetch.
        outputsDebounce.restart();
    }

    Timer {
        id: backoffTimer
        repeat: false
        interval: root.backoffMinMs
        onTriggered: {
            if (!eventStreamProc.running) {
                Logger.i(root.logTag, "Reconnecting niri event-stream...");
                eventStreamProc.running = true;
            }
        }
    }

    // Debounce timer for the §4.2 fallback: any niri event triggers an
    // outputs re-fetch, but we batch rapid bursts to avoid spawning a
    // subprocess per event. 300 ms is long enough to coalesce a burst but
    // short enough to feel responsive on hotplug.
    Timer {
        id: outputsDebounce
        repeat: false
        interval: 300
        onTriggered: root.fetchOutputs()
    }

    // ───── systemd-inhibit availability probe ────────────────────────────
    // Runs once at startup. If `which systemd-inhibit` exits non-zero we
    // flip `inhibitorAvailable` to false and the UI/widgets will treat the
    // plugin as permanently inert (spec §5.3).
    Process {
        id: inhibitProbeProc
        command: ["which", "systemd-inhibit"]
        // StdioCollector silences stdout — we only care about the exit code.
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.inhibitorAvailable = true;
                Logger.d(root.logTag, "systemd-inhibit found");
            } else {
                root.inhibitorAvailable = false;
                root.enabled = false;
                Logger.w(root.logTag, "systemd-inhibit not found in PATH (which exit=" + exitCode + ") — clamshell inhibition disabled");
            }
        }
    }

    // ───── systemd-inhibit lifecycle ────────────────────────────────────
    // Quickshell sends SIGTERM when Process.running becomes false and kills
    // tracked children when the shell exits. Binding `running` keeps the
    // process count at zero or one.
    Process {
        id: inhibitorProc
        running: root.enabled && root.externalPresent && root.inhibitorAvailable
        command: [
            "systemd-inhibit",
            "--what=handle-lid-switch",
            "--who=" + root.inhibitorWho,
            "--why=Clamshell mode - external display in use",
            "--mode=block",
            "sleep", "infinity"
        ]

        stdout: StdioCollector {}
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data && data.length > 0) {
                    Logger.w(root.logTag, "systemd-inhibit stderr:", data);
                }
            }
        }

        onStarted: {
            Logger.i(root.logTag, "systemd-inhibit started; pid=" + root.inhibitorPid);
            root.notifyInhibitorChange(true);
        }

        onExited: (exitCode, exitStatus) => {
            Logger.i(root.logTag, "systemd-inhibit exited; code=" + exitCode + " status=" + exitStatus);
            root.notifyInhibitorChange(false);
        }
    }

    function notifyInhibitorChange(active) {
        if (!root.componentReady || !root.notifyEnabled) return;

        var msg = active
            ? pluginApi?.tr("notify.on")
            : pluginApi?.tr("notify.off");
        ToastService.showNotice("Clamshell Mode", msg, "device-desktop");
    }

    // ─────────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        root.componentReady = true;
        Logger.i(root.logTag, "Main.qml initialised; internalConnectorRegex=" + root.internalConnectorRegex);
        // Probe systemd-inhibit availability first (cheap, async).
        inhibitProbeProc.running = true;
        // Start the event stream. Initial outputs fetch happens in
        // eventStreamProc.onStarted so we always have a fresh snapshot
        // immediately after the stream comes up.
        eventStreamProc.running = true;
    }

    Component.onDestruction: {
        root.componentReady = false;
        // Stop the long-lived stream cleanly so we don't leak processes
        // across Noctalia reloads. Quickshell's Process should SIGTERM on
        // running=false, but we stop the backoff timer too so a queued
        // reconnect can't race with destruction.
        backoffTimer.stop();
        if (eventStreamProc.running) {
            eventStreamProc.running = false;
        }
        if (inhibitorProc.running) {
            inhibitorProc.running = false;
        }
    }
}
