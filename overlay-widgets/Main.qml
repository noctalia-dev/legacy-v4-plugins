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
    property var widgetInstances: ({})
    
    function loadSettings() {
        if (!pluginApi) return;
        
        try {
            widgets = JSON.parse(pluginApi.pluginSettings.widgets || "[]");
        } catch(e) {
            widgets = [];
        }
        
        syncWidgetInstances();
    }
    
    function saveWidgets() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.widgets = JSON.stringify(widgets);
        pluginApi.saveSettings();
    }
    
    function syncWidgetInstances() {
        if (!pluginApi || !pluginApi.pluginDir) return;
        
        var currentIds = {};
        
        for (var i = 0; i < widgets.length; i++) {
            var data = widgets[i];
            currentIds[data.id] = true;
            
            if (!widgetInstances[data.id]) {
                var widgetDef = WidgetRegistry.getWidgetById(data.widgetType);
                if (!widgetDef) continue;
                
                var component = Qt.createComponent(pluginApi.pluginDir + "/WidgetWindow.qml");
                if (component.status === Component.Ready) {
                    var instance = component.createObject(null, {
                        widgetId: data.id,
                        widgetType: data.widgetType,
                        widgetX: data.x,
                        widgetY: data.y,
                        widgetWidth: data.width || widgetDef.defaultWidth,
                        widgetHeight: data.height || widgetDef.defaultHeight,
                        pinned: data.pinned,
                        pluginApi: pluginApi,
                        mainInstance: root,
                        editMode: overlayOpen
                    });
                    if (instance) widgetInstances[data.id] = instance;
                }
            } else {
                widgetInstances[data.id].pinned = data.pinned;
                widgetInstances[data.id].editMode = overlayOpen;
            }
        }
        
        for (var id in widgetInstances) {
            if (!currentIds[id]) {
                widgetInstances[id].destroy();
                delete widgetInstances[id];
            }
        }
    }
    
    function updateWidgetsEditMode() {
        for (var id in widgetInstances) {
            widgetInstances[id].editMode = overlayOpen;
        }
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
        }
    }
    
    function destroyCanvas() {
        if (canvasInstance) {
            canvasInstance.destroy();
            canvasInstance = null;
        }
    }
    
    function openOverlay() {
        if (overlayOpen) return;
        overlayOpen = true;
        
        createCanvas();
        updateWidgetsEditMode();
    }
    
    function closeOverlay() {
        overlayOpen = false;
        
        updateWidgetsEditMode();
        destroyCanvas();
    }
    
    function toggleWidget(widgetType) {
        var newWidgets = widgets.slice();
        
        for (var i = 0; i < newWidgets.length; i++) {
            if (newWidgets[i].widgetType === widgetType) {
                var removedId = newWidgets[i].id;
                newWidgets.splice(i, 1);
                widgets = newWidgets;
                saveWidgets();
                
                if (widgetInstances[removedId]) {
                    widgetInstances[removedId].destroy();
                    delete widgetInstances[removedId];
                }
                return;
            }
        }
        
        var widgetDef = WidgetRegistry.getWidgetById(widgetType);
        if (!widgetDef) return;
        
        var id = "widget_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        newWidgets.push({
            id: id,
            widgetType: widgetType,
            x: 100 + Math.random() * 200,
            y: 150 + Math.random() * 100,
            width: widgetDef.defaultWidth,
            height: widgetDef.defaultHeight,
            pinned: false
        });
        widgets = newWidgets;
        saveWidgets();
        syncWidgetInstances();
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
                
                if (widgetInstances[widgetId]) {
                    widgetInstances[widgetId].destroy();
                    delete widgetInstances[widgetId];
                }
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
                if (widgetInstances[widgetId]) {
                    widgetInstances[widgetId].pinned = true;
                }
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
                if (widgetInstances[widgetId]) {
                    widgetInstances[widgetId].pinned = false;
                }
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
