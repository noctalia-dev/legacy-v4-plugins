import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "WidgetRegistry.js" as WidgetRegistry

Item {
    id: root
    
    property string widgetId: ""
    property string widgetType: ""
    property real widgetX: 100
    property real widgetY: 100
    property int widgetWidth: 200
    property int widgetHeight: 100
    property bool pinned: false
    property bool editMode: false
    property var pluginApi: null
    property var mainInstance: null
    
    x: widgetX
    y: widgetY
    width: widgetWidth
    height: showHeader ? widgetHeight : widgetHeight - 30
    z: dragArea.drag.active ? 100 : 1
    
    readonly property bool showHeader: editMode
    
    Rectangle {
        id: container
        anchors.fill: parent
        color: Color.mSurface
        radius: Style.radiusM
        border.color: pinned ? Color.mPrimary : (dragArea.drag.active ? Color.mPrimary : Color.mOutline)
        border.width: pinned || dragArea.drag.active ? 2 : 1
        opacity: 0.95
        
        Rectangle {
            id: header
            visible: showHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30
            color: Color.mSurfaceVariant
            radius: Style.radiusM
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Style.radiusM
                color: parent.color
            }
            
            MouseArea {
                id: dragArea
                anchors.fill: parent
                enabled: editMode
                drag.target: root
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.minimumY: 0
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                
                onReleased: {
                    if (mainInstance) {
                        mainInstance.updateWidget(widgetId, root.x, root.y, root.width, root.height);
                    }
                }
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginXS
                spacing: Style.marginXS
                
                NIcon {
                    visible: pinned
                    icon: "pin"
                    color: Color.mPrimary
                }
                
                NText {
                    text: WidgetRegistry.getWidgetById(root.widgetType)?.name || "Widget"
                    Layout.fillWidth: true
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                }
                
                NIconButton {
                    icon: pinned ? "pin-off" : "pin"
                    baseSize: Style.baseWidgetSize * 0.6
                    colorFg: pinned ? Color.mOnSurfaceVariant : Color.mPrimary
                    tooltipText: pinned 
                        ? (pluginApi?.tr("widget.unpin") || "Unpin")
                        : (pluginApi?.tr("widget.pin") || "Pin")
                    
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
                
                NIconButton {
                    icon: "x"
                    baseSize: Style.baseWidgetSize * 0.6
                    colorFg: Color.mError
                    tooltipText: pluginApi?.tr("widget.close") || "Close"
                    
                    onClicked: {
                        if (mainInstance) {
                            mainInstance.removeWidget(widgetId);
                        }
                    }
                }
            }
        }
        
        Item {
            id: contentArea
            anchors.top: showHeader ? header.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.marginS
            
            MouseArea {
                anchors.fill: parent
            }
            
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
}
