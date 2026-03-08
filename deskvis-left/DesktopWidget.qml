import QtQuick
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.Media

DraggableDesktopWidget {
    id: root
    property var pluginApi: null

    readonly property string spectrumInstanceId: "plugin:deskvis-left:" + Date.now() + Math.random()
    onPluginApiChanged: { if (pluginApi) SpectrumService.registerComponent(spectrumInstanceId) }
    Component.onDestruction: { SpectrumService.unregisterComponent(spectrumInstanceId) }

    showBackground: false

    readonly property int baseW: pluginApi?.pluginSettings?.customWidth  > 0 ? pluginApi.pluginSettings.customWidth  : 120
    readonly property int baseH: pluginApi?.pluginSettings?.customHeight > 0 ? pluginApi.pluginSettings.customHeight : 480

    implicitWidth:  Math.round(baseW * widgetScale)
    implicitHeight: Math.round(baseH * widgetScale)
    width:  implicitWidth
    height: implicitHeight

    VisCore {
        anchors.fill:     parent
        pluginApi:        root.pluginApi
        fixedOrientation: "left"
        widgetScaleHint:  root.widgetScale
    }
}
