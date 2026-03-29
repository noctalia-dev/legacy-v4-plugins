import QtQuick 2.15
import qs.Modules.DesktopWidgets 1.0
import qs.Commons

DraggableDesktopWidget {
    id: root

    property var pluginApi: null

    readonly property string imageSource:       widgetData.imageSource       ?? ""
    readonly property bool   transparentBg:     widgetData.transparentBg     ?? false
    
    Component.onCompleted: {
        if (!widgetData.imageSource && pluginApi?.pluginSettings?.imageSource) {
            widgetData.imageSource = pluginApi?.pluginSettings?.imageSource
        }
        if (widgetData.transparentBg === undefined && pluginApi?.pluginSettings?.transparentBg !== undefined) {
            widgetData.transparentBg = pluginApi?.pluginSettings?.transparentBg
        }
    }

    readonly property int baseWidth:    300
    readonly property int baseHeight:   220
    readonly property int basePadding:   8
    readonly property int baseRadius:   10
    readonly property int baseBorder:    1

    readonly property int maxBaseLongSide: screen
                                        ? Math.round(Math.min(320, Math.max(180, Math.min(screen.width, screen.height) * 0.22)))
                                        : 260

    readonly property real photoAspectRatio: {
        if (photo.status === Image.Ready && photo.sourceSize.width > 0 && photo.sourceSize.height > 0)
            return photo.sourceSize.width / photo.sourceSize.height
        return baseWidth / baseHeight
    }

    readonly property int photoWidth: photoAspectRatio >= 1
                                   ? maxBaseLongSide
                                   : Math.max(120, Math.round(maxBaseLongSide * photoAspectRatio))
    readonly property int photoHeight: photoAspectRatio >= 1
                                    ? Math.max(90, Math.round(maxBaseLongSide / photoAspectRatio))
                                    : maxBaseLongSide

    readonly property int frameBaseWidth: transparentBg
                                       ? photoWidth
                                       : (photoWidth + basePadding * 2 + baseBorder * 2)
    readonly property int frameBaseHeight: transparentBg
                                        ? photoHeight
                                        : (photoHeight + basePadding * 2 + baseBorder * 2)

    implicitWidth:  Math.round(Math.max(120, frameBaseWidth) * widgetScale)
    implicitHeight: Math.round(Math.max(90, frameBaseHeight) * widgetScale)

    Rectangle {
        anchors.fill: parent

        color:        transparentBg ? "transparent" : Color.mSurface
        border.color: transparentBg ? "transparent" : Color.mOutline
        border.width: transparentBg ? 0 : Math.round(baseBorder * widgetScale)
        radius:       transparentBg ? 0 : Math.round(baseRadius * widgetScale)

        clip: true

        layer.enabled: !transparentBg && !root.isScaling

        Image {
            id: photo

            anchors {
                fill:    parent
                margins: transparentBg ? 0 : Math.round(basePadding * widgetScale)
            }

            source:          root.imageSource
            fillMode:        Image.PreserveAspectFit
            smooth:          !root.isScaling
            mipmap:          !root.isScaling
            asynchronous:    true
            cache:           true

            Rectangle {
                anchors.fill: parent
                visible:      photo.status !== Image.Ready
                color:        transparentBg ? "transparent" : Color.mSurfaceVariant
                radius:       transparentBg ? 0 : Math.round((baseRadius - 2) * widgetScale)

                Text {
                    anchors.centerIn: parent
                    visible:  !transparentBg
                    text:     photo.status === Image.Loading
                                ? pluginApi?.tr("widget.loading")
                                : pluginApi?.tr("widget.noImage")
                    color:    Color.mOnSurfaceVariant
                    font.pixelSize: Math.round(13 * widgetScale)
                }
            }
        }
    }
}
