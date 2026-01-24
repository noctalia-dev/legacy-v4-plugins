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
    property int widgetX: 100
    property int widgetY: 100
    property int widgetWidth: 200
    property int widgetHeight: 100
    property var pluginApi: null
    
    exclusiveZone: 0
    color: "transparent"
    
    WlrLayershell.namespace: "noctalia:overlay-widgets:pinned:" + widgetId
    WlrLayershell.layer: WlrLayer.Overlay
    
    anchors.top: true
    anchors.left: true
    margins.top: widgetY
    margins.left: widgetX
    
    width: widgetWidth
    height: widgetHeight - 30
    
    Rectangle {
        id: container
        anchors.fill: parent
        color: Color.mSurface
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: 1
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
}
