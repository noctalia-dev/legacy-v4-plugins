import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Floating panel surface for the clipboard plugin. The shell shows
// this anchored to the bar widget that triggered it (SmartPanel wrapper).
//
// Visual contract: matches the official NotificationHistoryPanel conventions
// (NBox-wrapped header with icon + title + action buttons, mSurfaceVariant
// card rows, pointSize-based typography). See the reference panel at
// $XDG_CONFIG_HOME/quickshell/noctalia-shell/Modules/Panels/NotificationHistory/
// NotificationHistoryPanel.qml — the style tokens here mirror its header row,
// empty-state layout, and list-item card treatment so the plugin feels native.
//
// Contracts followed:
//   - docs/specs/plugin-entry-point-contracts.md (SmartPanel geometry read-back
//     properties; onVisibleChanged refresh lifecycle; pluginApi.panelOpenScreen
//     as the canonical shell-provided screen reference).
//   - docs/specs/plugin-qml-idioms.md (null-guard pluginApi; revision-counter
//     pattern for reactive re-renders; Logger.w for diagnostic output).
Item {
    id: root

    // Accept keyboard focus so Keys.onPressed (defined further down) receives
    // `/` and Escape when the user hasn't explicitly focused another widget.
    // The same pattern is used by the shell's NotificationHistoryPanel,
    // SettingsContent, and SessionMenu — all Noctalia panels that handle
    // top-level key events.
    focus: true

    // --- Shell-injected properties ------------------------------------------
    property var pluginApi: null

    // --- SmartPanel required / read-back properties ------------------------
    // The shell reads these off the root to size and position the panel.

    // Geometry anchor used by the SmartPanel wrapper. Must be `readonly`
    // per the contract in plugin-entry-point-contracts.md, and typed as
    // `var` — not `Item` — so the shell's property introspection reads it
    // as the contract expects. An `Item`-typed property serialises
    // differently in the shell's placeholder-reading path and contributed
    // to issue #16 alongside the missing caller argument in BarWidget.
    readonly property var geometryPlaceholder: mainContainer
    readonly property bool allowAttach: true

    // Preferred panel width. Kept conservative for a text-only list; fullscreen
    // mode (added with image previews in a later issue) will override this.
    property real contentPreferredWidth: 440 * Style.uiScaleRatio

    // Dynamic height: grows with content up to a capped maximum. The shell
    // reads this property after each `itemsRevision` change so the panel
    // collapses when there are only a few entries and avoids excess whitespace.
    //
    // Overhead is an empirical estimate of header + tab bar + margins in scaled
    // pixels. Row height (44) and image cell aspect (0.65) match the delegate
    // sizes set in the ListView / GridView below.
    property var contentPreferredHeight: {
        const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
        const count = root.filteredItems.length;
        const scale = Style.uiScaleRatio;
        // Overhead = header card (title row + tab bar rows) + search input +
        // outer margins. The tab bar lives inside the header card now (see
        // `headerBox` below) but still contributes roughly the same pixel
        // budget it did as a sibling — so the 180 px estimate is unchanged.
        // Bumped from 130 → 180 historically to accommodate the search row
        // (~50 px at 1x scale: baseWidgetSize * 1.1 plus the column's marginM
        // gap). Max height raised proportionally so the panel can still show
        // a useful list on smaller screens now that the chrome is taller.
        const overhead = Math.round(180 * scale);
        const maxH = Math.round(560 * scale);
        if (count === 0)
            return Math.min(overhead + Math.round(120 * scale), maxH);
        let contentH;
        if (root.currentTypeFilter === 1 && root.showImagePreviews) {
            // Image grid: 2 columns, cell aspect ratio 0.65.
            const cellW = Math.floor((root.contentPreferredWidth - Math.round(Style.marginL * 2 + Style.marginS)) / 2);
            const rows = Math.ceil(count / 2);
            contentH = rows * Math.floor(cellW * 0.65);
        } else {
            contentH = count * Math.round(44 * scale);
        }
        return Math.min(overhead + contentH + Math.round(8 * scale), maxH);
    }

    // Panel background. Solid surface color — list item cards use
    // mSurfaceVariant so they stand out against this base.
    property color panelBackgroundColor: Color.mSurface

    // Cached settings for reactive use inside bindings.
    readonly property bool showImagePreviews: pluginApi?.pluginSettings?.showImagePreviews ?? true
    readonly property real densitySpacing: {
        const d = pluginApi?.pluginSettings?.density ?? "comfortable";
        if (d === "compact") return Style.marginXS;
        if (d === "spacious") return Style.marginM;
        return Style.marginS; // comfortable (default)
    }

    // --- Type filter ---------------------------------------------------------

    // 0 = Text, 1 = Images, 2 = Files
    property int currentTypeFilter: 0

    // --- Keyboard selection --------------------------------------------------
    //
    // Index of the currently-highlighted row in filteredItems. -1 means
    // "nothing selected" — activation keys (Return) fall back to "copy
    // index 0 if anything exists". See docs/specs/panel-keyboard-nav.md
    // for the full behavior contract.
    //
    // Reset to -1 whenever the list shape changes (tab switch, search
    // query change, Main.qml refresh) or the panel hides. The one
    // exception is post-delete clamping inside the Delete key handler,
    // which clamps to [0, length-1] instead of resetting so the user's
    // focus stays on the row that slid up into the deleted position.
    property int selectedIndex: -1
    property bool pasteAfterClose: false

    // Sentinel index to restore AFTER a delete-triggered refresh. -1
    // means "no pending clamp" (normal reset semantics apply). Any
    // value >= 0 means "the user just pressed Delete at this position;
    // when filteredItems next updates, clamp to this index rather than
    // resetting to -1". Cleared back to -1 by the onFilteredItemsChanged
    // handler below once the clamp has been applied.
    //
    // This indirection exists because remove() in Main.qml is async
    // (spawns a cliphist delete Process, onExited calls refresh());
    // filteredItems does not update in the same frame as the delete
    // key press, so we cannot clamp inline in deleteSelection().
    property int _pendingClampIndex: -1

    // Reset selection whenever the visible list changes underneath us.
    // filteredItems is recomputed by binding when itemsRevision bumps,
    // currentTypeFilter changes, or searchQuery changes — all three
    // paths shorten or reorder the list such that the prior index no
    // longer maps to the same entry.
    //
    // The delete path sets _pendingClampIndex first so that when the
    // async cliphist delete lands and the list updates, we clamp to
    // the old position (or one less, if the list shrank past it)
    // instead of resetting — keeping the user's focus on the row that
    // slid up.
    onFilteredItemsChanged: {
        if (root._pendingClampIndex >= 0) {
            const n = root.filteredItems.length;
            if (n === 0) {
                root.selectedIndex = -1;
            } else {
                root.selectedIndex = Math.min(root._pendingClampIndex, n - 1);
                _positionActiveView();
            }
            root._pendingClampIndex = -1;
            return;
        }
        root.selectedIndex = -1;
    }

    // --- Keyboard navigation helpers ----------------------------------------
    //
    // Extracted as functions so the root Keys.onPressed handler AND the
    // search input's Keys.on<Nav>Pressed re-dispatchers can call the
    // same logic — the search input captures Up/Down/Home/End/PageUp/
    // PageDown/Return/Delete before they reach the root, so we re-emit
    // them into these helpers from the field-level handler.
    //
    // Each helper is a no-op on an empty list (filteredItems.length === 0)
    // per the acceptance criteria "empty list safety" rule.

    // Scroll the currently-active view so selectedIndex is visible.
    // Called after every selection mutation. ListView.Contain / GridView.Contain
    // keeps the viewport stable when the selection is already on screen —
    // only scrolls when the selection would otherwise be clipped.
    function _positionActiveView() {
        if (root.selectedIndex < 0)
            return;
        if (root.currentTypeFilter === 1) {
            imageGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
        } else {
            historyList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    // Compute the page-step (rows per viewport) for the active view. Min 1
    // so even a tiny viewport still advances selection on PageUp/PageDown.
    // rowHeight for the history list matches the estimate used in
    // contentPreferredHeight (Math.round(44 * Style.uiScaleRatio)).
    function _pageStep() {
        if (root.currentTypeFilter === 1) {
            const rows = Math.max(1, Math.floor(imageGrid.height / imageGrid.cellHeight));
            return rows * 2; // two-column grid
        }
        const rowH = Math.max(1, Math.round(44 * Style.uiScaleRatio));
        return Math.max(1, Math.floor(historyList.height / rowH));
    }

    function navigateDown() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        if (root.selectedIndex < 0) {
            root.selectedIndex = 0;
        } else {
            root.selectedIndex = Math.min(root.selectedIndex + 1, n - 1);
        }
        _positionActiveView();
    }

    function navigateUp() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        // Don't re-enter the -1 state: per the spec, Up at index 0 stays
        // at 0 rather than deselecting (and does not bump focus back
        // into the search field).
        if (root.selectedIndex < 0)
            return;
        root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
        _positionActiveView();
    }

    function navigateHome() {
        if (root.filteredItems.length === 0)
            return;
        root.selectedIndex = 0;
        _positionActiveView();
    }

    function navigateEnd() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        root.selectedIndex = n - 1;
        _positionActiveView();
    }

    function navigatePageDown() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        const step = _pageStep();
        // First press from -1 lands on (step-1) rather than step, so the
        // initial viewport-worth of entries becomes reachable without
        // requiring Down-then-PageDown.
        const base = root.selectedIndex < 0 ? -1 : root.selectedIndex;
        root.selectedIndex = Math.min(base + step, n - 1);
        _positionActiveView();
    }

    function navigatePageUp() {
        if (root.filteredItems.length === 0)
            return;
        if (root.selectedIndex < 0)
            return;
        const step = _pageStep();
        root.selectedIndex = Math.max(root.selectedIndex - step, 0);
        _positionActiveView();
    }

    // Return / Enter: copy the selected row (or index 0 if nothing is
    // selected but the list is non-empty), then close the panel via
    // closePanelTimer. Uses the same deferred-close idiom as the
    // delegate click path so toast notifications survive the close.
    function activateSelection() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        const idx = root.selectedIndex >= 0 ? root.selectedIndex : 0;
        const entry = root.filteredItems[idx];
        if (!entry || !entry.id) {
            Logger.w("Clipboard Plugin", "activateSelection: no entry at index", idx);
            return;
        }
        if (entry.pinned && entry.pinnedIndex >= 0) {
            root.pluginApi?.mainInstance?.copyPinned(entry.pinnedIndex);
        } else {
            root.pluginApi?.mainInstance?.copy(entry.id);
        }
        const cfg = root.pluginApi?.pluginSettings || ({});
        const defaults = root.pluginApi?.manifest?.metadata?.defaultSettings || ({});
        root.pasteAfterClose = cfg.autoPasteOnSelect ?? defaults.autoPasteOnSelect ?? false;
        const typeSlug = entry.type === "file" ? "file"
                       : entry.type === "image" ? "image"
                       : "text";
        ToastService.showNotice(
            root.pluginApi?.tr("toast.item-copied-" + typeSlug + "-title"),
            root.pluginApi?.tr("toast.item-copied-" + typeSlug + "-body")
        );
        closePanelTimer.restart();
    }

    // Pin / unpin the selected row. Toggles based on the entry's
    // `pinned` flag in the merged filteredItems list:
    //   - pinned row  → unpin via pinnedIndex (O(1) into pinnedItems)
    //   - history row → pin the {preview, type} snapshot
    //
    // No panel close on either branch — the user likely wants to pin
    // several entries in a row (same UX policy as Delete). The merged
    // list recomputes reactively via pinnedRevision, so the row moves
    // to the pinned section and the badge appears on the next frame.
    //
    // See docs/specs/pinned-items.md §Acceptance Criteria #5.
    function togglePinSelection() {
        if (root.selectedIndex < 0)
            return;
        const entry = root.filteredItems[root.selectedIndex];
        if (!entry) {
            Logger.w("Clipboard Plugin", "togglePinSelection: no entry at index", root.selectedIndex);
            return;
        }
        const main = root.pluginApi?.mainInstance;
        if (!main)
            return;
        if (entry.pinned) {
            if (typeof entry.pinnedIndex === "number" && entry.pinnedIndex >= 0) {
                main.unpin(entry.pinnedIndex);
            } else {
                // Fallback — pinnedIndex should always be set on a
                // pinned merged entry, but guard against stale models.
                main.unpinByEntry(entry.preview, entry.type);
            }
            ToastService.showNotice(root.pluginApi?.tr("toast.item-unpinned"));
        } else {
            if (!entry.preview || !entry.type)
                return;
            main.pin({ preview: entry.preview, type: entry.type });
            ToastService.showNotice(root.pluginApi?.tr("toast.item-pinned"));
        }
    }

    // Delete: remove the selected row, then arrange for the selection
    // to land back on the same visual position once the async remove
    // completes and the list refreshes.
    //
    // Why the _pendingClampIndex handshake? remove() in Main.qml spawns
    // a cliphist delete Process; the items array doesn't update until
    // the Process exits and refresh() re-parses cliphist list. So
    // filteredItems.length still reports the old length at the point
    // we return from remove(). We record the intended post-delete
    // index in _pendingClampIndex and let the onFilteredItemsChanged
    // handler do the actual clamp when the refresh lands.
    //
    // If the user presses Delete rapidly on successive rows, each
    // press overwrites _pendingClampIndex with the current
    // selectedIndex — which is what we want: focus tracks the
    // most-recent prune target, not the first one in a burst.
    function deleteSelection() {
        if (root.selectedIndex < 0)
            return;
        const entry = root.filteredItems[root.selectedIndex];
        if (!entry || !entry.id) {
            Logger.w("Clipboard Plugin", "deleteSelection: no entry at index", root.selectedIndex);
            return;
        }
        // Pinned entries are not in cliphist — Delete on a pinned row
        // unpins it (same destructive-intent mapping, but applied to
        // the correct backing store). Without this branch, remove(id)
        // would be called with a synthetic "pinned:N" id and silently
        // fail the `cliphist list | grep ^<id>\t` lookup, leaving the
        // row stuck in the pinned section.
        if (entry.pinned) {
            if (typeof entry.pinnedIndex === "number" && entry.pinnedIndex >= 0) {
                root._pendingClampIndex = root.selectedIndex;
                root.pluginApi?.mainInstance?.unpin(entry.pinnedIndex);
            }
            return;
        }
        root._pendingClampIndex = root.selectedIndex;
        root.pluginApi?.mainInstance?.remove(entry.id);
    }

    // Returns the count of items matching the given filter index.
    // Reads itemsRevision AND pinnedRevision so bindings re-evaluate after
    // every history refresh or pin/unpin mutation. Counts are shown in the
    // tab labels — intentionally NOT narrowed by the search query so users
    // can always see the full per-type total while they're typing.
    // Narrowing these would flicker the tab labels on every keystroke and
    // make the "switch tab to broaden results" affordance confusing.
    //
    // Pinned entries are included in the count so the tab numbers reflect
    // what the user will see in the list (pinned + history per type). See
    // docs/specs/pinned-items.md §Behavior — pinned items appear in every
    // tab whose type matches.
    function countForType(typeIndex) {
        const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
        const _prev = pluginApi?.mainInstance?.pinnedRevision ?? 0;
        const all = pluginApi?.mainInstance?.items ?? [];
        const pinned = pluginApi?.mainInstance?.pinnedItems ?? [];
        const typeMap = ["text", "image", "file"];
        const t = typeMap[typeIndex];
        if (!t)
            return 0;
        return all.filter(item => item.type === t).length
             + pinned.filter(item => item.type === t).length;
    }

    // --- Search --------------------------------------------------------------

    // Debounced search term. Never bound directly to the TextField — the
    // debounce timer copies field.text into this property after the user
    // pauses typing. Keeping this property separate from the raw input
    // text is what makes the debounce observable: `filteredItems` reads
    // searchQuery as a binding dependency, so it re-evaluates once per
    // debounce fire rather than once per keystroke.
    property string searchQuery: ""

    // Fuzzy-match `query` against `candidate`. Returns { matched, score }.
    //
    // Match rule: every character of query (case-insensitive) must appear
    // in order inside candidate. Characters need not be contiguous. An
    // empty query matches everything with score 0 so the binding upstream
    // can short-circuit without evaluating this.
    //
    // Scoring (higher is better):
    //   - Exact substring hit earns a large base (1000) plus a bonus that
    //     decays with the hit's offset from the start. Matches anchored at
    //     index 0 sort above matches of equal length found later in the
    //     string — the usual expectation for history search.
    //   - Fallback character-sequence scoring: each matched character
    //     earns 10 points; consecutive matches earn an additional
    //     20-point run bonus; a match immediately after a word-break
    //     character ([\s\-_/.]) earns an extra 15 points. The first
    //     character's position subtracts 1 point per offset index (capped
    //     at 30) so earlier-starting matches edge out later ones.
    //
    // The scorer is intentionally small (~40 lines) and inline — the
    // handoff called for "no new runtime deps" and this is sufficient
    // for the clipboard-history use case (short candidates, short
    // queries, list sizes capped at maxHistorySize).
    function fuzzyMatch(query, candidate) {
        if (!query || query.length === 0)
            return { matched: true, score: 0 };
        if (!candidate || candidate.length === 0)
            return { matched: false, score: 0 };

        const q = String(query).toLowerCase();
        const c = String(candidate).toLowerCase();

        // Exact substring fast path.
        const idx = c.indexOf(q);
        if (idx !== -1) {
            // 1000 baseline, minus offset penalty (earlier = better), minus
            // a small length-gap penalty so shorter haystacks rank higher
            // when the query is the same (clipboard entries vary wildly in
            // length — "http" in "http" should beat "http" in a 500-char
            // log line).
            const offsetPenalty = Math.min(idx, 100);
            const lengthPenalty = Math.min(c.length - q.length, 200) * 0.1;
            return { matched: true, score: 1000 - offsetPenalty - lengthPenalty };
        }

        // Character-sequence scoring.
        let score = 0;
        let qi = 0;
        let lastMatchIdx = -2;
        let firstMatchIdx = -1;
        const wordBreak = /[\s\-_\/.]/;

        for (let ci = 0; ci < c.length && qi < q.length; ci++) {
            if (c[ci] === q[qi]) {
                if (firstMatchIdx === -1)
                    firstMatchIdx = ci;
                score += 10;
                if (ci === lastMatchIdx + 1)
                    score += 20; // consecutive-run bonus
                if (ci > 0 && wordBreak.test(c[ci - 1]))
                    score += 15; // word-boundary bonus
                lastMatchIdx = ci;
                qi++;
            }
        }

        if (qi < q.length)
            return { matched: false, score: 0 };

        // Early-start bonus: penalise by first-match offset, capped.
        const startPenalty = Math.min(firstMatchIdx, 30);
        return { matched: true, score: score - startPenalty };
    }

    // Filtered item list for the current tab selection, narrowed by the
    // (debounced) search query. The type filter runs first so the fuzzy
    // scorer only considers candidates the user is currently viewing —
    // otherwise an image entry could outscore the text the user is
    // looking at on the Text tab.
    //
    // Pinned items are prepended to the cliphist-backed items before the
    // search filter runs, so pinned entries always appear above history
    // entries and are searchable alongside them (see
    // docs/specs/pinned-items.md). Each pinned entry is tagged with
    // `pinned: true` so the delegate can render a pin badge. The merged
    // entry also carries a `pinnedIndex` key so the `P` key handler
    // (Panel.qml root Keys.onPressed) can unpin in O(1) without
    // re-scanning pinnedItems.
    //
    // Reactive dependencies: itemsRevision (list refresh),
    // pinnedRevision (pin/unpin), currentTypeFilter (tab switch),
    // searchQuery (debounced input).
    readonly property var filteredItems: {
        const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
        const _prev = pluginApi?.mainInstance?.pinnedRevision ?? 0;
        const all = pluginApi?.mainInstance?.items ?? [];
        const pinned = pluginApi?.mainInstance?.pinnedItems ?? [];
        const typeMap = ["text", "image", "file"];
        const t = typeMap[root.currentTypeFilter];
        if (!t)
            return [];
        // Tag pinned entries so the delegate can render the badge and the
        // keyboard handler can unpin in one step. Type filter runs against
        // the pinned list as well so the Text / Images / Files tabs each
        // show only matching pinned entries.
        const pinnedTyped = [];
        for (let i = 0; i < pinned.length; i++) {
            if (pinned[i].type !== t)
                continue;
            pinnedTyped.push({
                id: "pinned:" + i,
                preview: pinned[i].preview,
                type: pinned[i].type,
                pinned: true,
                pinnedIndex: i
            });
        }
        // History entries carry pinned: false explicitly so the delegate's
        // binding on `pinned` re-evaluates correctly when a row is rebound
        // under ListView.reuseItems (otherwise the last row's pinned state
        // could leak into a recycled delegate).
        const historyTyped = all
            .filter(item => item.type === t)
            .map(item => ({
                id: item.id,
                preview: item.preview,
                type: item.type,
                pinned: false,
                pinnedIndex: -1
            }));
        const merged = pinnedTyped.concat(historyTyped);
        const q = root.searchQuery;
        if (!q)
            return merged;
        // Score every candidate, keep matches, sort by score desc. Stable
        // within equal scores because Array.sort in QML's JS is stable
        // for modern Qt (V4) engines — important so the recency ordering
        // from cliphist is preserved inside equal-score clusters and the
        // pinned-before-history ordering is preserved on ties.
        const scored = [];
        for (let i = 0; i < merged.length; i++) {
            const m = root.fuzzyMatch(q, merged[i].preview || "");
            if (m.matched)
                scored.push({ item: merged[i], score: m.score, idx: i });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.idx - b.idx;
        });
        return scored.map(e => e.item);
    }

    // --- Lifecycle ----------------------------------------------------------

    // Refresh the clipboard history whenever the panel becomes visible so
    // the very first row always reflects the current clipboard head. This
    // matches Main.qml's single-flight guard — rapid toggles collapse to one.
    //
    // On hide: reset searchQuery and the input text so the next open starts
    // fresh. Stop the debounce timer explicitly to cancel any queued fire
    // from the last session — otherwise a timer queued mid-close would
    // restore the prior query right as the user reopened the panel.
    onVisibleChanged: {
        if (visible) {
            pluginApi?.mainInstance?.refresh();
            // Defer focus grab to the next event-loop cycle so ListView
            // delegates (created synchronously during the same frame as
            // onVisibleChanged) don't win activeFocus after us.
            // We target searchInput directly rather than root so that
            // printable keys land in the field immediately — no extra
            // step required.
            searchFocusTimer.restart();
        } else {
            searchDebounceTimer.stop();
            root.searchQuery = "";
            if (searchInput)
                searchInput.text = "";
            // Clear keyboard selection so the next open starts fresh —
            // otherwise a stale selectedIndex would briefly highlight a
            // row during reopen before onFilteredItemsChanged fires.
            root.selectedIndex = -1;
        }
    }

    // Debounce timer for the search input. One-shot, restarted on every
    // keystroke. 150 ms matches a comfortable "pause before the next
    // keystroke" window — long enough to avoid re-filtering mid-word,
    // short enough that the UI feels responsive. Copy-on-fire (rather
    // than binding searchQuery to input.text) is what makes the
    // debounce observable: filteredItems only re-evaluates when
    // searchQuery changes, not on every TextField edit.
    // Focuses the search field on panel open, deferred by one event-loop
    // tick so ListView delegates can't steal activeFocus after us.
    Timer {
        id: searchFocusTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!root.visible)
                return;
            if (searchInput && searchInput.visible && searchInput.inputItem)
                searchInput.inputItem.forceActiveFocus();
            else
                root.forceActiveFocus();
        }
    }

    Timer {
        id: searchDebounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (searchInput)
                root.searchQuery = searchInput.text;
        }
    }

    // --- Layout -------------------------------------------------------------

    // One-shot deferred-close timer. Owned by Panel (not the delegate) so the
    // close call survives recycled delegates (ListView.reuseItems: true).
    // The 50ms deferral gives ToastService.showNotice() a frame to queue
    // before the panel collapses; without it the toast is dropped on dismiss.
    // Memory-management idiom from docs/specs/plugin-qml-idioms.md:
    // repeat: false, single-shot, self-stopping.
    //
    // Screen reference: `pluginApi.panelOpenScreen` is set by the shell
    // in PluginPanelSlot.onOpened. Using it (rather than a `screen`
    // property we never have injected) is the canonical
    // plugin-entry-point-contracts.md path for close calls. An earlier
    // version passed `root.screen` which was always null because the
    // shell does not inject `screen` into Panel.qml — only `pluginApi`.
    // The null value then drove PanelService.getPanel down its
    // first-match fallback path, which on some layouts returned the
    // wrong slot and made closePanel a no-op.
    Timer {
        id: closePanelTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (!root.pluginApi?.closePanel) {
                Logger.w("Clipboard Plugin", "closePanel unavailable — pluginApi not injected yet");
                return;
            }
            var targetScreen = root.pluginApi.panelOpenScreen;
            var ok = root.pluginApi.closePanel(targetScreen);
            if (!ok) {
                // Diagnostic: if getPanel / currentPluginId match fails the
                // shell returns false. Log once so the failure is visible in
                // the Quickshell log without flooding on repeat attempts.
                Logger.w("Clipboard Plugin", "closePanel returned false — screen:", targetScreen?.name ?? "null");
            }
            if (ok && root.pasteAfterClose) {
                root.pluginApi?.mainInstance?.pasteIntoPreviousWindow();
            }
            root.pasteAfterClose = false;
        }
    }

    // Keyboard shortcuts for the panel as a whole. The Keys attached
    // object on the root Item receives key events when the panel has
    // focus and nothing more specific captures them.
    //
    //   - Any printable single-character keystroke (letters, digits,
    //     punctuation including `/`) moves focus to the search input
    //     and is inserted into it. This delivers the dmenu/rofi-style
    //     "open and just start typing" UX (see
    //     docs/specs/panel-search-autofocus.md).
    //   - Escape clears the search first (if non-empty) rather than
    //     closing the panel. Once the query is empty, a second Escape
    //     falls through to the normal close flow. This matches the
    //     convention used in most GUI search boxes.
    //
    // The type-filter hotkeys and navigation keys existing in other
    // parts of the contract live on their own delegates/handlers — this
    // block is intentionally narrow.
    Keys.onPressed: event => {
        // Ctrl+P: pin / unpin the currently selected row. Must come
        // BEFORE the type-ahead branch so the modifier+letter combo
        // isn't stolen by the search field. The Ctrl modifier also
        // lets this bind work while the search field has focus (the
        // search input's Keys.onPressed does not handle Ctrl+P, so
        // the event bubbles up to here). See docs/specs/pinned-items.md.
        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            root.togglePinSelection();
            event.accepted = true;
            return;
        }

        // Any-printable-char type-ahead. `event.text.length === 1`
        // naturally excludes Escape, Tab, Return, arrows, modifiers,
        // and function keys (all of which produce an empty text
        // string in Qt). The modifier guard prevents Ctrl+A / Alt+F /
        // Super+V style shortcuts from hijacking focus — Shift is
        // deliberately allowed because it yields normal printable
        // characters. Only active when the field is shown (hidden
        // when the clipboard history is empty) and not already
        // focused, so re-entering this branch is a no-op once the
        // user is typing. We do NOT set event.accepted — the same
        // key press propagates to the now-focused TextField on the
        // next delivery and is inserted naturally, without any
        // manual text manipulation.
        if (searchInput.visible && searchInput.inputItem && !searchInput.inputItem.activeFocus && event.text.length === 1 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            // On Wayland key events are not re-delivered after a focus
            // change, so we must insert the character explicitly. NTextInput
            // wraps a TextField — focus and text must go through inputItem
            // (the inner TextField), not the NTextInput wrapper.
            searchInput.text = event.text;
            searchInput.inputItem.forceActiveFocus();
            event.accepted = true;
            return;
        }

        // Navigation keys. Delegate to the shared helpers so the
        // search-input re-dispatchers (Keys.on<Nav>Pressed on
        // searchInput) can use the same logic without duplicating it.
        // Every branch sets event.accepted so the key is consumed at
        // this level and doesn't leak into the ListView's own key
        // handling (which would move ListView.currentIndex, producing
        // a second highlighted row out of sync with selectedIndex).
        switch (event.key) {
        case Qt.Key_Down:
            root.navigateDown();
            event.accepted = true;
            return;
        case Qt.Key_Up:
            root.navigateUp();
            event.accepted = true;
            return;
        case Qt.Key_Home:
            root.navigateHome();
            event.accepted = true;
            return;
        case Qt.Key_End:
            root.navigateEnd();
            event.accepted = true;
            return;
        case Qt.Key_PageDown:
            root.navigatePageDown();
            event.accepted = true;
            return;
        case Qt.Key_PageUp:
            root.navigatePageUp();
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activateSelection();
            event.accepted = true;
            return;
        case Qt.Key_Delete:
            root.deleteSelection();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Escape) {
            if (root.searchQuery.length > 0 || searchInput.text.length > 0) {
                searchDebounceTimer.stop();
                searchInput.text = "";
                root.searchQuery = "";
                event.accepted = true;
                return;
            }
            closePanelTimer.restart();
            event.accepted = true;
        }
    }

    // The shell uses this Item as the geometry reference. Everything the
    // panel renders lives inside it.
    Item {
        id: mainContainer
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            // Style.marginL matches the NotificationHistoryPanel outer gutter
            // — the tighter marginM we used previously made the header feel
            // cramped against the SmartPanel edge.
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // Header card -----------------------------------------------------
            // Wrapping the title row in an NBox mirrors the notification panel's
            // `headerBox`. The card gives the header a visual anchor distinct
            // from the surface below and aligns the icon/title/action cluster
            // with Noctalia's "chrome" convention used across native panels.
            //
            // The card holds two rows driven by an inner ColumnLayout:
            //   1. `header`   — icon + title + wipe + close actions.
            //   2. `typeFilterBar` — the Text / Images / Files filter tabs.
            // This two-row header matches the Audio and Notifications panels,
            // where the primary chrome and the filter/segment control share a
            // single card rather than standing as separate siblings under the
            // outer ColumnLayout. The inner ColumnLayout's implicitHeight
            // drives the NBox height; Style.margin2M still accounts for the
            // anchors.margins (marginM on top + marginM on bottom).
            NBox {
                id: headerBox
                Layout.fillWidth: true
                implicitHeight: headerColumn.implicitHeight + Style.margin2M

                ColumnLayout {
                    id: headerColumn
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    RowLayout {
                        id: header
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        // Primary-color icon: ties the header to the user's
                        // wallpaper-derived accent, matching the notification
                        // panel's "bell" treatment.
                        NIcon {
                            icon: "clipboard"
                            pointSize: Style.fontSizeXXL
                            color: Color.mPrimary
                        }

                        NText {
                            Layout.fillWidth: true
                            text: root.pluginApi?.tr("panel.title")
                            pointSize: Style.fontSizeL
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                        }

                        // Wipe-all: mirrors the notification panel's "clear
                        // history" trash button. Closes the panel on success
                        // since there's nothing left to interact with.
                        NIconButton {
                            icon: "trash"
                            tooltipText: root.pluginApi?.tr("panel.wipe")
                            baseSize: Style.baseWidgetSize * 0.8
                            // Disable while empty — hides a no-op affordance and
                            // matches the "there's nothing to clear" state.
                            enabled: {
                                const _rev = root.pluginApi?.mainInstance?.itemsRevision ?? 0;
                                const items = root.pluginApi?.mainInstance?.items ?? [];
                                return items.length > 0;
                            }
                            onClicked: {
                                root.pluginApi?.mainInstance?.wipe();
                                ToastService.showNotice(root.pluginApi?.tr("toast.history-cleared"));
                                // Close the panel: same UX as the notification
                                // panel's clear-history button.
                                closePanelTimer.restart();
                            }
                        }

                        NIconButton {
                            icon: "settings"
                            tooltipText: root.pluginApi?.tr("panel.settings")
                            baseSize: Style.baseWidgetSize * 0.8
                            onClicked: {
                                BarService.openPluginSettings(root.pluginApi?.panelOpenScreen, root.pluginApi?.manifest);
                            }
                        }
                    }

                    // Type filter tabs --------------------------------------
                    // Lives inside the header card as a second row, matching
                    // the Audio and Notifications panel conventions. Hidden
                    // when the clipboard has no items so the card collapses
                    // back to a single-row header — the ColumnLayout's
                    // `visible: false` handling reclaims the row's height
                    // naturally, so no special-case height math is needed.
                    NTabBar {
                        id: typeFilterBar
                        Layout.fillWidth: true
                        visible: {
                            const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
                            return (pluginApi?.mainInstance?.items?.length ?? 0) > 0;
                        }
                        currentIndex: root.currentTypeFilter
                        tabHeight: Style.toOdd(Style.baseWidgetSize * 0.8)
                        spacing: Style.marginXS
                        distributeEvenly: true

                        NTabButton {
                            tabIndex: 0
                            text: root.pluginApi?.tr("panel.filter-text-count", { count: root.countForType(0) })
                            checked: typeFilterBar.currentIndex === 0
                            onClicked: root.currentTypeFilter = 0
                            pointSize: Style.fontSizeXS
                        }
                        NTabButton {
                            tabIndex: 1
                            text: root.pluginApi?.tr("panel.filter-images-count", { count: root.countForType(1) })
                            checked: typeFilterBar.currentIndex === 1
                            onClicked: root.currentTypeFilter = 1
                            pointSize: Style.fontSizeXS
                        }
                        NTabButton {
                            tabIndex: 2
                            text: root.pluginApi?.tr("panel.filter-files-count", { count: root.countForType(2) })
                            checked: typeFilterBar.currentIndex === 2
                            onClicked: root.currentTypeFilter = 2
                            pointSize: Style.fontSizeXS
                        }
                    }
                }
            }

            // Search input ----------------------------------------------------
            // NTextInput is the Noctalia-styled wrapper around TextField. It
            // brings a focus-aware outlined frame, an inline magnifying-glass
            // icon, and a built-in clear (x) button that appears when the
            // field has content — matching the shell's own settings search
            // fields visually.
            //
            // Why not bind searchQuery: input.text directly? Debouncing:
            // the text property changes on every keystroke, but filteredItems
            // should only re-score the list once the user pauses. The
            // debounce timer above reads searchInput.text when it fires
            // and assigns it to searchQuery, producing a single binding
            // update per typing burst.
            //
            // Hidden while the list is empty to avoid a confusing "search
            // over nothing" affordance — same gating the type filter bar
            // uses.
            NTextInput {
                id: searchInput
                Layout.fillWidth: true
                visible: {
                    const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
                    return (pluginApi?.mainInstance?.items?.length ?? 0) > 0;
                }
                label: ""
                description: ""
                inputIconName: "search"
                placeholderText: root.pluginApi?.tr("panel.search-placeholder")
                showClearButton: true

                // Debounce: restart the timer on every edit rather than
                // writing searchQuery directly. On blur/commit (Enter /
                // focus loss) flush immediately so the user doesn't wait
                // 150 ms after pressing Enter.
                onTextChanged: searchDebounceTimer.restart()
                onAccepted: {
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                }
                onEditingFinished: {
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                }

                // Keys.onPressed handles:
                //   - Escape: clear the field first, then let the root
                //     Keys.onPressed take over on the second press.
                //   - Home / End / PageUp / PageDown: re-dispatch to the
                //     list navigation helpers. These four keys have no
                //     dedicated Keys.on<Key>Pressed signal in QtQuick
                //     (unlike Up/Down/Return/Enter/Delete/Escape), so
                //     they must be handled here via key-code matching.
                //
                // We do NOT intercept Up/Down/Return/Enter here — those
                // are handled by their dedicated Keys.on<Key>Pressed
                // signals below, which produce cleaner code and match
                // the keyboard-navigation idiom in
                // docs/specs/plugin-entry-point-contracts.md.
                Keys.onPressed: event => {
                    // Ctrl+P while the search field has focus: re-dispatch
                    // to the root pin toggle. TextField would otherwise
                    // swallow Ctrl+P with no native binding — empty
                    // handling would leak the keystroke silently. Same
                    // re-dispatch pattern as Home / End / PageUp /
                    // PageDown below.
                    if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                        root.togglePinSelection();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Escape) {
                        if (searchInput.text.length > 0) {
                            searchDebounceTimer.stop();
                            searchInput.text = "";
                            root.searchQuery = "";
                            event.accepted = true;
                        }
                        return;
                    }
                    if (event.key === Qt.Key_Home) {
                        root.navigateHome();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_End) {
                        root.navigateEnd();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_PageUp) {
                        root.navigatePageUp();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_PageDown) {
                        root.navigatePageDown();
                        event.accepted = true;
                        return;
                    }
                }

                // Navigation keys must bubble to the panel-level handler
                // so the user can type a query, press Down, and move
                // into the results without refocusing. The TextField
                // inside NTextInput would otherwise consume Up/Down as
                // cursor moves (no-op on a single-line field).
                //
                // We call the root helpers directly rather than forwarding
                // the event because Keys attached-object handlers are not
                // functions we can invoke programmatically — re-emitting
                // a synthetic event is messier than just calling the
                // helper.
                Keys.onUpPressed: event => {
                    root.navigateUp();
                    event.accepted = true;
                }
                Keys.onDownPressed: event => {
                    root.navigateDown();
                    event.accepted = true;
                }
                Keys.onReturnPressed: event => {
                    // Keep existing search-commit behavior: flush the
                    // debounce, then activate the selection. If there's
                    // no selection yet activateSelection falls back to
                    // index 0 per the spec, which is the usual
                    // "press Enter after typing to copy the top match"
                    // flow.
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                    root.activateSelection();
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    // Same as Return — numpad Enter delivers Key_Enter,
                    // not Key_Return, so handle both.
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                    root.activateSelection();
                    event.accepted = true;
                }
                // Delete is deliberately NOT re-dispatched from the
                // search field: inside an input, Delete means "delete
                // the character under the cursor" — taking it over
                // would break text editing. The user can blur the
                // field (Tab, or Down to move into the list) and then
                // use Delete to prune entries.
            }

            // Empty-state card -----------------------------------------------
            // Matches the notification panel's NBox-wrapped empty state: a
            // large muted icon above a muted label, both centered. Shown
            // when the ListView model is empty. We gate on itemsRevision
            // so it flips correctly once Main.qml's first refresh completes.
            NBox {
                id: emptyBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.filteredItems.length === 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    Item {
                        Layout.fillHeight: true
                    }

                    // Icon flips to a "search-off" glyph when the empty
                    // state is driven by a no-match query rather than an
                    // actually empty history. The distinction is the
                    // difference between "nothing to show" and "nothing
                    // matches what you typed" — users need to know
                    // whether clearing the query would help.
                    NIcon {
                        icon: root.searchQuery.length > 0 ? "search-off" : "clipboard-off"
                        pointSize: Style.baseWidgetSize
                        color: Color.mOnSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                    }

                    NText {
                        text: root.searchQuery.length > 0
                            ? root.pluginApi?.tr("panel.no-matches")
                            : root.pluginApi?.tr("panel.empty")
                        pointSize: Style.fontSizeL
                        color: Color.mOnSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            // History list (Text / Files tabs) --------------------------------
            //
            // Raw ListView (not qs.Widgets.NListView) by deliberate exception to
            // the noctalia-plugins AGENTS.md "prefer N* widgets" rule: the
            // acceptance test requires delegate recycling (`reuseItems: true`)
            // for 100+ entry performance, and NListView does not forward that
            // property through its alias list (checked against the widget source
            // in $XDG_CONFIG_HOME/quickshell/noctalia-shell/Widgets/NListView.qml
            // — aliases cover model/delegate/spacing/currentIndex/contentY and
            // similar, but `reuseItems` is absent). Adopting NListView would
            // regress the ClipboardItem delegate allocation characteristics on
            // scroll. See the PR notes for the known-exception disclosure.
            ListView {
                id: historyList
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Hidden when the image grid is active or there are no items.
                // Also shown for Images tab when showImagePreviews is off.
                visible: (root.currentTypeFilter !== 1 || !root.showImagePreviews) && !emptyBox.visible
                clip: true
                spacing: root.densitySpacing
                // Recycle delegates so 100+ entries don't allocate 100+ rows —
                // the acceptance test specifically calls out no visual lag at
                // that size, and without recycling the delegate allocations
                // show up in scrolling frames.
                reuseItems: true
                // Binding that reads itemsRevision so the model updates when
                // Main.qml mutates items in place (see
                // docs/specs/plugin-qml-idioms.md — revision counter section).
                model: root.filteredItems

                delegate: ClipboardItem {
                    width: historyList.width
                    pluginApi: root.pluginApi
                    // The model entries are {id, preview, type, pinned,
                    // pinnedIndex} objects produced by Panel.qml's
                    // filteredItems merge (pinned + cliphist). `type`
                    // drives image-vs-text rendering inside ClipboardItem
                    // — see docs/specs/image-previews.md. `pinned` shows
                    // the pin badge — see docs/specs/pinned-items.md.
                    entryId: modelData?.id ?? ""
                    previewText: modelData?.preview ?? ""
                    itemType: modelData?.type ?? "text"
                    pinned: modelData?.pinned ?? false
                    pinnedIndex: modelData?.pinnedIndex ?? -1
                    // Keyboard selection driver. `index` is the delegate's
                    // implicit model index; this stays correct under
                    // reuseItems: true because the binding re-evaluates
                    // when the delegate is rebound to a new index.
                    selected: index === root.selectedIndex
                    // Panel owns the close lifecycle so recycled delegates
                    // (reuseItems: true) cannot carry a stale screen
                    // reference through the deferred-close timer — see the
                    // closePanelTimer commentary above.
                    onCopied: {
                        const cfg = root.pluginApi?.pluginSettings || ({});
                        const defaults = root.pluginApi?.manifest?.metadata?.defaultSettings || ({});
                        root.pasteAfterClose = cfg.autoPasteOnSelect ?? defaults.autoPasteOnSelect ?? false;
                        closePanelTimer.restart();
                    }
                }

                // A subtle scrollbar keeps the user oriented in a long list.
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }

            // Image grid (Images tab) -----------------------------------------
            // Two-column grid so thumbnails use horizontal space efficiently.
            // Each cell is sized to a 0.65 aspect ratio (landscape-friendly).
            // Delegates use compact: true so ClipboardItem renders as an image
            // fill with a hover-reveal delete overlay instead of a text row.
            //
            // Uses NGridView (qs.Widgets) per the noctalia-plugins AGENTS.md
            // "prefer N* widgets" rule. cellWidth / cellHeight are set on the
            // NGridView directly — it forwards them to the inner GridView.
            NGridView {
                id: imageGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTypeFilter === 1 && root.showImagePreviews && !emptyBox.visible
                clip: true
                model: root.filteredItems

                cellWidth: Math.floor(availableWidth / 2)
                cellHeight: Math.floor(cellWidth * 0.65)

                // Wrapper Item owns the inter-card gap: marginXS on all sides
                // gives 2*marginXS between adjacent cards and marginXS at the
                // outer edges — symmetric in every direction.
                delegate: Item {
                    width: imageGrid.cellWidth
                    height: imageGrid.cellHeight

                    ClipboardItem {
                        anchors.fill: parent
                        anchors.margins: Style.marginXS
                        compact: true
                        pluginApi: root.pluginApi
                        entryId: modelData?.id ?? ""
                        previewText: modelData?.preview ?? ""
                        itemType: modelData?.type ?? "text"
                        pinned: modelData?.pinned ?? false
                        pinnedIndex: modelData?.pinnedIndex ?? -1
                        // Keyboard selection drives the same fill + border
                        // state as list-mode (see ClipboardItem.qml
                        // background Rectangle) — so grid cells highlight
                        // consistently on the Images tab.
                        selected: index === root.selectedIndex
                        onCopied: {
                            const cfg = root.pluginApi?.pluginSettings || ({});
                            const defaults = root.pluginApi?.manifest?.metadata?.defaultSettings || ({});
                            root.pasteAfterClose = cfg.autoPasteOnSelect ?? defaults.autoPasteOnSelect ?? false;
                            closePanelTimer.restart();
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }
}
