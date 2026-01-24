import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import "WidgetRegistry.js" as WidgetRegistry

PanelWindow {
    id: root
    
    property var pluginApi: null
    property var mainInstance: null
    
    readonly property bool editMode: mainInstance ? mainInstance.overlayOpen : false
    
    exclusiveZone: 0
    color: editMode ? Qt.rgba(0, 0, 0, 0.3) : "transparent"
    
    WlrLayershell.namespace: "noctalia:overlay-widgets:canvas"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: editMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    MouseArea {
        anchors.fill: parent
        enabled: editMode
        visible: editMode
        onClicked: {
            if (mainInstance) mainInstance.closeOverlay();
        }
    }
    
    Rectangle {
        id: topBar
        visible: editMode
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.marginM
        width: barLayout.implicitWidth + Style.marginM * 2
        height: 50 * Style.uiScaleRatio
        color: Color.mSurface
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: 1
        opacity: 0.95
        z: 1000
        
        MouseArea {
            anchors.fill: parent
        }
        
        RowLayout {
            id: barLayout
            anchors.centerIn: parent
            spacing: Style.marginS
            
            Repeater {
                model: WidgetRegistry.getAllWidgets()
                
                delegate: NIconButton {
                    icon: modelData.icon || "widget"
                    tooltipText: modelData.name || "Widget"
                    colorFg: mainInstance && mainInstance.isWidgetActive(modelData.id) 
                             ? Color.mPrimary 
                             : Color.mOnSurfaceVariant
                    
                    onClicked: {
                        if (mainInstance) mainInstance.toggleWidget(modelData.id);
                    }
                }
            }
            
            Rectangle {
                width: 1
                height: 30 * Style.uiScaleRatio
                color: Color.mOutline
            }
            
            NIconButton {
                icon: "x"
                tooltipText: pluginApi?.tr("bar.close") || "Close"
                colorFg: Color.mError
                
                onClicked: {
                    if (mainInstance) mainInstance.closeOverlay();
                }
            }
        }
    }
    
    Item {
        id: widgetsContainer
        anchors.fill: parent
        
        Repeater {
            id: widgetRepeater
            model: mainInstance ? mainInstance.widgets : []
            
            delegate: WidgetItem {
                visible: editMode || modelData.pinned
                
                widgetId: modelData.id
                widgetType: modelData.widgetType
                widgetX: modelData.x
                widgetY: modelData.y
                widgetWidth: modelData.width
                widgetHeight: modelData.height
                pinned: modelData.pinned
                editMode: root.editMode
                pluginApi: root.pluginApi
                mainInstance: root.mainInstance
            }
        }
    }
    
    Connections {
        target: mainInstance
        function onWidgetsChanged() {
            widgetRepeater.model = [];
            widgetRepeater.model = mainInstance.widgets;
        }
    }
}
