import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets
import qs.Services.System

DraggableDesktopWidget {
    id: root
    property var pluginApi: null

    readonly property string widgetImage:          widgetData?.image          ?? ""
    readonly property real   widgetOpacity:        widgetData?.opacity        ?? 1.0
    readonly property bool   widgetMirror:         widgetData?.mirror         ?? false
    readonly property bool   widgetVerticalMirror: widgetData?.verticalMirror ?? false

    readonly property real _size: Math.round(150 * widgetScale)
    readonly property real _stableSize: {
        if (isScaling || isDragging) return _stableSize;

        return _size;
    }

    implicitWidth:  _size
    implicitHeight: _size
    width:  implicitWidth
    height: implicitHeight

    Image {
        id: sticker

        asynchronous: true
        opacity: root.widgetOpacity
        source: Qt.resolvedUrl(root.widgetImage)
        fillMode: Image.PreserveAspectFit

        mirror: root.widgetMirror
        mirrorVertically: root.widgetVerticalMirror

        // 50 pixels more, a bit better quality for a tiny bit more memory usage.
        sourceSize.width:  root._stableSize + 50
        sourceSize.height: root._stableSize + 50

        width: root._size
        height: root._size
    }
}
