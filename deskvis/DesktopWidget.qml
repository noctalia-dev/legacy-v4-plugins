import QtQuick
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.Media

DraggableDesktopWidget {
    id: root
    property var widgetSettings: null

    readonly property string spectrumInstanceId: "plugin:deskvis:" + Date.now() + Math.random()
    Component.onCompleted:  SpectrumService.registerComponent(spectrumInstanceId)
    Component.onDestruction: SpectrumService.unregisterComponent(spectrumInstanceId)

    showBackground: false

    readonly property string widgetDirection: widgetData?.direction ?? "up"
    readonly property bool isVertical: widgetDirection === "left" || widgetDirection === "right"

    readonly property int baseW: {
        var cw = widgetData?.customWidth ?? 0
        if (cw > 0) return cw
        return isVertical ? 120 : 480
    }
    readonly property int baseH: {
        var ch = widgetData?.customHeight ?? 0
        if (ch > 0) return ch
        return isVertical ? 480 : 120
    }

    implicitWidth:  Math.round(baseW * widgetScale)
    implicitHeight: Math.round(baseH * widgetScale)
    width:  implicitWidth
    height: implicitHeight

    VisCore {
        anchors.fill:    parent
        orientation:     root.widgetDirection
        widgetScaleHint: root.widgetScale

        visMode:         widgetData?.mode                ?? "bars"
        barCount:        widgetData?.barCount            ?? 32
        fps:             widgetData?.fps                 ?? 60
        sensitivity:     widgetData?.sensitivity         ?? 1.5
        smoothingVal:    widgetData?.smoothing           ?? 0.18
        useGradient:     widgetData?.useGradient         ?? true
        fadeWhenIdle:    widgetData?.fadeWhenIdle        ?? true
        useCustomColors: widgetData?.useCustomColors     ?? false
        customPrimary:   widgetData?.customPrimaryColor  ?? "#6750A4"
        customSecondary: widgetData?.customSecondaryColor ?? "#625B71"
    }
}
