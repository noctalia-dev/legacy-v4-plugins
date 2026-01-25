import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import "WidgetRegistry.js" as WidgetRegistry

PanelWindow {
    id: root
    
    property string widgetId: ""
    property string widgetType: ""
    property real widgetX: 100
    property real widgetY: 100
    property int widgetWidth: 200
    property int widgetHeight: 100
    property bool pinned: false
    property var pluginApi: null
    property var mainInstance: null
    property bool editMode: false
    
    visible: editMode || pinned
    
    readonly property int buttonPadding: editMode ? 14 : 0
    readonly property int contentHeight: widgetHeight - 30
    
    exclusiveZone: 0
    color: "transparent"
    
    WlrLayershell.namespace: "noctalia:overlay-widgets:" + widgetId
    WlrLayershell.layer: WlrLayer.Overlay
    
    anchors.top: true
    anchors.left: true
    margins.top: widgetY - buttonPadding
    margins.left: widgetX - buttonPadding
    
    implicitWidth: widgetWidth + buttonPadding * 2
    implicitHeight: contentHeight + buttonPadding * 2
    
    Item {
        id: dragTarget
        x: root.margins.left
        y: root.margins.top
        width: root.implicitWidth
        height: root.implicitHeight
        
        onXChanged: {
            if (dragArea.drag.active) {
                root.margins.left = Math.max(0, Math.round(x)) | 0;
            }
        }
        onYChanged: {
            if (dragArea.drag.active) {
                root.margins.top = Math.max(0, Math.round(y)) | 0;
            }
        }
    }
    
    Rectangle {
        id: container
        x: buttonPadding
        y: buttonPadding
        width: widgetWidth
        height: contentHeight
        color: Color.mSurface
        radius: Style.radiusM
        border.color: editMode ? Color.mPrimary : Color.mOutline
        border.width: editMode ? 2 : 1
        opacity: 0.95
        
        Item {
            id: contentArea
            anchors.fill: parent
            anchors.margins: Style.marginS
            
            Loader {
                id: widgetLoader
                anchors.fill: parent
                source: {
                    if (!pluginApi || !pluginApi.pluginDir) return "";
                    var widget = WidgetRegistry.getWidgetById(widgetType);
                    return widget ? Qt.resolvedUrl(pluginApi.pluginDir + "/" + widget.component) : "";
                }
                
                onLoaded: {
                    if (item) item.pluginApi = pluginApi;
                }
            }
        }
    }
    
    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: editMode
        drag.target: dragTarget
        drag.axis: Drag.XAndYAxis
        drag.minimumX: 0
        drag.minimumY: 0
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        
        onPressed: (mouse) => {
            var dragButtonX = buttonPadding - dragButton.width / 2;
            var dragButtonY = buttonPadding - dragButton.height / 2;
            if (mouse.x >= dragButtonX && mouse.x <= dragButtonX + dragButton.width &&
                mouse.y >= dragButtonY && mouse.y <= dragButtonY + dragButton.height) {
            } else {
                drag.target = null;
            }
        }
        
        onReleased: {
            drag.target = dragTarget;
            
            var actualX = root.margins.left + buttonPadding;
            var actualY = root.margins.top + buttonPadding;
            root.widgetX = actualX;
            root.widgetY = actualY;
            
            if (mainInstance) {
                mainInstance.updateWidget(widgetId, actualX, actualY, root.widgetWidth, root.widgetHeight);
            }
        }
    }
    
    Rectangle {
        id: dragButton
        visible: editMode
        x: buttonPadding - width / 2
        y: buttonPadding - height / 2
        width: 28
        height: 28
        radius: width / 2
        color: dragArea.drag.active ? Color.mPrimary : Color.mSurface
        border.color: dragArea.drag.active ? Color.mPrimary : Color.mOutline
        border.width: 1
        z: 10
        
        NIcon {
            anchors.centerIn: parent
            icon: "arrows-move"
            color: dragArea.drag.active ? Color.mOnPrimary : Color.mOnSurface
        }
    }
    
    Rectangle {
        id: pinButton
        visible: editMode
        x: buttonPadding + widgetWidth - closeButton.width - 4 - width
        y: buttonPadding - height / 2
        width: 28
        height: 28
        radius: width / 2
        color: Color.mSurface
        border.color: Color.mPrimary
        border.width: 1
        z: 10
        
        NIcon {
            anchors.centerIn: parent
            icon: pinned ? "pin-off" : "pin"
            color: Color.mPrimary
        }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (mainInstance) {
                    if (pinned) {
                        mainInstance.unpinWidget(widgetId);
                    } else {
                        mainInstance.pinWidget(widgetId);
                    }
                }
            }
        }
    }
    
    Rectangle {
        id: closeButton
        visible: editMode
        x: buttonPadding + widgetWidth - width / 2
        y: buttonPadding - height / 2
        width: 28
        height: 28
        radius: width / 2
        color: Color.mSurface
        border.color: Color.mError
        border.width: 1
        z: 10
        
        NIcon {
            anchors.centerIn: parent
            icon: "x"
            color: Color.mError
        }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (mainInstance) mainInstance.removeWidget(widgetId);
            }
        }
    }
}
