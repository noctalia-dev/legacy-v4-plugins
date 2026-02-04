import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.Noctalia

Item {
    id: root
    property var pluginApi: null

    // Pending selected text for ToDo selector
    property string pendingSelectedText: ""

    // Pinned items data
    property var pinnedItems: []
    property int pinnedRevision: 0



    // Clipboard items from cliphist
    property var items: []
    property bool loading: false
    property var firstSeenById: ({})

    // Image cache (id -> data URL) with LRU eviction
    property var imageCache: ({})
    property var imageCacheOrder: []  // Track insertion order for LRU
    property int imageCacheRevision: 0  // Incremented when cache changes (for reactive bindings)
    readonly property int maxImageCacheSize: 50  // Limit cache to 50 entries

    // Pending pageId for async operations (ToDo integration)
    property int pendingPageId: 0

    // Constants for limits
    readonly property int maxPinnedItems: 20          // Maximum number of pinned items
    readonly property int maxTodoTextLength: 500      // Maximum text length for ToDo items
    readonly property int maxImageSize: 5 * 1024 * 1024   // 5MB - max image size for pinning
    readonly property int maxTextSize: 1 * 1024 * 1024    // 1MB - max text size for pinning
    readonly property int maxPreviewImageSize: 10 * 1024 * 1024  // 10MB - max image size for preview

    // FileView for pinned.json
    FileView {
        id: pinnedFile
        path: Quickshell.env("HOME") + "/.config/noctalia/plugins/clipper/pinned.json"
        watchChanges: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.pinnedItems = data.items || [];
                root.pinnedRevision++;
            } catch(e) {
                Logger.e("clipper", "Failed to load pinned items: " + e);
                root.pinnedItems = [];
            }
        }
    }

    // Helper function to add to image cache with LRU eviction
    function addToImageCache(cliphistId, dataUrl) {
        // Remove from order if already exists (will re-add at end)
        const existingIndex = root.imageCacheOrder.indexOf(cliphistId);
        if (existingIndex !== -1) {
            root.imageCacheOrder = root.imageCacheOrder.filter((_, i) => i !== existingIndex);
        }

        // Evict oldest entries if at capacity
        while (root.imageCacheOrder.length >= maxImageCacheSize) {
            const oldestKey = root.imageCacheOrder[0];
            root.imageCacheOrder = root.imageCacheOrder.slice(1);
            const newCache = Object.assign({}, root.imageCache);
            delete newCache[oldestKey];
            root.imageCache = newCache;
        }

        // Add new entry
        root.imageCache = Object.assign({}, root.imageCache, {[cliphistId]: dataUrl});
        root.imageCacheOrder = [...root.imageCacheOrder, cliphistId];
        root.imageCacheRevision++;
    }

    // Clear caches (called on wipe)
    function clearCaches() {
        root.imageCache = {};
        root.imageCacheOrder = [];
        root.imageCacheRevision++;
        root.firstSeenById = {};
    }

    // Shared item type detection (used by Panel and ClipboardCard)
    function getItemType(item) {
        if (!item) return "Text";
        if (item.isImage) return "Image";

        const preview = item.preview || "";
        const trimmed = preview.trim();

        // Color detection
        if (/^#[A-Fa-f0-9]{6}$/.test(trimmed) || /^#[A-Fa-f0-9]{3}$/.test(trimmed)) return "Color";
        if (/^[A-Fa-f0-9]{6}$/.test(trimmed)) return "Color";
        if (/^rgba?\s*\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(,\s*[\d.]+\s*)?\)$/i.test(trimmed)) return "Color";

        // Link detection
        if (/^https?:\/\//.test(trimmed)) return "Link";

        // Code detection
        if (preview.includes("function") || preview.includes("import ") ||
            preview.includes("const ") || preview.includes("let ") ||
            preview.includes("var ") || preview.includes("class ") ||
            preview.includes("def ") || preview.includes("return ") ||
            /^[\{\[\(<]/.test(trimmed)) return "Code";

        // Emoji detection
        if (trimmed.length <= 4 && trimmed.length > 0 && trimmed.charCodeAt(0) > 255) return "Emoji";

        // File path detection
        if (/^(\/|~|file:\/\/)/.test(trimmed)) return "File";

        return "Text";
    }

    // Process to list cliphist items
    Process {
        id: listProc
        stdout: StdioCollector {}

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root.items = [];
                root.loading = false;
                return;
            }

            const out = String(stdout.text);
            const lines = out.split('\n').filter(l => l.length > 0);

            const parsed = lines.map(l => {
                let id = "";
                let preview = "";
                const m = l.match(/^(\d+)\s+(.+)$/);
                if (m) {
                    id = m[1];
                    preview = m[2];
                } else {
                    const tab = l.indexOf('\t');
                    id = tab > -1 ? l.slice(0, tab) : l;
                    preview = tab > -1 ? l.slice(tab + 1) : "";
                }

                const lower = preview.toLowerCase();
                const isImage = lower.startsWith("[image]") || lower.includes(" binary data ");

                var mime = "text/plain";
                if (isImage) {
                    if (lower.includes(" png")) mime = "image/png";
                    else if (lower.includes(" jpg") || lower.includes(" jpeg")) mime = "image/jpeg";
                    else if (lower.includes(" webp")) mime = "image/webp";
                    else if (lower.includes(" gif")) mime = "image/gif";
                    else mime = "image/*";
                }

                if (!root.firstSeenById[id]) {
                    root.firstSeenById[id] = Date.now();
                }

                return {
                    "id": id,
                    "preview": preview,
                    "isImage": isImage,
                    "mime": mime
                };
            });

            root.items = parsed;
            root.loading = false;
        }
    }

    // Function to pin item - use preview from items list
    function pinItem(cliphistId) {
        // Validate cliphistId is numeric only (prevents command injection)
        if (!cliphistId || !/^\d+$/.test(String(cliphistId))) {
            Logger.e("clipper", "Invalid clipboard ID: " + cliphistId);
            ToastService.showError("Invalid clipboard item");
            return;
        }

        if (root.pinnedItems.length >= maxPinnedItems) {
            ToastService.showWarning("Maximum " + maxPinnedItems + " pinned items reached");
            return;
        }

        // Find item in current items list to get preview
        const item = root.items.find(i => i.id === cliphistId);
        if (!item) {
            ToastService.showError("Item not found in clipboard");
            Logger.e("clipper", "Cannot pin - item " + cliphistId + " not in items list");
            return;
        }



        const pinnedId = "pinned-" + Date.now() + "-" + cliphistId;

        const newItem = {
            id: pinnedId,
            cliphistId: cliphistId,  // Keep original ID for image decode
            content: "",  // Will be filled for text items
            preview: item.preview,  // Use preview from list
            mime: item.mime || "text/plain",
            isImage: item.isImage || false,
            pinnedAt: Date.now()
        };

        // Decode content (text or image data)
        decodeProc.cliphistId = cliphistId;
        decodeProc.pinnedItem = newItem;

        if (newItem.isImage) {
            // For images, pipe through base64 to avoid binary corruption
            decodeProc.command = ["sh", "-c", `cliphist decode ${cliphistId} | base64 -w 0`];
        } else {
            // For text, direct decode
            decodeProc.command = ["cliphist", "decode", String(cliphistId)];
        }
        decodeProc.running = true;
    }

    // Process to decode content for pinning
    Process {
        id: decodeProc
        property string cliphistId: ""
        property var pinnedItem: null
        stdout: StdioCollector {}

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                Logger.e("clipper", "Failed to decode cliphist item " + cliphistId);
                ToastService.showError("Failed to pin item");
                return;
            }

            if (pinnedItem.isImage) {
                // For images, stdout.text contains base64-encoded data
                const base64 = String(stdout.text).trim();
                if (!base64 || base64.length === 0) {
                    Logger.e("clipper", "Empty image data");
                    ToastService.showError("Failed to pin image");
                    return;
                }

                // Validate image size (approximate: base64 is ~33% larger)
                const estimatedSize = (base64.length * 3) / 4;
                if (estimatedSize > root.maxImageSize) {
                    ToastService.showWarning("Image too large to pin (max 5MB)");
                    return;
                }

                const dataUrl = "data:" + pinnedItem.mime + ";base64," + base64;
                pinnedItem.content = dataUrl;
            } else {
                // For text, validate size (max 1MB)
                const textContent = String(stdout.text);
                if (textContent.length > root.maxTextSize) {
                    ToastService.showWarning("Text too large to pin (max 1MB)");
                    return;
                }

                pinnedItem.content = textContent;
            }

            // Add to array
            root.pinnedItems = [...root.pinnedItems, pinnedItem];

            // Save to file
            root.savePinnedFile();

            // Delete from cliphist
            Quickshell.execDetached(["cliphist", "delete", String(cliphistId)]);

            root.pinnedRevision++;
            ToastService.showNotice("Item pinned");
        }
    }

    // Function to save pinned items to file
    function savePinnedFile() {
        const data = { items: root.pinnedItems };
        const json = JSON.stringify(data, null, 2);

        // Use base64 encoding to safely pass JSON through shell
        // Qt.btoa() produces valid base64 (A-Z, a-z, 0-9, +, /, =) - no shell metacharacters
        // File path is constant, not user-controlled
        const base64 = Qt.btoa(json);
        const filePath = Quickshell.env("HOME") + "/.config/noctalia/plugins/clipper/pinned.json";

        Quickshell.execDetached(["sh", "-c", `echo "${base64}" | base64 -d > "${filePath}"`]);
    }

    // Function to unpin item
    function unpinItem(pinnedId) {
        root.pinnedItems = root.pinnedItems.filter(item => item.id !== pinnedId);
        root.savePinnedFile();
        root.pinnedRevision++;
        ToastService.showNotice("Item unpinned");
    }

    // Process for copying pinned images to clipboard
    Process {
        id: copyPinnedImageProc
        command: ["wl-copy"]
        running: false
        stdinEnabled: true

        onExited: (exitCode) => {
            if (exitCode === 0) {
                ToastService.showNotice("Copied to clipboard");
            } else {
                Logger.e("clipper", "Failed to copy pinned image");
                ToastService.showError("Failed to copy image");
            }
            stdinEnabled = true;  // Re-enable for next use
        }
    }

    // Process for copying pinned text to clipboard
    Process {
        id: copyPinnedTextProc
        command: ["wl-copy", "--"]
        running: false
        stdinEnabled: true

        onExited: (exitCode) => {
            if (exitCode === 0) {
                ToastService.showNotice("Copied to clipboard");
            } else {
                Logger.e("clipper", "Failed to copy pinned text");
                ToastService.showError("Failed to copy text");
            }
            stdinEnabled = true;  // Re-enable for next use
        }
    }

    // Function to copy pinned item to clipboard
    function copyPinnedToClipboard(pinnedId) {
        const item = root.pinnedItems.find(i => i.id === pinnedId);
        if (!item) {
            return;
        }

        if (item.isImage && item.content) {
            // For images, decode base64 and copy binary data
            // Extract base64 from data URL: data:image/png;base64,iVBORw0K...
            const matches = item.content.match(/^data:([^;]+);base64,(.+)$/);
            if (!matches) {
                Logger.e("clipper", "Invalid data URL format");
                ToastService.showError("Failed to copy image");
                return;
            }

            const mimeType = matches[1];
            const base64Data = matches[2];

            // Decode base64 to binary in JavaScript (no shell commands)
            const binaryStr = Qt.atob(base64Data);
            const bytes = new Uint8Array(binaryStr.length);
            for (let i = 0; i < binaryStr.length; i++) {
                bytes[i] = binaryStr.charCodeAt(i);
            }

            // Copy binary data directly via Process stdin
            copyPinnedImageProc.running = true;
            copyPinnedImageProc.write(bytes);
            copyPinnedImageProc.stdinEnabled = false;  // Close stdin to signal EOF
        } else {
            // For text, copy via Process stdin (no shell interpolation)
            copyPinnedTextProc.running = true;
            copyPinnedTextProc.write(item.content || "");
            copyPinnedTextProc.stdinEnabled = false;  // Close stdin to signal EOF
        }
    }

    // Image handling functions
    function getImageData(cliphistId) {
        return root.imageCache[cliphistId] || "";
    }

    function decodeToDataUrl(cliphistId, mimeType, callback) {
        // Validate cliphistId is numeric only (prevents command injection)
        if (!cliphistId || !/^\d+$/.test(String(cliphistId))) {
            Logger.e("clipper", "Invalid cliphistId: " + cliphistId);
            return;
        }

        // Check cache first
        if (root.imageCache[cliphistId]) {
            if (callback) callback(root.imageCache[cliphistId]);
            return;
        }

        // Decode and encode to base64 in one shell command (like official ClipboardService)
        imageDecodeProc.cliphistId = cliphistId;
        imageDecodeProc.mimeType = mimeType || "image/png";
        imageDecodeProc.callback = callback;
        // Use shell to pipe: cliphist decode ID | base64 -w 0
        imageDecodeProc.command = ["sh", "-c", `cliphist decode ${cliphistId} | base64 -w 0`];
        imageDecodeProc.running = true;
    }

    // Process to decode image from cliphist and encode to base64
    Process {
        id: imageDecodeProc
        property string cliphistId: ""
        property string mimeType: "image/png"
        property var callback: null
        stdout: StdioCollector {}

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                return;
            }

            // Read base64-encoded text output
            const base64 = String(stdout.text).trim();
            if (!base64 || base64.length === 0) {
                return;
            }

            // Validate size (approximate: base64 is ~33% larger than binary)
            const estimatedSize = (base64.length * 3) / 4;
            if (estimatedSize > maxPreviewImageSize) {
                return;
            }

            const dataUrl = "data:" + mimeType + ";base64," + base64;

            // Cache it with LRU eviction
            root.addToImageCache(cliphistId, dataUrl);

            if (callback) callback(dataUrl);
        }
    }

    // Process to get selected text (primary selection) - for ToDo integration
    Process {
        id: getSelectionProcess
        command: ["wl-paste", "-p", "-n"]
        stdout: StdioCollector { id: selectionStdout }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                const selectedText = selectionStdout.text.trim();
                if (selectedText && selectedText.length > 0) {
                    root.addTodoWithText(selectedText, root.pendingPageId);
                } else {
                    ToastService.showError("No text selected");
                }
            } else {
                ToastService.showError("Failed to get selection");
            }
        }
    }

    // Add todo with text to specified page via direct PluginService API
    function addTodoWithText(text, pageId) {
        if (!text || text.length === 0) {
            ToastService.showError("No text to add");
            return;
        }

        const todoApi = PluginService.getPluginAPI("todo");
        if (!todoApi) {
            Logger.e("clipper", "ToDo plugin not loaded");
            ToastService.showError("ToDo plugin not available");
            return;
        }

        const trimmedText = text.substring(0, maxTodoTextLength);
        var todos = todoApi.pluginSettings.todos || [];

        var newTodo = {
            id: Date.now(),
            text: trimmedText,
            completed: false,
            createdAt: new Date().toISOString(),
            pageId: pageId
        };

        todos.push(newTodo);
        todoApi.pluginSettings.todos = todos;
        todoApi.pluginSettings.count = todos.length;
        todoApi.saveSettings();

        ToastService.showNotice("Added to ToDo");

        // Also copy to clipboard
        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    // Process for copying to clipboard (prevents command injection)
    Process {
        id: copyToClipboardProc
        property string clipboardId: ""
        stdout: StdioCollector {}

        onExited: (exitCode) => {
            if (exitCode === 0) {
                // Now copy the decoded content to clipboard
                wlCopyProc.write(stdout.data);
                wlCopyProc.stdinEnabled = false;  // Close stdin to signal EOF
            } else {
                Logger.e("clipper", "Failed to decode clipboard item " + clipboardId);
                ToastService.showError("Failed to copy to clipboard");
            }
        }
    }

    // Process for wl-copy
    Process {
        id: wlCopyProc
        command: ["wl-copy"]
        running: false
        stdinEnabled: true

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                Logger.e("clipper", "wl-copy failed with exit code " + exitCode);
            }
            stdinEnabled = true;  // Re-enable for next use
        }
    }

    // Clipboard management functions
    function list(maxPreviewWidth) {
        if (listProc.running) return;
        root.loading = true;
        const width = maxPreviewWidth || 100;
        listProc.command = ["cliphist", "list", "-preview-width", String(width)];
        listProc.running = true;
    }

    function copyToClipboard(id) {
        // Validate id is numeric only (prevents command injection)
        if (!id || !/^\d+$/.test(String(id))) {
            Logger.e("clipper", "Invalid clipboard ID: " + id);
            ToastService.showError("Invalid clipboard item");
            return;
        }

        // Use Process with proper command array (no shell interpolation)
        copyToClipboardProc.clipboardId = id;
        copyToClipboardProc.command = ["cliphist", "decode", String(id)];
        copyToClipboardProc.running = true;
    }

    function deleteById(id) {
        // Validate id is numeric only (prevents command injection)
        if (!id || !/^\d+$/.test(String(id))) {
            Logger.e("clipper", "Invalid clipboard ID: " + id);
            ToastService.showError("Invalid clipboard item");
            return;
        }

        // cliphist delete needs the full line (ID + preview) via stdin
        // ID is validated to be numeric-only, so string interpolation is safe here
        deleteItemProc.command = ["sh", "-c", `cliphist list | grep "^${id}	" | cliphist delete`];
        deleteItemProc.running = true;
    }

    // Process for deleting clipboard item
    Process {
        id: deleteItemProc
        stdout: StdioCollector {}

        onExited: (exitCode) => {
            // Refresh list immediately after deletion
            root.list();
        }
    }

    function wipeAll() {
        wipeProc.running = true;
    }

    // Process for wiping all clipboard history
    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]

        onExited: (exitCode) => {
            // Clear caches and refresh list
            root.clearCaches();
            root.list();
        }
    }

    // Add selected text to specific page
    function addSelectedToPage(pageId) {
        if (!pluginApi?.pluginSettings?.enableTodoIntegration) {
            ToastService.showError("ToDo integration is disabled");
            return;
        }

        root.pendingPageId = pageId;
        getSelectionProcess.running = true;
    }

    IpcHandler {
        target: "plugin:clipper"

        function openPanel() {
            if (pluginApi) {
                const screens = Quickshell.screens;
                if (screens && screens.length > 0) {
                    pluginApi.openPanel(screens[0]);
                }
            }
        }

        function closePanel() {
            if (pluginApi) {
                const screens = Quickshell.screens;
                if (screens && screens.length > 0) {
                    pluginApi.closePanel(screens[0]);
                }
            }
        }

        function togglePanel() {
            if (pluginApi) {
                const screens = Quickshell.screens;
                if (screens && screens.length > 0) {
                    pluginApi.togglePanel(screens[0]);
                }
            }
        }

        // Alias for keybind compatibility
        function toggle() {
            togglePanel();
        }

        // Pinned items IPC handlers
        function pinClipboardItem(cliphistId: string) {
            root.pinItem(cliphistId);
        }

        function unpinItem(pinnedId: string) {
            root.unpinItem(pinnedId);
        }

        function copyPinned(pinnedId: string) {
            root.copyPinnedToClipboard(pinnedId);
        }

        // Show ToDo page selector with current selection
        // Usage: qs -c noctalia-shell ipc call plugin:clipper addSelectionToTodo
        function addSelectionToTodo() {
            if (!pluginApi?.pluginSettings?.enableTodoIntegration) {
                ToastService.showError("ToDo integration is disabled");
                return;
            }
            // Get selected text first, then show selector
            root.getSelectionAndShowSelector();
        }
    }

    // Process to get selected text for ToDo selector
    Process {
        id: getSelectionForSelectorProcess
        command: ["wl-paste", "-p", "-n"]
        stdout: StdioCollector { id: selectorSelectionStdout }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                const selectedText = selectorSelectionStdout.text.trim();
                if (selectedText && selectedText.length > 0) {
                    root.showTodoPageSelector(selectedText);
                } else {
                    ToastService.showError("No text selected");
                }
            } else {
                ToastService.showError("Failed to get selection");
            }
        }
    }

    // Get selection and show page selector
    function getSelectionAndShowSelector() {
        getSelectionForSelectorProcess.running = true;
    }

    // Refresh clipboard list when panel opens
    function refreshOnPanelOpen() {
        root.list();
    }

    // Show ToDo page selector at cursor position
    function showTodoPageSelector(text) {
        root.pendingSelectedText = text;
        // Show selector on first screen (it's fullscreen overlay, will work on any screen)
        if (todoPageSelector) {
            todoPageSelector.show(text);
        } else {
            ToastService.showError("Could not open ToDo selector");
        }
    }

    // Handle page selection from selector
    function handleTodoPageSelected(pageId, pageName) {
        if (root.pendingSelectedText) {
            root.addTodoWithText(root.pendingSelectedText, pageId);
            root.pendingSelectedText = "";
        }
    }

    // ToDo page selector (single instance, uses first screen)
    // It's a fullscreen overlay so it works regardless of which screen cursor is on
    property var todoPageSelector: null

    Variants {
        model: Quickshell.screens

        TodoPageSelector {
            screen: modelData
            pluginApi: root.pluginApi

            Component.onCompleted: {
                // Register first selector as the active one
                if (!root.todoPageSelector) {
                    root.todoPageSelector = this;
                }
            }

            onPageSelected: (pageId, pageName) => {
                root.handleTodoPageSelected(pageId, pageName);
            }

            onCancelled: {
                root.pendingSelectedText = "";
            }
        }
    }

    // Initialize pinned.json if doesn't exist
    Component.onCompleted: {
        // Create empty pinned.json if it doesn't exist
        const configPath = Quickshell.env("HOME") + "/.config/noctalia/plugins/clipper/pinned.json";
        Quickshell.execDetached([
            "sh", "-c",
            `[ -f "${configPath}" ] || echo '{"items":[]}' > "${configPath}"`
        ]);

        // Force reload pinned items from file
        pinnedFile.reload();

        // Load clipboard history
        list();
    }

    // Cleanup all running processes on destruction
    Component.onDestruction: {
        if (listProc.running) listProc.terminate();
        if (decodeProc.running) decodeProc.terminate();
        if (copyPinnedImageProc.running) copyPinnedImageProc.terminate();
        if (copyPinnedTextProc.running) copyPinnedTextProc.terminate();
        if (imageDecodeProc.running) imageDecodeProc.terminate();
        if (getSelectionProcess.running) getSelectionProcess.terminate();
        if (getSelectionForSelectorProcess.running) getSelectionForSelectorProcess.terminate();
        if (copyToClipboardProc.running) copyToClipboardProc.terminate();
        if (wlCopyProc.running) wlCopyProc.terminate();
        if (deleteItemProc.running) deleteItemProc.terminate();
        if (wipeProc.running) wipeProc.terminate();
    }
}
