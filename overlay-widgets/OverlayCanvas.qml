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
    
    exclusiveZone: 0
    color: Qt.rgba(0, 0, 0, 0.3)
    
    WlrLayershell.namespace: "noctalia:overlay-widgets:canvas"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (mainInstance) mainInstance.closeOverlay();
        }
    }
    
    Rectangle {
        id: topBar
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
}
