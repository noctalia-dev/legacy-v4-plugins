import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "WidgetRegistry.js" as WidgetRegistry

Item {
    id: root
    property var pluginApi: null
    
    property bool overlayOpen: false
    property var widgets: []
    property var canvasInstance: null
    property var pinnedDisplayInstances: []
    
    function getPinnedWidgets() {
        var pinned = [];
        for (var i = 0; i < widgets.length; i++) {
            if (widgets[i].pinned) pinned.push(widgets[i]);
        }
        return pinned;
    }
    
    // Check if we have any pinned widgets
    readonly property bool hasPinnedWidgets: getPinnedWidgets().length > 0
    
    function loadSettings() {
        if (!pluginApi) return;
        
        try {
            widgets = JSON.parse(pluginApi.pluginSettings.widgets || "[]");
        } catch(e) {
            widgets = [];
        }
        
        if (hasPinnedWidgets) {
            createPinnedDisplays();
        }
    }
    
    function saveWidgets() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.widgets = JSON.stringify(widgets);
        pluginApi.saveSettings();
    }
    
    function createCanvas() {
        if (canvasInstance) return;
        if (!pluginApi || !pluginApi.pluginDir) return;
        
        var component = Qt.createComponent(pluginApi.pluginDir + "/OverlayCanvas.qml");
        if (component.status === Component.Ready) {
            canvasInstance = component.createObject(null, {
                pluginApi: pluginApi,
                mainInstance: root
            });
        } else {
            console.error("OverlayWidgets: Error creating canvas:", component.errorString());
        }
    }
    
    function destroyCanvas() {
        if (canvasInstance) {
            canvasInstance.destroy();
            canvasInstance = null;
        }
    }
    
    function createPinnedDisplays() {
        destroyPinnedDisplays();
        
        if (!pluginApi || !pluginApi.pluginDir) return;
        
        var pinned = getPinnedWidgets();
        for (var i = 0; i < pinned.length; i++) {
            var data = pinned[i];
            var widget = WidgetRegistry.getWidgetById(data.widgetType);
            if (!widget) continue;
            
            var component = Qt.createComponent(pluginApi.pluginDir + "/PinnedWidgetDisplay.qml");
            if (component.status === Component.Ready) {
                var instance = component.createObject(null, {
                    widgetId: data.id,
                    widgetType: data.widgetType,
                    widgetX: data.x,
                    widgetY: data.y,
                    widgetWidth: data.width || widget.defaultWidth,
                    widgetHeight: data.height || widget.defaultHeight,
                    pluginApi: pluginApi
                });
                if (instance) pinnedDisplayInstances.push(instance);
            }
        }
    }
    
    function destroyPinnedDisplays() {
        for (var i = 0; i < pinnedDisplayInstances.length; i++) {
            if (pinnedDisplayInstances[i]) {
                pinnedDisplayInstances[i].destroy();
            }
        }
        pinnedDisplayInstances = [];
    }
    
    function openOverlay() {
        if (overlayOpen) return;
        overlayOpen = true;
        
        destroyPinnedDisplays();
        
        createCanvas();
    }
    
    function closeOverlay() {
        overlayOpen = false;
        
        destroyCanvas();
        
        if (hasPinnedWidgets) {
            createPinnedDisplays();
        }
    }
    
    function toggleWidget(widgetType) {
        var newWidgets = widgets.slice();
        
        for (var i = 0; i < newWidgets.length; i++) {
            if (newWidgets[i].widgetType === widgetType) {
                newWidgets.splice(i, 1);
                widgets = newWidgets;
                saveWidgets();
                return;
            }
        }
        
        var widget = WidgetRegistry.getWidgetById(widgetType);
        if (!widget) return;
        
        var id = "widget_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        newWidgets.push({
            id: id,
            widgetType: widgetType,
            x: 100 + Math.random() * 200,
            y: 150 + Math.random() * 100,
            width: widget.defaultWidth,
            height: widget.defaultHeight,
            pinned: false
        });
        widgets = newWidgets;
        saveWidgets();
    }
    
    function updateWidget(widgetId, x, y, width, height) {
        var newWidgets = widgets.slice();
        for (var i = 0; i < newWidgets.length; i++) {
            if (newWidgets[i].id === widgetId) {
                newWidgets[i] = Object.assign({}, newWidgets[i], {
                    x: x,
                    y: y,
                    width: width || newWidgets[i].width,
                    height: height || newWidgets[i].height
                });
                widgets = newWidgets;
                saveWidgets();
                return;
            }
        }
    }
    
    function removeWidget(widgetId) {
        var newWidgets = widgets.slice();
        for (var i = 0; i < newWidgets.length; i++) {
            if (newWidgets[i].id === widgetId) {
                newWidgets.splice(i, 1);
                widgets = newWidgets;
                saveWidgets();
                return;
            }
        }
    }
    
    function pinWidget(widgetId) {
        var newWidgets = widgets.slice();
        for (var i = 0; i < newWidgets.length; i++) {
            if (newWidgets[i].id === widgetId) {
                newWidgets[i] = Object.assign({}, newWidgets[i], { pinned: true });
                widgets = newWidgets;
                saveWidgets();
                return;
            }
        }
    }
    
    function unpinWidget(widgetId) {
        var newWidgets = widgets.slice();
        for (var i = 0; i < newWidgets.length; i++) {
            if (newWidgets[i].id === widgetId) {
                newWidgets[i] = Object.assign({}, newWidgets[i], { pinned: false });
                widgets = newWidgets;
                saveWidgets();
                return;
            }
        }
    }
    
    function isWidgetActive(widgetType) {
        for (var i = 0; i < widgets.length; i++) {
            if (widgets[i].widgetType === widgetType) return true;
        }
        return false;
    }
    
    IpcHandler {
        target: "plugin:overlay-widgets"
        
        function toggle() {
            if (overlayOpen) {
                closeOverlay();
            } else {
                openOverlay();
            }
        }
    }
    
    Component.onCompleted: {
        loadSettings();
    }
}
