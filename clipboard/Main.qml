import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Persistent background singleton for the clipboard plugin.
// The shell instantiates this once when the plugin loads and keeps it alive
// until the shell exits. It has no physical dimensions and is never rendered.
//
// Responsibilities (per docs/specs/plugin-entry-point-contracts.md):
//   - Wrap cliphist as the data backend for the clipboard history list.
//   - Expose items / itemsRevision as shared state for Panel/BarWidget/Settings.
//   - Expose refresh / copy / remove / wipe via pluginApi.mainInstance.
//
// Patterns used (per docs/specs/plugin-qml-idioms.md):
//   - Process + StdioCollector for shell commands.
//   - Revision counter so QML bindings re-evaluate on in-place list changes.
//   - Component.onDestruction stops any running Process so shell reload leaves
//     no orphaned cliphist children (the 500+ refresh memory acceptance test).
Item {
    id: root

    // Injected by the shell after instantiation. Always null-guard access with
    // optional chaining (?.) — see docs/specs/plugin-qml-idioms.md.
    property var pluginApi: null

    // --- Shared state exposed via pluginApi.mainInstance ---------------------

    // Parsed output of `cliphist list`. Each element is { id, preview, type }
    // where id is the numeric cliphist entry id as a string, preview is the
    // text up to the first tab, and type is "text" or "image" based on
    // whether the preview matches the "[[ binary data ... ]]" marker that
    // cliphist emits for non-text entries. Type detection drives rendering
    // in ClipboardItem.qml — see docs/specs/image-previews.md.
    property var items: []

    // Incremented on every completed mutation of `items`, including empty
    // resets after parse or exit errors. Consumers bind to this to stay
    // reactive, since QML does not fire bindings on in-place array changes.
    property int itemsRevision: 0

    // --- Pinned items --------------------------------------------------------
    //
    // User-pinned clipboard entries that must survive `cliphist wipe` and
    // shell restarts. Pinned items live OUTSIDE the cliphist backing store —
    // they are persisted to a JSON file owned by this plugin and merged into
    // the Panel's display list at render time.
    //
    // Each entry is `{ preview, type }`. No `id` key — pinned entries have
    // no cliphist id (the original cliphist row may have been wiped). Within
    // a session, pinned entries are keyed by their positional index in this
    // array (unpin(index)). See docs/specs/pinned-items.md.
    property var pinnedItems: []

    // Revision counter for pinnedItems, same idiom as itemsRevision — any
    // binding that reads a pinned-list derived value must also read
    // pinnedRevision so QML re-evaluates on in-place mutations. Bumped by
    // pin(), unpin(), and pinnedFile.onLoaded.
    property int pinnedRevision: 0

    // Base directory for all plugin-owned runtime files. Using the cache
    // directory keeps mutable state out of the user's config tree.
    readonly property string dataDir: (Quickshell.env("HOME") || "") + "/.cache/noctalia/plugins/clipboard"

    // Absolute path to the pinned JSON file. Resolved at construction so
    // both pinnedFile.path and the save function below read the same value.
    readonly property string pinnedPath: root.dataDir + "/pinned.json"

    // --- LRU image cache -----------------------------------------------------
    //
    // Maps cliphist entry id (string) → "file:///tmp/..." URL of the decoded
    // image on disk. The cache is bounded to maxImageCacheSize entries with
    // LRU eviction so a long history of binary entries can't grow unbounded.
    //
    // Pattern verbatim from docs/specs/plugin-qml-idioms.md (LRU cache
    // pattern) — cache, order array, and revision counter in lockstep.
    // Replacing references (Object.assign, array spreads) instead of
    // mutating in place is the reason QML bindings on imageCache re-fire
    // when entries are added or evicted.

    // id → file:// URL. Populated by getImage(id).
    property var imageCache: ({})

    // Ordered list of ids, oldest first. Tail is most-recently-used.
    property var imageCacheOrder: []

    // Reactive signal that increments on every cache mutation. Consumers in
    // ClipboardItem.qml read it alongside imageCache[entryId] so the Image
    // source binding re-evaluates when a decode completes.
    property int imageCacheRevision: 0

    // Hard cap. Bounds worst-case memory regardless of how many binary
    // entries `cliphist list` returns.
    readonly property int maxImageCacheSize: 50

    // Id of the decode currently in flight ("" when idle).
    property string decodingId: ""

    // Sends Ctrl+V after the panel has closed and focus has returned to the
    // previously active window. The explicit Wayland environment keeps wtype
    // working when Noctalia is launched as a user service.
    function pasteIntoPreviousWindow() {
        if (pasteProc.running)
            return;
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR") || "";
        const waylandDisplay = Quickshell.env("WAYLAND_DISPLAY") || "";
        pasteProc.command = ["bash", "-c",
            'sleep 0.5; XDG_RUNTIME_DIR="$1" WAYLAND_DISPLAY="$2" wtype -M ctrl -P v -p v -m ctrl',
            "--", runtimeDir, waylandDisplay];
        pasteProc.running = true;
    }

    // Pending ids waiting for decodeProc to become free. FIFO — delegates
    // are rendered top-to-bottom so the first enqueued id is the most
    // visible one.
    property var decodeQueue: []

    // --- File metadata cache ------------------------------------------------
    //
    // Maps cliphist entry id (string) →
    //   { filename, parentDir, sizeBytes, sizeHuman }
    //
    // Populated by getFileMeta(id) via a single queued `stat` Process
    // (metaProc). The cache bounds worst-case memory at maxImageCacheSize
    // entries using the same LRU pattern as imageCache — see
    // docs/specs/plugin-qml-idioms.md (LRU cache pattern). A dedicated
    // queue + in-flight id pair (metaQueue / metaFetchingId) means a
    // scroll through a file-heavy history does not stampede `stat` calls.
    //
    // Entries for missing/unreadable files are still cached: sizeBytes
    // is set to -1 and sizeHuman is "". The delegate reads those values
    // directly, so broken links still render basename + parent path.
    property var fileMetaCache: ({})
    property var fileMetaOrder: []
    property int fileMetaRevision: 0

    // Id of the metadata fetch currently in flight ("" when idle).
    property string metaFetchingId: ""

    // Pending ids waiting for metaProc to become free. FIFO for the same
    // reason as decodeQueue — the topmost visible row's metadata should
    // resolve first.
    property var metaQueue: []

    // --- Relative-time state -------------------------------------------------
    //
    // `copiedAt` maps cliphist id (string) → ISO 8601 timestamp of the moment
    // the plugin first observed that id in a list refresh. It is NOT the
    // time the user copied the entry in reality — cliphist does not persist
    // per-entry timestamps and we are seeded at plugin load with whatever
    // history is already in the store. "First observed by this plugin run"
    // is the contract the spec promises; existing ids retain their
    // timestamp across re-copy events, so "3m ago" does not reset when the
    // user copies the same text again (same id stays in cliphist).
    //
    // Persistence: the map is mirrored to
    // ~/.cache/noctalia/plugins/clipboard/copied-at.json so that
    // timestamps survive shell restarts. Without persistence every id is
    // stamped `now` on first observation after a restart and the whole
    // list renders as "just now" (issue: persist-copied-at). The file is
    // loaded once by copiedAtFile.onLoaded and rewritten by
    // copiedAtWriteProc after every mutation inside listProc.onExited. We
    // are the sole writer (watchChanges: false) — the listProc path merges
    // disk state into `prior` via the initial assignment in onLoaded, and
    // subsequent refreshes read `prior` from the in-memory map.
    //
    // `timeRevision` is the reactive signal consumed by ClipboardItem.qml —
    // every Timer tick increments it, forcing any binding that reads it to
    // re-evaluate `formatRelativeTime(copiedAt[id])`. See
    // docs/specs/plugin-qml-idioms.md (revision counter section) and
    // docs/specs/relative-time-display.md (ticker contract).
    //
    // The map itself is replaced by reference on every mutation (same idiom
    // as imageCache / fileMetaCache) so QML bindings fire. No revision
    // counter for copiedAt specifically — mutations only happen inside
    // listProc.onExited, and consumers already bind to itemsRevision there.
    property var copiedAt: ({})
    property int timeRevision: 0

    // Set to true once copiedAtFile.onLoaded has fired (even if the file is
    // absent or malformed — onLoaded fires on both success and parse-failure
    // paths via the try/catch below). Used to gate saveCopiedAt() so the
    // first listProc.onExited refresh after startup does not overwrite the
    // on-disk snapshot with a half-seeded map before the file has been
    // read. Without this gate a fast cliphist list (parent of onExited)
    // that beats the FileView read would erase persisted timestamps.
    property bool copiedAtLoaded: false

    // LRU-touch + bounded insert for fileMetaCache. Mirrors
    // addToImageCache exactly — replacing the object reference (Object.
    // assign({}, ...)) is what causes QML bindings on fileMetaCache to
    // re-evaluate, since in-place mutation would not fire the binding.
    function addFileMeta(key, meta) {
        const existing = root.fileMetaOrder.indexOf(key);
        if (existing !== -1) {
            root.fileMetaOrder = root.fileMetaOrder.filter((_, i) => i !== existing);
        }
        while (root.fileMetaOrder.length >= root.maxImageCacheSize) {
            const oldest = root.fileMetaOrder[0];
            root.fileMetaOrder = root.fileMetaOrder.slice(1);
            const next = Object.assign({}, root.fileMetaCache);
            delete next[oldest];
            root.fileMetaCache = next;
        }
        root.fileMetaCache = Object.assign({}, root.fileMetaCache, {
            [key]: meta
        });
        root.fileMetaOrder = [...root.fileMetaOrder, key];
        root.fileMetaRevision++;
    }

    // Reinsert a key at the tail (most-recently-used end), evicting the
    // oldest entry if the cache is at capacity. Safe for both cache-hit
    // refresh (moves the key to the tail) and cache-miss insertion.
    function addToImageCache(key, value) {
        // Remove the key from the order if it was already present so the
        // reinsertion below places it at the tail (LRU touch semantics).
        const existing = root.imageCacheOrder.indexOf(key);
        if (existing !== -1) {
            root.imageCacheOrder = root.imageCacheOrder.filter((_, i) => i !== existing);
        }

        // Evict oldest while at capacity. Loop handles both the normal
        // "one over" case and any future change that lowers maxImageCacheSize.
        while (root.imageCacheOrder.length >= root.maxImageCacheSize) {
            const oldest = root.imageCacheOrder[0];
            root.imageCacheOrder = root.imageCacheOrder.slice(1);
            const newCache = Object.assign({}, root.imageCache);
            delete newCache[oldest];
            root.imageCache = newCache;
        }

        // Insert. Object.assign({}, ...) replaces the object reference so
        // QML bindings fire — mutating root.imageCache in place would not.
        root.imageCache = Object.assign({}, root.imageCache, {
            [key]: value
        });
        root.imageCacheOrder = [...root.imageCacheOrder, key];
        root.imageCacheRevision++;
    }

    // --- Persistent storage for copiedAt -------------------------------------
    //
    // Mirror of root.copiedAt on disk. The plugin is the sole writer, so
    // watchChanges is false — we do not want spurious re-loads triggered by
    // our own writes. The parent directory is created by pinnedDirProc in
    // onPluginApiChanged, so the path is guaranteed to exist before
    // copiedAtWriteProc fires.
    //
    // `copiedAtLoaded` is the gate that suppresses the first write: until
    // onLoaded assigns the parsed map into root.copiedAt, listProc.onExited
    // must not call saveCopiedAt() — otherwise the first refresh after
    // startup can race the FileView read and erase persisted timestamps.
    FileView {
        id: copiedAtFile
        path: root.dataDir + "/copied-at.json"
        watchChanges: false
        printErrors: false

        onLoaded: {
            try {
                const txt = String(copiedAtFile.text());
                if (txt.length > 0) {
                    const parsed = JSON.parse(txt);
                    // Guard against a file that decodes to a non-object
                    // (e.g. an array or a bare null from a corrupted
                    // earlier write). Only plain objects are valid
                    // copiedAt snapshots; anything else is treated as
                    // "no seed" and the map stays empty.
                    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
                        root.copiedAt = parsed;
                    }
                }
            } catch (e) {
                // Malformed JSON on disk — keep root.copiedAt at its default
                // ({}) so listProc.onExited can repopulate from cliphist.
                Logger.w("Clipboard Plugin", "copied-at.json parse failed:", e);
            }
            // Mark loaded even on failure so saveCopiedAt() can run and
            // repair the file on the next list refresh.
            root.copiedAtLoaded = true;
        }

        onLoadFailed: {
            // File does not exist (first run) or is unreadable. Treat as
            // empty seed — the in-memory default ({}) already holds.
            // Mark loaded so the next refresh can write a fresh snapshot.
            root.copiedAtLoaded = true;
        }
    }

    // Writes root.copiedAt to copied-at.json. Command shape mirrors
    // decodeProc's bash -c stdin-redirect pattern — the JSON body is
    // passed via $1 (not interpolated) so nothing in the payload can
    // execute. The quoted target path means a HOME with spaces still
    // resolves to the right file. No stdout / stderr handlers: the
    // write is fire-and-forget and any filesystem error is recoverable
    // on the next refresh.
    Process {
        id: copiedAtWriteProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // Persist the current root.copiedAt snapshot to disk. Called after
    // every mutation inside listProc.onExited. Short-circuits when the
    // FileView load has not yet fired (copiedAtLoaded === false) to
    // avoid the race described on copiedAtLoaded above. If the write
    // Process is already running, we skip this tick — the next refresh
    // will write a fresh snapshot, and the map mutates only on
    // listProc.onExited so no intermediate state can be lost.
    function saveCopiedAt() {
        if (!root.copiedAtLoaded)
            return;
        if (copiedAtWriteProc.running)
            return;
        const payload = JSON.stringify(root.copiedAt || {});
        const target = root.dataDir + "/copied-at.json";
        // `printf %s` (no trailing newline in the format string) emits the
        // JSON verbatim. Passing the payload and path as $1 / $2 keeps
        // them out of the shell's interpolation path — payload contains
        // arbitrary JSON and the path contains $HOME, both of which are
        // safe as argv elements but dangerous if embedded in the command
        // string. The same argv-as-positional policy is used by copy()
        // and metaProc — see those for the rationale.
        copiedAtWriteProc.command = ["bash", "-c",
            'printf %s "$1" > "$2"', "--", payload, target];
        copiedAtWriteProc.running = true;
    }

    // --- Processes -----------------------------------------------------------

    // Lists the current clipboard history. Piped through `head` so the shell's
    // maxHistorySize setting caps the result — see manifest.json defaultSettings.
    Process {
        id: listProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.items = [];
                root.itemsRevision++;
                return;
            }
            try {
                const raw = String(listProc.stdout.text);
                const lines = raw.length > 0 ? raw.split("\n") : [];
                const parsed = [];
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab === -1)
                        continue;
                    const preview = line.substring(tab + 1);
                    // Classification:
                    //   - "image" — cliphist's binary marker with pixel
                    //     dimensions at the end (e.g. "png 664x532").
                    //   - "file"  — a single-line preview beginning with
                    //     "file://". File managers copy URIs as plain
                    //     text; cliphist's preview is only the first line
                    //     so a multi-URI entry still passes this test.
                    //   - "text"  — everything else, including generic
                    //     "[[ binary data ... ]]" blobs with no pixel
                    //     dimensions. Those have no filename / size we
                    //     can usefully surface, so they fall through to
                    //     the text path with the raw marker as preview —
                    //     same behavior as before file type existed.
                    // See docs/specs/file-items.md for the rationale.
                    const imageRx = /^\[\[\s*binary data\s+[\d.]+\s+\w+\s+\w+\s+\d+x\d+\s*\]\]$/i;
                    const fileRx = /^(file:\/\/\S+|\/\S+)$/;
                    const type = imageRx.test(preview) ? "image"
                               : fileRx.test(preview) ? "file" : "text";
                    parsed.push({
                        id: line.substring(0, tab),
                        preview: preview,
                        type: type
                    });
                }
                root.items = parsed;
                // --- Relative-time timestamps ----------------------------
                //
                // Stamp every newly-observed id and prune ids that cliphist
                // no longer reports. The two operations share a single
                // rebuild so we replace root.copiedAt by reference exactly
                // once per refresh (QML bindings on the map fire off the
                // reference change). See docs/specs/relative-time-display.md.
                const now = new Date().toISOString();
                const nextCopiedAt = {};
                const prior = root.copiedAt || {};
                for (let j = 0; j < parsed.length; j++) {
                    const id = parsed[j].id;
                    // Preserve existing timestamp so "3m ago" keeps counting
                    // up across refreshes and is not reset by a re-copy.
                    nextCopiedAt[id] = prior[id] || now;
                }
                // Ids no longer in `parsed` are dropped (implicit: we only
                // copied keys that exist in parsed), so copiedAt tracks the
                // cliphist set exactly and cannot grow past maxHistorySize.
                root.copiedAt = nextCopiedAt;
                // Persist the updated map so timestamps survive a shell
                // restart. Gated on copiedAtLoaded inside saveCopiedAt()
                // so the pre-load refresh does not overwrite the
                // on-disk snapshot before we have read it.
                root.saveCopiedAt();
            } catch (e) {
                root.items = [];
            }
            root.itemsRevision++;
        }
    }

    // Decodes an entry and pipes it into wl-copy. Does not mutate items.
    Process {
        id: copyProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // Sends the paste shortcut to the window focused after the panel closes.
    Process {
        id: pasteProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0) {
                Logger.w("Clipboard Plugin", "automatic paste failed:",
                    String(pasteProc.stderr.text).trim() || "exit " + exitCode);
            }
        }
    }

    // Deletes a specific entry, then refreshes the list on success.
    Process {
        id: removeProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                root.refresh();
            }
        }
    }

    // Wipes the entire history, then refreshes on success (end state: items=[]).
    // Does NOT touch pinnedItems or pinned.json — pinned entries live outside
    // cliphist and are the whole point of the "survive wipe" contract in
    // docs/specs/pinned-items.md.
    Process {
        id: wipeProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                root.refresh();
            }
        }
    }

    // Ensures the pinned-file parent directory exists before pinnedFile
    // tries to write to it. Run once during onPluginApiChanged, before any
    // user action can trigger a save. `mkdir -p` is idempotent so a fresh
    // install (no directory yet) and the normal case (directory already
    // exists because settings.json lives there) both succeed with exit
    // code 0.
    Process {
        id: pinnedDirProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // Persistent store for pinned clipboard items. JSON shape is
    //   { "items": [ { preview, type }, ... ] }
    // matching the canonical Clipper example in
    // docs/specs/plugin-entry-point-contracts.md. watchChanges: true means
    // an external edit (or a save from this same plugin) re-fires onLoaded
    // so pinnedItems stays consistent with the on-disk file.
    //
    // atomicWrites: true is the Noctalia default for FileView. Keeping it
    // explicit here documents the policy — a partially-written pinned.json
    // on crash would be worse than losing the last pin, so atomic swap is
    // the right tradeoff.
    FileView {
        id: pinnedFile
        path: root.pinnedPath
        watchChanges: true
        atomicWrites: true
        // printErrors default (true) is fine — a missing file on first
        // launch will log once and onLoaded will not fire; we handle that
        // via the onLoadFailed path below which seeds an empty array.

        onLoaded: {
            try {
                const raw = pinnedFile.text();
                if (!raw || raw.length === 0) {
                    root.pinnedItems = [];
                } else {
                    const data = JSON.parse(raw);
                    // Accept both `{ items: [...] }` (documented shape) and
                    // a bare `[...]` (tolerant migration path) so a user
                    // who hand-edits the file with a plain array doesn't
                    // lose their pins on next load.
                    if (Array.isArray(data)) {
                        root.pinnedItems = data;
                    } else if (data && Array.isArray(data.items)) {
                        root.pinnedItems = data.items;
                    } else {
                        root.pinnedItems = [];
                    }
                }
            } catch (e) {
                // Malformed JSON — keep whatever we had rather than wiping.
                // A single bad read shouldn't destroy the user's pins.
                Logger.w("Clipboard Plugin", "pinned.json parse failed:", e);
            }
            root.pinnedRevision++;
        }

        onLoadFailed: error => {
            // FileNotFound on first launch is expected — seed an empty
            // list so consumers can bind. Other errors (permission,
            // NotAFile) are logged for diagnosis; keep pinnedItems
            // empty to avoid operating on stale state.
            //
            // FileViewError enum values (from Quickshell.Io): 0=Success,
            // 1=Unknown, 2=FileNotFound, 3=PermissionDenied, 4=NotAFile.
            // Comparing against the integer avoids importing the singleton
            // and matches the idiom used in Noctalia's own Settings.qml.
            if (error !== 2) {
                Logger.w("Clipboard Plugin", "pinned.json load failed:", error);
            }
            root.pinnedItems = [];
            root.pinnedRevision++;
        }
    }

    // Stats a single file path to populate fileMetaCache. Dedicated Process
    // for the same reason decodeProc is dedicated: destruction-time
    // cancellation must be independent of the list / copy / remove / wipe
    // paths so a stat in flight does not outlive the plugin.
    //
    // Command shape is `stat -c %s -- <path>`: the -- separator prevents
    // filenames that start with a dash from being parsed as stat flags,
    // and we pass the path as its own argv element (not inside a
    // `bash -c` string) so shell metacharacters in the filename cannot
    // execute. This is the same policy applied to remove() below.
    Process {
        id: metaProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        // Set alongside `metaProc.command` in _processNextMeta so the
        // onExited handler can cache metadata without reparsing the
        // command vector. Kept as properties on metaProc (not on root)
        // to keep in-flight state local to the Process it belongs to.
        property string pendingPath: ""
        property string pendingFilename: ""
        property string pendingParent: ""

        onExited: exitCode => {
            const id = root.metaFetchingId;
            root.metaFetchingId = "";

            // Only cache when there is a bound id. A stray exit with no
            // bound id would be a destruction-time race; drop it.
            if (id) {
                if (exitCode === 0) {
                    const raw = String(metaProc.stdout.text).trim();
                    const bytes = parseInt(raw, 10);
                    const safeBytes = isNaN(bytes) ? -1 : bytes;
                    root.addFileMeta(id, {
                        filename: metaProc.pendingFilename,
                        parentDir: metaProc.pendingParent,
                        sizeBytes: safeBytes,
                        sizeHuman: safeBytes >= 0 ? root.humanSize(safeBytes) : ""
                    });
                } else {
                    // File missing / unreadable — still cache so the
                    // delegate renders basename + parent without a size,
                    // and so we don't retry stat on every re-scroll.
                    root.addFileMeta(id, {
                        filename: metaProc.pendingFilename,
                        parentDir: metaProc.pendingParent,
                        sizeBytes: -1,
                        sizeHuman: ""
                    });
                }
            }
            // Chain the next queued metadata fetch now that the Process
            // is free — mirrors decodeProc.onExited → _processNextDecode().
            root._processNextMeta();
        }
    }

    // Decodes a single clipboard entry to /tmp/clipboard-<id>.png and,
    // on success, registers the file:// URL with the LRU cache. Dedicated
    // Process so cancellation in Component.onDestruction is independent of
    // the copy path — a decode mid-destruction would otherwise outlive the
    // plugin and leak a cliphist child.
    Process {
        id: decodeProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            const id = root.decodingId;
            root.decodingId = "";
            if (exitCode === 0 && id) {
                // cliphist decode redirected to a stable path — same id always
                // targets the same file. Shell reload scenarios re-decode into
                // the same path, which is safe (overwrite, not append).
                root.addToImageCache(id, "file:///tmp/clipboard-" + id + ".png");
            }
            // Process the next queued id now that the process is free.
            root._processNextDecode();
        }
    }

    // --- Timers --------------------------------------------------------------

    // Single ticker that drives relative-time refreshes in every delegate.
    // One Timer for the whole plugin, not one per row: ListView uses
    // reuseItems: true and 100+ recycled delegates would otherwise mean
    // 100+ Timer instances on every scroll burst, breaking the memory
    // contract from docs/specs/plugin-qml-idioms.md (memory management).
    //
    // Incrementing timeRevision forces every binding that reads it to
    // re-evaluate formatRelativeTime(). Interval matches the coarsest
    // bucket in the format contract ("Nm ago" — whole minutes), so a one-
    // minute tick is exactly what's needed for labels to stay fresh.
    //
    // running: true from construction so labels update without requiring
    // the panel to open — the handful of CPU cycles per minute is
    // negligible compared to the UX cost of a stale "just now" on first
    // panel open. repeat: true because the plugin lives as long as the
    // shell does; onDestruction does not stop it explicitly since the
    // Timer dies with its parent Item (see plugin-qml-idioms.md).
    Timer {
        id: timeRevisionTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.timeRevision++
    }

    // --- Public API (called via pluginApi.mainInstance.*) --------------------

    // Reload the clipboard history. Single-flight: a call while listProc is
    // already running is a no-op so rapid panel-open toggles can't stampede.
    function refresh() {
        if (listProc.running)
            return;
        const cap = pluginApi?.pluginSettings?.maxHistorySize ?? 100;
        listProc.command = ["bash", "-c", "cliphist list | head -n " + cap];
        listProc.running = true;
    }

    // Copy a history entry (by cliphist id) to the Wayland clipboard.
    function copy(id) {
        if (!id)
            return;
        // File entries need x-special/gnome-copied-files so paste targets
        // (Nautilus and most GTK file managers) recognise them as file
        // references rather than plain text. See the branch below for
        // the full rationale. Look up the item type; if it's a file,
        // build the file:// URI and pass it via $1 (not interpolated)
        // so shell metacharacters in the path cannot execute.
        const sid = String(id);
        if (!/^[0-9]+$/.test(sid))
            return;
        let itemType = "text";
        let itemPreview = "";
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].id === sid) {
                itemType = root.items[i].type;
                itemPreview = root.items[i].preview;
                break;
            }
        }
        if (itemType === "file") {
            const uri = itemPreview.indexOf("file://") === 0
                        ? itemPreview
                        : "file://" + itemPreview;
            // GNOME Files (Nautilus) and most GTK file managers will only
            // recognise a clipboard paste as a file operation when the
            // entry carries MIME type x-special/gnome-copied-files whose
            // body is an action line ("copy" or "cut") followed by one
            // URI per line. Offering text/uri-list alone makes GTK
            // report "There is nothing on the clipboard to paste."
            //
            // wl-copy supports only one --type at a time (verified
            // against wl-clipboard 2.3.0 --help). x-special/gnome-copied-
            // files is the broadly-compatible choice for the file
            // managers we care about here; paste into a text target
            // still works because most text widgets also accept
            // x-special as plain text.
            //
            // The URI is passed via $1 (not interpolated) so shell
            // metacharacters in the path cannot execute. printf's
            // format string contains only constants so "copy\n" and
            // the trailing newline are emitted verbatim.
            copyProc.command = ["bash", "-c",
                'printf "copy\n%s\n" "$1" | wl-copy --type x-special/gnome-copied-files', "--", uri];
        } else {
            copyProc.command = ["bash", "-c", `cliphist decode ${sid} | wl-copy`];
        }
        copyProc.running = true;
    }

    // Delete a single entry, then refresh on success.
    //
    // `cliphist delete` does not accept an id argument — it reads a full
    // list line (`<id>\t<content>`) from stdin and deletes entries whose
    // leading id matches. We therefore shape the command as
    // `cliphist list | grep -Pm1 "^<id>\t" | cliphist delete`, passing the
    // numeric id as `$1` (not interpolated into the shell string) so shell
    // metacharacters in the id — implausible, but the same policy as
    // copy() / metaProc — cannot execute. grep -P for the literal tab and
    // -m1 so only the first matching line is forwarded.
    function remove(id) {
        if (!id)
            return;
        const sid = String(id);
        removeProc.command = ["bash", "-c",
            `cliphist list | grep -Pm1 "^${sid}\\t" | cliphist delete`];
        removeProc.running = true;
    }

    // Wipe the entire history, then refresh on success.
    //
    // Does NOT mutate pinnedItems or pinned.json — pinned entries are
    // explicitly preserved across cliphist wipes per the contract in
    // docs/specs/pinned-items.md. wipeProc.onExited calls refresh() which
    // re-parses `cliphist list` (now empty); pinned entries continue to
    // live in root.pinnedItems untouched.
    function wipe() {
        wipeProc.command = ["cliphist", "wipe"];
        wipeProc.running = true;
    }

    // --- IPC surface ---------------------------------------------------------
    //
    // Registers external commands callable via:
    //   qs -c noctalia-shell ipc call plugin:clipboard <handler>
    //
    // The target string's plugin suffix must match manifest.json `id`
    // exactly — a mismatch makes the IPC call a silent no-op.
    //
    // Focused-screen resolution uses pluginApi.withCurrentScreen(callback),
    // the canonical helper the shell exposes for IPC handlers that need a
    // ShellScreen (see docs/specs/ipc-handlers.md, cross-referenced with the
    // clipper and workspace-overview reference plugins). Hard-coding
    // Quickshell.screens[0] would open the panel on the wrong monitor for
    // multi-head setups.
    //
    // pluginApi is null-guarded per the project-wide rule — IPC handlers
    // are invoked by the shell, so in principle pluginApi is already set,
    // but guarding here matches every other pluginApi access site and costs
    // nothing. See docs/specs/plugin-qml-idioms.md (null-guarding).
    IpcHandler {
        target: "plugin:clipboard"

        // Primary keybind entry point. Open the panel when closed, close
        // it when open, on the currently focused screen. See
        // README.md keybinds section for Niri / Hyprland examples.
        //
        // Optional-chained at every access — the outer guard is enough to
        // short-circuit if pluginApi is null during an edge-case early
        // IPC call, but matching the project-wide "?. on every pluginApi
        // read" rule keeps the review directive uniform.
        function toggle() {
            root.pluginApi?.withCurrentScreen(screen => {
                root.pluginApi?.togglePanel(screen);
            });
        }

        // Clear the entire clipboard history without opening the panel.
        // Exposes the existing root.wipe() so power users can bind
        // "clear clipboard" to a key. Does not need a screen.
        function wipe() {
            root.wipe();
        }
    }

    // --- Pinned-item API ----------------------------------------------------

    // True iff a pinned entry with identical preview+type already exists.
    // Used to make pin() idempotent on duplicates — see
    // docs/specs/pinned-items.md §Acceptance Criteria #7.
    function isPinned(preview, type) {
        const list = root.pinnedItems || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].preview === preview && list[i].type === type)
                return true;
        }
        return false;
    }

    // Persist pinnedItems to disk. Called after every mutation so the user
    // never loses a pin across shell restarts. setText() triggers an async
    // write; pinnedFile.atomicWrites ensures partial writes on crash don't
    // leave the file corrupted. The wrapper shape `{ items: [...] }` is
    // stable across versions (see docs/specs/pinned-items.md).
    function _savePinned() {
        const body = JSON.stringify({ items: root.pinnedItems }, null, 2);
        pinnedFile.setText(body);
    }

    // Pin a clipboard entry. Accepts either `{preview, type}` or the full
    // cliphist entry shape `{id, preview, type}` — the `id` is ignored
    // since pinned items live outside cliphist and must survive wipes that
    // invalidate every cliphist id.
    //
    // Idempotent on duplicates (same preview+type): a second pin is a
    // silent no-op so a keybind-repeat or double-tap doesn't create two
    // rows for the same content.
    function pin(entry) {
        if (!entry || !entry.preview || !entry.type)
            return;
        if (root.isPinned(entry.preview, entry.type))
            return;
        const record = { preview: entry.preview, type: entry.type };
        // Replace by reference (spread + push) so the array binding fires —
        // mutating root.pinnedItems.push() in place would not trigger
        // consumer re-evaluation, same reason items[] is rebuilt in
        // listProc.onExited. See docs/specs/plugin-qml-idioms.md.
        root.pinnedItems = [...root.pinnedItems, record];
        root.pinnedRevision++;
        root._savePinned();
    }

    // Unpin the entry at positional index in pinnedItems. Out-of-range
    // indices are a silent no-op so a stale UI reference can't corrupt the
    // array.
    function unpin(index) {
        const list = root.pinnedItems || [];
        if (index < 0 || index >= list.length)
            return;
        root.pinnedItems = list.filter((_, i) => i !== index);
        root.pinnedRevision++;
        root._savePinned();
    }

    // Convenience: unpin a pinned entry by its preview+type pair. Used by
    // the `P` key shortcut in Panel.qml, which sees the merged list entry
    // with `pinned: true` but doesn't know its positional index in the
    // pinnedItems array. Silently succeeds even if no match is found.
    function unpinByEntry(preview, type) {
        const list = root.pinnedItems || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].preview === preview && list[i].type === type) {
                root.unpin(i);
                return;
            }
        }
    }

    // Copy a pinned entry (by positional index in pinnedItems) to the
    // Wayland clipboard. Pinned entries have no cliphist id so the normal
    // `copy(id)` path — which does a cliphist decode — cannot be used.
    // Instead, the preview text stored at pin time is piped directly into
    // wl-copy. For `type === "file"`, the same x-special/gnome-copied-files
    // treatment used by copy() is applied so pasting into Nautilus works.
    //
    // Pinned image entries: we only have the cliphist binary marker
    // (e.g. "[[ binary data 1.2 KiB png 1920x1080 ]]"), not the bitmap.
    // v1 copies that marker as text — documented in
    // docs/specs/pinned-items.md.
    function copyPinned(index) {
        const list = root.pinnedItems || [];
        if (index < 0 || index >= list.length)
            return;
        const entry = list[index];
        const preview = String(entry.preview || "");
        const type = String(entry.type || "text");
        if (type === "file") {
            // File-URI fast path: same MIME treatment as copy(). `$1` is
            // not interpolated into the shell string so metacharacters in
            // the path cannot execute.
            const uri = preview.indexOf("file://") === 0 ? preview : "file://" + preview;
            copyProc.command = ["bash", "-c",
                'printf "copy\n%s\n" "$1" | wl-copy --type x-special/gnome-copied-files', "--", uri];
        } else {
            // Text / image-marker: pipe the preview into wl-copy via
            // stdin. `$1` passes the payload as an argv element (not
            // interpolated into the shell string) so newlines, quotes,
            // and shell metacharacters in the preview stay inert.
            copyProc.command = ["bash", "-c", 'printf "%s" "$1" | wl-copy', "--", preview];
        }
        copyProc.running = true;
    }


    // Ensure the cliphist entry `id` has a decoded preview file on disk and
    // its file:// URL registered in `imageCache`. Called by ClipboardItem.qml
    // when an image-type delegate is instantiated (or recycled onto a new
    // id). Cheap when already cached; spawns cliphist decode on miss.
    //
    // Guarded by pluginSettings.showImagePreviews so flipping the setting
    // off short-circuits the whole image path — image entries then render
    // as text with their raw "[[ binary data ... ]]" preview (no regression
    // from the pre-image-previews behavior).
    // Drain one item from decodeQueue into decodeProc. No-op if the queue is
    // empty or the process is already running. Called by getImage() on a
    // cache miss and by decodeProc.onExited to chain the next decode.
    function _processNextDecode() {
        if (decodeProc.running || root.decodeQueue.length === 0)
            return;
        const sid = root.decodeQueue[0];
        root.decodeQueue = root.decodeQueue.slice(1);
        root.decodingId = sid;
        decodeProc.command = ["bash", "-c", `cliphist decode ${sid} > /tmp/clipboard-${sid}.png`];
        decodeProc.running = true;
    }

    // --- File metadata helpers ----------------------------------------------
    //
    // All three are pure functions: they do not touch root state. They live
    // on root so ClipboardItem.qml can call them through
    // pluginApi.mainInstance for the basename placeholder while metadata is
    // still resolving (see docs/specs/file-items.md — "Fallback state").

    // Decode a file:// URI into a filesystem path. cliphist stores entries
    // exactly as copied, so URIs arrive percent-encoded (a copy of
    // "My Notes.md" becomes "My%20Notes.md"). decodeURIComponent handles
    // every percent-escape including multi-byte UTF-8. Returns "" for
    // inputs that are not file:// URIs or that fail to decode.
    function fileUriToPath(uri) {
        if (!uri || typeof uri !== "string")
            return "";
        // Plain absolute path (e.g. from GTK file managers that write
        // the path directly rather than a file:// URI).
        if (uri.indexOf("/") === 0)
            return uri;
        const prefix = "file://";
        if (uri.indexOf(prefix) !== 0)
            return "";
        // Strip an optional host component: "file://host/abs/path" is
        // valid RFC 8089 (only localhost is meaningful on Linux).
        let rest = uri.substring(prefix.length);
        const slash = rest.indexOf("/");
        if (slash > 0) {
            // host = rest.substring(0, slash); -- dropped, irrelevant here.
            rest = rest.substring(slash);
        }
        try {
            return decodeURIComponent(rest);
        } catch (e) {
            // Malformed percent-escape. Fall back to the raw string so
            // the row still renders something.
            return rest;
        }
    }

    // Split an absolute path into { filename, parentDir }. parentDir has
    // $HOME collapsed to "~" per docs/specs/file-items.md so long home
    // paths display compactly. Empty filename / parentDir for malformed
    // paths — the caller (delegate) handles the empty case gracefully.
    function splitPath(path) {
        if (!path)
            return { filename: "", parentDir: "" };
        const last = path.lastIndexOf("/");
        if (last === -1)
            return { filename: path, parentDir: "" };
        const filename = path.substring(last + 1);
        let parent = path.substring(0, last);
        if (parent === "")
            parent = "/";
        const home = Quickshell.env("HOME") || "";
        if (home && parent === home) {
            parent = "~";
        } else if (home && parent.indexOf(home + "/") === 0) {
            parent = "~" + parent.substring(home.length);
        }
        return { filename: filename, parentDir: parent };
    }

    // Format an ISO 8601 timestamp as a short "how long ago" label for the
    // clipboard delegate. Pure function of (iso, Date.now()) — does not
    // touch root state. Kept on root so ClipboardItem.qml can call it
    // through pluginApi.mainInstance.
    //
    // Buckets (see docs/specs/relative-time-display.md):
    //   - < 60 s             "just now"
    //   - < 1 h              "<N>m ago"   (floor minutes)
    //   - same calendar day  "<N>h ago"   (floor hours; 24 h cap)
    //   - previous day       "yesterday"
    //   - same year          "MMM D"
    //   - earlier years      "MMM D, YYYY"
    //
    // Returns "" for empty / unparseable input so the delegate can hide
    // the label without a special-case branch. Future timestamps (clock
    // skew) collapse to "just now" rather than rendering a negative age.
    function formatRelativeTime(iso) {
        if (!iso || typeof iso !== "string")
            return "";
        const t = Date.parse(iso);
        if (isNaN(t))
            return "";
        const now = Date.now();
        const diffSec = Math.floor((now - t) / 1000);
        // Clamp future / near-future to "just now" so a drifting clock
        // can't produce "-3m ago".
        if (diffSec < 60)
            return root.pluginApi?.tr("time.just-now");
        if (diffSec < 3600) {
            const mins = Math.floor(diffSec / 60);
            return root.pluginApi?.tr("time.minutes-ago", { minutes: mins });
        }
        // Within the same calendar day (local time) but more than an
        // hour — show the hour bucket. Crossing midnight with a small
        // diff (e.g. 1 h across a day boundary) falls through to the
        // yesterday / same-year branches below.
        const then = new Date(t);
        const nowDate = new Date(now);
        const sameDay = then.getFullYear() === nowDate.getFullYear()
                     && then.getMonth() === nowDate.getMonth()
                     && then.getDate() === nowDate.getDate();
        if (sameDay) {
            const hours = Math.floor(diffSec / 3600);
            return root.pluginApi?.tr("time.hours-ago", { hours: hours });
        }
        // Same-or-previous calendar day check via a one-day-earlier Date.
        const yesterday = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate() - 1);
        const isYesterday = then.getFullYear() === yesterday.getFullYear()
                         && then.getMonth() === yesterday.getMonth()
                         && then.getDate() === yesterday.getDate();
        if (isYesterday)
            return root.pluginApi?.tr("time.yesterday");
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const monStr = months[then.getMonth()];
        const dayStr = String(then.getDate());
        if (then.getFullYear() === nowDate.getFullYear())
            return monStr + " " + dayStr;
        return monStr + " " + dayStr + ", " + then.getFullYear();
    }

    // Render a byte count as a short human-readable string. Binary units
    // (1024-step) match the Noctalia convention for disk-reported sizes.
    // 0 → "0 B"; negative returns "" (the "no size" sentinel — keep in
    // sync with the delegate's visibility check).
    function humanSize(bytes) {
        if (bytes < 0)
            return "";
        if (bytes < 1024)
            return bytes + " B";
        const units = ["KB", "MB", "GB", "TB"];
        let value = bytes / 1024;
        let i = 0;
        while (value >= 1024 && i < units.length - 1) {
            value /= 1024;
            i++;
        }
        // 1 decimal place for < 10 and whole numbers beyond that so the
        // width is stable across rows (e.g. "4.1 MB", "128 MB").
        const formatted = value < 10 ? value.toFixed(1) : Math.round(value).toString();
        return formatted + " " + units[i];
    }

    // Drain one id from metaQueue into metaProc. No-op when the process
    // is already running or the queue is empty — same shape as
    // _processNextDecode.
    function _processNextMeta() {
        if (metaProc.running || root.metaQueue.length === 0)
            return;
        const sid = root.metaQueue[0];
        root.metaQueue = root.metaQueue.slice(1);

        // Resolve the entry preview → filesystem path. This runs against
        // the current items array so an entry evicted between enqueue
        // and drain is silently skipped.
        let entry = null;
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].id === sid) {
                entry = root.items[i];
                break;
            }
        }
        if (!entry) {
            // Entry gone — chain to the next without firing a Process.
            root._processNextMeta();
            return;
        }
        // Use the first file:// URI on the preview line. Multi-URI
        // entries expose only the first in the preview anyway.
        const path = root.fileUriToPath(entry.preview);
        if (!path) {
            // Preview doesn't decode to a path — cache an empty meta so
            // we don't re-enqueue and skip ahead.
            root.addFileMeta(sid, {
                filename: "",
                parentDir: "",
                sizeBytes: -1,
                sizeHuman: ""
            });
            root._processNextMeta();
            return;
        }
        const parts = root.splitPath(path);
        metaProc.pendingPath = path;
        metaProc.pendingFilename = parts.filename;
        metaProc.pendingParent = parts.parentDir;
        root.metaFetchingId = sid;
        // argv form (no bash -c) so filenames containing shell
        // metacharacters cannot execute. `--` ends stat's flag parsing
        // so files starting with "-" work correctly.
        metaProc.command = ["stat", "-c", "%s", "--", path];
        metaProc.running = true;
    }

    // Ensure the cliphist entry `id` has a file metadata record in
    // fileMetaCache. Called by ClipboardItem.qml when a file-type
    // delegate is instantiated or rebound. Same contract as getImage():
    // cheap on cache hit, idempotent on in-flight ids, numeric-id guard
    // against shell injection.
    function getFileMeta(id) {
        if (!id)
            return;
        const sid = String(id);
        if (!/^[0-9]+$/.test(sid))
            return;
        if (root.fileMetaCache[sid] !== undefined)
            return;
        if (root.metaFetchingId === sid || root.metaQueue.indexOf(sid) !== -1)
            return;
        root.metaQueue = [...root.metaQueue, sid];
        _processNextMeta();
    }

    function getImage(id) {
        if (!id)
            return;
        if (!(pluginApi?.pluginSettings?.showImagePreviews ?? true))
            return;
        // Reject non-numeric ids defensively. cliphist ids are always
        // integers, so anything else is malformed or — worst case — shell
        // metacharacter injection through the substring extracted from
        // cliphist list output. Interpolating an untrusted string into the
        // bash -c command below would be an arbitrary-exec bug.
        const sid = String(id);
        if (!/^[0-9]+$/.test(sid))
            return;
        // Cache hit — nothing to do. The Image binding will already be
        // reading the existing URL.
        if (root.imageCache[sid] !== undefined)
            return;
        // Already queued or in flight — don't enqueue twice.
        if (root.decodingId === sid || root.decodeQueue.indexOf(sid) !== -1)
            return;
        root.decodeQueue = [...root.decodeQueue, sid];
        _processNextDecode();
    }

    // --- Lifecycle -----------------------------------------------------------

    // Seed or clear the list once the shell has injected pluginApi so startup
    // behavior resolves to the user's actual settings.
    //
    // Also ensure the pinned-file parent directory exists. FileView.setText
    // does not create missing parent directories, so a fresh install with
    // no settings.json yet would otherwise fail silently on first pin.
    // `mkdir -p` is idempotent and costs nothing when the directory already
    // exists. Creates the cache dir on first run so both pinned.json and
    // copied-at.json have a parent to write into.
    onPluginApiChanged: {
        if (pluginApi) {
            const cfg = pluginApi?.pluginSettings || ({});
            const defaults = pluginApi?.manifest?.metadata?.defaultSettings || ({});
            if (cfg.clearHistoryOnStartup ?? defaults.clearHistoryOnStartup ?? false) {
                root.wipe();
            } else {
                root.refresh();
            }
            if (root.dataDir) {
                pinnedDirProc.command = ["mkdir", "-p", root.dataDir];
                pinnedDirProc.running = true;
            }
        }
    }

    // Stop any in-flight Process on destruction so a shell reload does not
    // orphan cliphist children. Required for the 500+ refresh memory test.
    Component.onDestruction: {
        if (listProc.running)
            listProc.running = false;
        if (copyProc.running)
            copyProc.running = false;
        if (pasteProc.running)
            pasteProc.running = false;
        if (removeProc.running)
            removeProc.running = false;
        if (wipeProc.running)
            wipeProc.running = false;
        // Stop any in-flight image decode so shell reload doesn't orphan a
        // cliphist child. Mirrors the policy applied to the other processes
        // above — see docs/specs/plugin-qml-idioms.md (memory management).
        if (decodeProc.running)
            decodeProc.running = false;
        // Same destruction-time policy for the file metadata Process.
        // A stat in flight during shell reload would otherwise outlive
        // the plugin and leak a child — see docs/specs/file-items.md.
        if (metaProc.running)
            metaProc.running = false;
        // mkdir -p is a one-shot at plugin start, but if the plugin is
        // reloaded quickly while the command is still in flight, stop
        // it so it doesn't outlive the shell — same policy as the other
        // Process children per docs/specs/plugin-qml-idioms.md.
        if (pinnedDirProc.running)
            pinnedDirProc.running = false;
        // Stop any in-flight copiedAt persistence write. A one-line
        // `printf > file` is typically instantaneous, but the same
        // destruction-time policy applies: a Process outliving the
        // plugin would orphan a shell child — see the memory-management
        // section of docs/specs/plugin-qml-idioms.md.
        if (copiedAtWriteProc.running)
            copiedAtWriteProc.running = false;
    }
}
