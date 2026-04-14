import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    ListModel { id: pinsModel }
    readonly property bool hasPins: pinsModel.count > 0

    function addPin(imgPath, pw, ph, screen) {
        var offset = pinsModel.count * 28
        var w = Math.min(Math.max(pw, 160), 900)
        var h = Math.min(Math.max(ph, 100), 700)
        var sw = screen?.width  ?? 1920
        var sh = screen?.height ?? 1080
        var px = Math.max(0, Math.round((sw - w) / 2) + offset)
        var py = Math.max(0, Math.round((sh - h) / 2) + offset)
        pinsModel.append({
            imgPath:    imgPath,
            w:          w,
            h:          h,
            posX:       px,
            posY:       py,
            screenName: screen?.name ?? "",
            pinOpacity: 1.0,
            fillMode:   "fit"
        })
    }

    function removePin(i) {
        if (i >= 0 && i < pinsModel.count)
            pinsModel.remove(i)
    }

    function updatePin(i, props) {
        if (i < 0 || i >= pinsModel.count) return
        for (var k in props) pinsModel.setProperty(i, k, props[k])
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property ShellScreen modelData
            screen: modelData
            id: pinWindow
            readonly property string _screenName: modelData.name

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            visible: {
                var _ = pinsModel.count
                for (var i = 0; i < pinsModel.count; i++) {
                    var sn = pinsModel.get(i).screenName
                    if (sn === _screenName || sn === "") return true
                }
                return false
            }

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "noctalia-pin"

            mask: Region { item: maskRect }

            Rectangle {
                id: maskRect
                color: "transparent"
                visible: pinWindow.visible

                property var _bbox: {
                    var _ = pinsModel.count
                    var minX = 999999, minY = 999999, maxX = 0, maxY = 0
                    var found = false
                    for (var i = 0; i < pinsModel.count; i++) {
                        var p = pinsModel.get(i)
                        if (p.screenName !== pinWindow._screenName && p.screenName !== "") continue
                        found = true
                        if (p.posX < minX) minX = p.posX
                        if (p.posY < minY) minY = p.posY
                        if (p.posX + p.w > maxX) maxX = p.posX + p.w
                        if (p.posY + p.h > maxY) maxY = p.posY + p.h
                    }
                    return found ? { x: minX, y: minY, w: maxX - minX, h: maxY - minY } : { x: 0, y: 0, w: 0, h: 0 }
                }

                x:      _bbox.x
                y:      _bbox.y
                width:  _bbox.w
                height: _bbox.h
            }

            readonly property var localPins: {
                var _ = pinsModel.count
                var result = []
                for (var i = 0; i < pinsModel.count; i++) {
                    var p = pinsModel.get(i)
                    if (p.screenName === _screenName || p.screenName === "")
                        result.push({
                            imgPath:    p.imgPath,
                            w:          p.w,
                            h:          p.h,
                            pinOpacity: p.pinOpacity,
                            fillMode:   p.fillMode,
                            globalIdx:  i
                        })
                }
                return result
            }

            Repeater {
                model: localPins
                delegate: Item {
                    id: pinDelegate
                    readonly property int edgePx:   8
                    readonly property int cornerPx: 18
                    readonly property int globalIdx: modelData.globalIdx
                    property real   pinW:       globalIdx < pinsModel.count ? pinsModel.get(globalIdx).w        : 0
                    property real   pinH:       globalIdx < pinsModel.count ? pinsModel.get(globalIdx).h        : 0
                    property real   pinOpacity: globalIdx < pinsModel.count ? pinsModel.get(globalIdx).pinOpacity : 1.0
                    property string fillMode:   globalIdx < pinsModel.count ? pinsModel.get(globalIdx).fillMode : "fit"
                    readonly property string pinImgPath: globalIdx < pinsModel.count ? pinsModel.get(globalIdx).imgPath : ""
                    property bool _dragging: false
                    property bool _ctxOpen:  false
                    x: globalIdx < pinsModel.count ? pinsModel.get(globalIdx).posX : 0
                    y: globalIdx < pinsModel.count ? pinsModel.get(globalIdx).posY : 0
                    width:  pinW
                    height: pinH

                    onXChanged: _refreshMask()
                    onYChanged: _refreshMask()
                    onPinWChanged: _refreshMask()
                    onPinHChanged: _refreshMask()

                    function _refreshMask() {
                        if (_dragging)
                            root.updatePin(globalIdx, { posX: x, posY: y, w: pinW, h: pinH })
                    }

                    function resolveFillMode(key) {
                        switch (key) {
                            case "crop":    return Image.PreserveAspectCrop
                            case "stretch": return Image.Stretch
                            default:        return Image.PreserveAspectFit
                        }
                    }

                    Rectangle {
                        id: pinCard
                        anchors.fill: parent
                        radius: Style.radiusL
                        color:  Color.mSurface
                        border.color: cardHover.hovered
                            ? Qt.rgba(1, 1, 1, 0.28)
                            : Qt.rgba(1, 1, 1, 0.07)
                        border.width: Style.capsuleBorderWidth || 1
                        clip: true
                        opacity: pinDelegate.pinOpacity
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Image {
                            anchors.fill: parent
                            source: pinDelegate.pinImgPath !== ""
                                ? "file://" + pinDelegate.pinImgPath : ""
                            fillMode: pinDelegate.resolveFillMode(pinDelegate.fillMode)
                            smooth: true
                            asynchronous: true
                        }
                        HoverHandler { id: cardHover }
                        MouseArea {
                            id: cardMA
                            anchors.fill: parent
                            hoverEnabled: false
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: pinDelegate._dragging
                                ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            drag.target: pinDelegate
                            drag.minimumX: -(pinDelegate.pinW - 60)
                            drag.maximumX: pinDelegate.parent
                                ? pinDelegate.parent.width  - 60 : 9999
                            drag.minimumY: 0
                            drag.maximumY: pinDelegate.parent
                                ? pinDelegate.parent.height - 40 : 9999
                            onPressed: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    ctxMenu.open(mouse.x, mouse.y)
                                    mouse.accepted = true
                                    return
                                }
                                pinDelegate._dragging = true
                            }
                            onReleased: {
                                pinDelegate._dragging = false
                                root.updatePin(pinDelegate.globalIdx, {
                                    posX: pinDelegate.x,
                                    posY: pinDelegate.y
                                })
                            }
                        }
                        Rectangle {
                            id: controlStrip
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: Style.marginM
                            width:  stripRow.implicitWidth + Style.marginM * 2
                            height: 36
                            radius: Style.radiusL
                            color:  Qt.rgba(0, 0, 0, 0.55)
                            z: 3
                            opacity: (cardHover.hovered || pinDelegate._ctxOpen) ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Row {
                                id: stripRow
                                anchors.centerIn: parent
                                spacing: Style.marginS
                                NIcon {
                                    icon: "brightness-half"
                                    color: Qt.rgba(1, 1, 1, 0.7)
                                    scale: 0.8
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    width:  88
                                    height: controlStrip.height
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        id: opTrack
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width; height: 5; radius: 3
                                        color: Qt.rgba(1, 1, 1, 0.25)
                                        Rectangle {
                                            width:  opTrack.width * pinDelegate.pinOpacity
                                            height: parent.height; radius: parent.radius
                                            color:  "white"
                                            Behavior on width { NumberAnimation { duration: 50 } }
                                        }
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: opTrack.verticalCenter
                                        width: 13; height: 13; radius: 7
                                        color: "white"
                                        border.color: Qt.rgba(0, 0, 0, 0.3)
                                        border.width: Style.capsuleBorderWidth
                                        x: opTrack.width * pinDelegate.pinOpacity - width / 2
                                        Behavior on x { NumberAnimation { duration: 50 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.SizeHorCursor
                                        preventStealing: true
                                        property real _startX:  0
                                        property real _startOp: 1.0
                                        onPressed: (mouse) => {
                                            _startX  = mouse.x
                                            _startOp = Math.max(0.05, Math.min(1.0, mouse.x / opTrack.width))
                                            pinDelegate.pinOpacity = _startOp
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (!(mouse.buttons & Qt.LeftButton)) return
                                            var delta = (mouse.x - _startX) / opTrack.width
                                            pinDelegate.pinOpacity = Math.max(0.05, Math.min(1.0, _startOp + delta))
                                        }
                                        onReleased: root.updatePin(pinDelegate.globalIdx, { pinOpacity: pinDelegate.pinOpacity })
                                    }
                                }
                                Rectangle { width: 1; height: 18; radius: 1; color: Qt.rgba(1,1,1,0.25); anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: fillMA.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    NIcon {
                                        anchors.centerIn: parent; scale: 0.8; color: "white"
                                        icon: pinDelegate.fillMode === "fit" ? "aspect-ratio" : pinDelegate.fillMode === "crop" ? "crop" : "arrows-maximize"
                                    }
                                    MouseArea {
                                        id: fillMA; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                        onClicked: {
                                            var next = pinDelegate.fillMode === "fit"  ? "crop" :
                                                       pinDelegate.fillMode === "crop" ? "stretch" : "fit"
                                            pinDelegate.fillMode = next
                                            root.updatePin(pinDelegate.globalIdx, { fillMode: next })
                                        }
                                        onEntered: TooltipService.show(parent,
                                            pinDelegate.fillMode === "fit"  ? root.pluginApi.tr("tooltips.switchToWide") :
                                            pinDelegate.fillMode === "crop" ? root.pluginApi.tr("tooltips.switchToSquare") : root.pluginApi.tr("tooltips.flipCamera"))
                                        onExited: TooltipService.hide()
                                    }
                                }
                                Rectangle { width: 1; height: 18; radius: 1; color: Qt.rgba(1,1,1,0.25); anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: closeMA.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    NIcon { anchors.centerIn: parent; scale: 0.8; icon: "x"; color: "white" }
                                    MouseArea {
                                        id: closeMA; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                        onClicked: root.removePin(pinDelegate.globalIdx)
                                        onEntered: TooltipService.show(parent, root.pluginApi.tr("pin.close"))
                                        onExited: TooltipService.hide()
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: [
                                { ax: "left",  ay: "top"    },
                                { ax: "right", ay: "top"    },
                                { ax: "left",  ay: "bottom" },
                                { ax: "right", ay: "bottom" }
                            ]
                            delegate: Rectangle {
                                width: 8; height: 8; radius: 2
                                color: Qt.rgba(1, 1, 1, 0.7); z: 9
                                anchors {
                                    left:   modelData.ax === "left"   ? parent.left   : undefined
                                    right:  modelData.ax === "right"  ? parent.right  : undefined
                                    top:    modelData.ay === "top"    ? parent.top    : undefined
                                    bottom: modelData.ay === "bottom" ? parent.bottom : undefined
                                }
                                opacity: cardHover.hovered ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                    }

                    component ResizeEdge: MouseArea {
                        id: re
                        property bool isLeft:   false
                        property bool isRight:  false
                        property bool isTop:    false
                        property bool isBottom: false
                        hoverEnabled:    true
                        preventStealing: true
                        z: 10
                        property real _sx: 0; property real _sy: 0
                        property real _sw: 0; property real _sh: 0
                        property real _ox: 0; property real _oy: 0
                        onPressed: (mouse) => {
                            var pt = mapToItem(pinDelegate.parent, mouse.x, mouse.y)
                            _sx = pt.x; _sy = pt.y
                            _sw = pinDelegate.pinW; _sh = pinDelegate.pinH
                            _ox = pinDelegate.x;   _oy = pinDelegate.y
                        }
                        onPositionChanged: (mouse) => {
                            if (!(mouse.buttons & Qt.LeftButton)) return
                            var pt  = mapToItem(pinDelegate.parent, mouse.x, mouse.y)
                            var ddx = pt.x - _sx
                            var ddy = pt.y - _sy
                            if (re.isRight)  pinDelegate.pinW = Math.max(160, _sw + ddx)
                            if (re.isBottom) pinDelegate.pinH = Math.max(100, _sh + ddy)
                            if (re.isLeft) {
                                var nw = Math.max(160, _sw - ddx)
                                pinDelegate.x    = _ox + (_sw - nw)
                                pinDelegate.pinW = nw
                            }
                            if (re.isTop) {
                                var nh = Math.max(100, _sh - ddy)
                                pinDelegate.y    = _oy + (_sh - nh)
                                pinDelegate.pinH = nh
                            }
                        }
                        onReleased: root.updatePin(pinDelegate.globalIdx, {
                            w:    pinDelegate.pinW,
                            h:    pinDelegate.pinH,
                            posX: pinDelegate.x,
                            posY: pinDelegate.y
                        })
                    }
                    ResizeEdge { isRight: true;  x: pinDelegate.pinW - edgePx; y: cornerPx; width: edgePx; height: pinDelegate.pinH - cornerPx * 2; cursorShape: Qt.SizeHorCursor }
                    ResizeEdge { isLeft: true;   x: 0;                          y: cornerPx; width: edgePx; height: pinDelegate.pinH - cornerPx * 2; cursorShape: Qt.SizeHorCursor }
                    ResizeEdge { isBottom: true; x: cornerPx; y: pinDelegate.pinH - edgePx; width: pinDelegate.pinW - cornerPx * 2; height: edgePx; cursorShape: Qt.SizeVerCursor }
                    ResizeEdge { isTop: true;    x: cornerPx; y: 0;             width: pinDelegate.pinW - cornerPx * 2; height: edgePx; cursorShape: Qt.SizeVerCursor }
                    ResizeEdge { isRight: true;  isBottom: true; x: pinDelegate.pinW - cornerPx; y: pinDelegate.pinH - cornerPx; width: cornerPx; height: cornerPx; cursorShape: Qt.SizeFDiagCursor }
                    ResizeEdge { isLeft: true;   isBottom: true; x: 0;                           y: pinDelegate.pinH - cornerPx; width: cornerPx; height: cornerPx; cursorShape: Qt.SizeBDiagCursor }
                    ResizeEdge { isRight: true;  isTop: true;    x: pinDelegate.pinW - cornerPx; y: 0;                           width: cornerPx; height: cornerPx; cursorShape: Qt.SizeBDiagCursor }
                    ResizeEdge { isLeft: true;   isTop: true;    x: 0;                           y: 0;                           width: cornerPx; height: cornerPx; cursorShape: Qt.SizeFDiagCursor }

                    Item {
                        id: ctxMenu
                        visible: false
                        z: 200
                        property real openX: 0
                        property real openY: 0
                        function open(mx, my) {
                            openX = Math.max(0, Math.min(mx, pinDelegate.pinW - menuRect.implicitWidth  - 4))
                            openY = Math.max(0, Math.min(my, pinDelegate.pinH - menuRect.implicitHeight - 4))
                            visible = true
                            pinDelegate._ctxOpen = true
                        }
                        function close() {
                            visible = false
                            pinDelegate._ctxOpen = false
                        }
                        MouseArea {
                            x: -pinDelegate.x; y: -pinDelegate.y
                            width:  pinDelegate.parent ? pinDelegate.parent.width  : 9999
                            height: pinDelegate.parent ? pinDelegate.parent.height : 9999
                            onClicked: ctxMenu.close()
                            z: -1
                        }
                        Rectangle {
                            id: menuRect
                            x: ctxMenu.openX; y: ctxMenu.openY
                            implicitWidth:  menuCol.implicitWidth  + Style.marginS * 2
                            implicitHeight: menuCol.implicitHeight + Style.marginS * 2
                            width: implicitWidth; height: implicitHeight
                            radius: Style.radiusM
                            color: Color.mSurface
                            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: Style.capsuleBorderWidth || 1
                            Column {
                                id: menuCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginS }
                                spacing: Style.marginXS
                                component MenuItem: Rectangle {
                                    property string mIcon:    ""
                                    property string mLabel:   ""
                                    property bool   mEnabled: true
                                    signal activated()
                                    width: parent.width; height: 32; radius: Style.radiusS
                                    color: miMA.containsMouse && mEnabled ? Color.mHover : "transparent"
                                    opacity: mEnabled ? 1.0 : 0.38
                                    Row {
                                        anchors { fill: parent; leftMargin: Style.marginS; rightMargin: Style.marginS }
                                        spacing: Style.marginS
                                        NIcon  { icon: mIcon;  color: Color.mOnSurface; scale: 0.85; anchors.verticalCenter: parent.verticalCenter }
                                        NText  { text: mLabel; color: Color.mOnSurface; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        id: miMA; anchors.fill: parent
                                        enabled: mEnabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { ctxMenu.close(); parent.activated() }
                                    }
                                }
                                MenuItem {
                                    mIcon: "aspect-ratio"
                                    mLabel: root.pluginApi.tr("pin.fillFit")
                                    mEnabled: pinDelegate.fillMode !== "fit"
                                    onActivated: root.updatePin(pinDelegate.globalIdx, { fillMode: "fit" })
                                }
                                MenuItem {
                                    mIcon: "crop"
                                    mLabel: root.pluginApi.tr("pin.fillCrop")
                                    mEnabled: pinDelegate.fillMode !== "crop"
                                    onActivated: root.updatePin(pinDelegate.globalIdx, { fillMode: "crop" })
                                }
                                MenuItem {
                                    mIcon: "arrows-maximize"
                                    mLabel: root.pluginApi.tr("pin.fillStretch")
                                    mEnabled: pinDelegate.fillMode !== "stretch"
                                    onActivated: root.updatePin(pinDelegate.globalIdx, { fillMode: "stretch" })
                                }
                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }
                                MenuItem {
                                    mIcon: "x"
                                    mLabel: root.pluginApi.tr("pin.close")
                                    onActivated: root.removePin(pinDelegate.globalIdx)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
