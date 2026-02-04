import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI
import qs.Services.Noctalia
import qs.Widgets

// Fullscreen transparent overlay that captures mouse position
// and shows a context menu with ToDo pages at cursor location
PanelWindow {
    id: root

    required property ShellScreen screen
    property var pluginApi: null
    property string selectedText: ""

    // Callback when page is selected
    signal pageSelected(int pageId, string pageName)
    signal cancelled()

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "noctalia-todo-selector-" + (screen?.name || "unknown")
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Get ToDo pages from plugin
    function getTodoPages() {
        const todoApi = PluginService.getPluginAPI("todo");
        if (!todoApi || !todoApi.pluginSettings || !todoApi.pluginSettings.pages) {
            return [{ id: 0, name: "General" }];
        }
        return todoApi.pluginSettings.pages;
    }

    // Build menu model from ToDo pages
    function buildMenuModel() {
        const pages = getTodoPages();
        const model = [];
        for (let i = 0; i < pages.length; i++) {
            model.push({
                "label": pages[i].name,
                "action": "page-" + pages[i].id,
                "icon": "checkbox",
                "pageId": pages[i].id
            });
        }
        return model;
    }

    // Show the selector - display menu at cursor position
    function show(text) {
        selectedText = text || "";
        contextMenu.model = buildMenuModel();
        visible = true;

        // Wait for compositor to send hover events
        showMenuTimer.start();
    }

    // Timer to wait for hover events from compositor
    Timer {
        id: showMenuTimer
        interval: 150
        repeat: false
        onTriggered: {
            // Position menu at current cursor position (tracked by hoverEnabled)
            anchorPoint.x = mouseCapture.mouseX;
            anchorPoint.y = mouseCapture.mouseY - 30;
            contextMenu.anchorItem = anchorPoint;
            contextMenu.visible = true;
        }
    }

    function close() {
        visible = false;
        contextMenu.visible = false;
    }

    // Context menu for page selection
    NPopupContextMenu {
        id: contextMenu
        visible: false
        screen: root.screen
        minWidth: 200

        onTriggered: (action, item) => {
            if (action.startsWith("page-")) {
                const pageId = parseInt(action.replace("page-", ""));
                const pages = getTodoPages();
                const page = pages.find(p => p.id === pageId);
                root.pageSelected(pageId, page ? page.name : "Unknown");
            }
            root.close();
        }
    }

    // Anchor point for menu positioning
    Item {
        id: anchorPoint
        width: 1
        height: 1
        x: 0
        y: 0
    }

    // Fullscreen mouse area - tracks cursor position via hoverEnabled
    MouseArea {
        id: mouseCapture
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            // Click outside menu - close
            root.cancelled();
            root.close();
        }
    }

    // ESC to cancel
    Keys.onEscapePressed: {
        root.cancelled();
        root.close();
    }

    Component.onDestruction: {
        showMenuTimer.stop();
        close();
    }
}
