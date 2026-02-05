import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.Noctalia

Item {
    id: root
    property var pluginApi: null

    // Pending pageId for async operations
    property int pendingPageId: 0

    // Process to get selected text (primary selection)
    Process {
        id: getSelectionProcess
        command: ["wl-paste", "-p", "-n"]
        stdout: StdioCollector { id: selectionStdout }
        onExited: (exitCode, exitStatus) => {
            Logger.i("clipper", "wl-paste exited with code " + exitCode);
            if (exitCode === 0) {
                const selectedText = selectionStdout.text.trim();
                Logger.i("clipper", "Selected text length: " + selectedText.length);
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

        const trimmedText = text.substring(0, 500);
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

        Logger.i("clipper", "Added todo to page " + pageId + ": " + trimmedText.substring(0, 50));
        ToastService.showNotice("Added to ToDo");

        // Also copy to clipboard
        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    // Add selected text to specific page
    function addSelectedToPage(pageId) {
        Logger.i("clipper", "addSelectedToPage called with pageId: " + pageId);
        if (!pluginApi?.pluginSettings?.enableTodoIntegration) {
            Logger.w("clipper", "ToDo integration is disabled");
            ToastService.showError("ToDo integration is disabled");
            return;
        }

        root.pendingPageId = pageId;
        Logger.i("clipper", "Starting wl-paste to get selection...");
        getSelectionProcess.running = true;
    }

    IpcHandler {
        target: "plugin:clipper"

        function openPanel() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => pluginApi.openPanel(screen));
            }
        }

        function closePanel() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => pluginApi.closePanel(screen));
            }
        }

        function togglePanel() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => pluginApi.togglePanel(screen));
            }
        }

        // Add selected text to ToDo pages 1-9 (pageId 0-8)
        function addToTodo1() { root.addSelectedToPage(0); }
        function addToTodo2() { root.addSelectedToPage(1); }
        function addToTodo3() { root.addSelectedToPage(2); }
        function addToTodo4() { root.addSelectedToPage(3); }
        function addToTodo5() { root.addSelectedToPage(4); }
        function addToTodo6() { root.addSelectedToPage(5); }
        function addToTodo7() { root.addSelectedToPage(6); }
        function addToTodo8() { root.addSelectedToPage(7); }
        function addToTodo9() { root.addSelectedToPage(8); }

        // Generic - add to specific page
        function addToTodo(pageId: int) { root.addSelectedToPage(pageId); }

        // Add specific text to ToDo (used by clipboard card button)
        function addTextToTodo(text: string, pageId: int) {
            if (pluginApi?.pluginSettings?.enableTodoIntegration) {
                root.addTodoWithText(text, pageId);
            } else {
                ToastService.showError("ToDo integration is disabled");
            }
        }
    }
}
