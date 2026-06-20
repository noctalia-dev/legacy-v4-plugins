import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI
Item {
    id: root
    property var pluginApi: null
    property int _nextPinId: 0
    property int _maskVersion: 0
    property bool _dragActive: false
    // Derived from Style so all sizing scales with the user's UI scale/density settings
    readonly property int _stripBtnSize: Style.baseWidgetSize - Style.marginXS - Style.borderS
    readonly property int _stripDivH:    Style.marginXL
    ListModel { id: pinsModel }
    readonly property bool hasPins: pinsModel.count > 0
    readonly property int  maxPins: 16
    function _fileType(path) {
        var ext = path.split(".").pop().toLowerCase()
        if (ext === "gif") return "gif"
        if (["mp4","webm","mkv","mov","avi"].indexOf(ext) >= 0) return "video"
        return "image"
    }
    function addPin(imgPath, pw, ph, screen) {
        if (pinsModel.count >= maxPins) {
            ToastService.showError(pluginApi?.tr("pin.tooMany"))
            return
        }
        var offset = _nextPinId * 28
        var w  = Math.min(Math.max(pw, 160), 900)
        var h  = Math.min(Math.max(ph, 100), 700)
        var sw = screen?.width  ?? 1920
        var sh = screen?.height ?? 1080
        pinsModel.append({
            pinId:      _nextPinId++,
            imgPath:    imgPath,
            fileType:   _fileType(imgPath),
            w:          w,
            h:          h,
            posX:       Math.max(0, Math.round((sw - w) / 2) + offset),
            posY:       Math.max(0, Math.round((sh - h) / 2) + offset),
            screenName: screen?.name ?? "",
            pinOpacity: 1.0,
            fillMode:   "crop"
        })
    }
    function removePin(i) {
        if (i >= 0 && i < pinsModel.count) pinsModel.remove(i)
    }
    function updatePin(i, props) {
        if (i < 0 || i >= pinsModel.count) return
        for (var k in props) pinsModel.setProperty(i, k, props[k])
        root._maskVersion++
    }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property ShellScreen modelData
            id: pinWindow
            screen: modelData
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
            WlrLayershell.layer:         WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace:     "noctalia-pin"
            mask: Region { item: maskRect }
            Rectangle {
                id: maskRect
                color: "transparent"
                visible: pinWindow.visible
                property var _bbox: {
                    var _c = pinsModel.count
                    var _v = root._maskVersion
                    if (root._dragActive)
                        return { x: 0, y: 0, w: pinWindow.width, h: pinWindow.height }
                    var minX = 999999, minY = 999999, maxX = 0, maxY = 0, found = false
                    for (var i = 0; i < pinsModel.count; i++) {
                        var p = pinsModel.get(i)
                        if (p.screenName !== pinWindow._screenName && p.screenName !== "") continue
                        found = true
                        minX = Math.min(minX, p.posX);  minY = Math.min(minY, p.posY)
                        maxX = Math.max(maxX, p.posX + p.w)
                        maxY = Math.max(maxY, p.posY + p.h)
                    }
                    return found
                        ? { x: minX, y: minY, w: maxX - minX, h: maxY - minY }
                        : { x: 0,    y: 0,    w: 0,           h: 0           }
                }
                x: _bbox.x;  y: _bbox.y
                width: _bbox.w; height: _bbox.h
            }
            Repeater {
                model: pinsModel
                delegate: Item {
                    id: pinDelegate
                    readonly property int _myIndex: index
                    property real   pinW:       model.w
                    property real   pinH:       model.h
                    property real   pinOpacity: model.pinOpacity
                    property string fillMode:   model.fillMode
                    property string fileType:   model.fileType
                    readonly property string pinImgPath: model.imgPath
                    width:  pinW
                    height: pinH
                    Component.onCompleted: {
                        pinDelegate.x    = model.posX
                        pinDelegate.y    = model.posY
                        pinDelegate.pinW = model.w
                        pinDelegate.pinH = model.h
                    }
                    visible: model.screenName === pinWindow._screenName
                          || model.screenName === ""
                    onVisibleChanged: {
                        if (visible) {
                            pinDelegate.x    = model.posX
                            pinDelegate.y    = model.posY
                            pinDelegate.pinW = model.w
                            pinDelegate.pinH = model.h
                        }
                    }
                    property bool _dragging: false
                    property bool _ctxOpen:  false
                    property bool _playing:  true
                    property bool _muted:    false
                    function resolveFillMode(key) {
                        switch (key) {
                        case "crop":    return Image.PreserveAspectCrop
                        case "stretch": return Image.Stretch
                        default:        return Image.PreserveAspectFit
                        }
                    }
                    component ResizeCorner: MouseArea {
                        id: rc
                        property int mode: 0   // 0=BR  1=BL  2=TR  3=TL
                        width: 24; height: 24
                        hoverEnabled: true; preventStealing: true; z: 10
                        cursorShape: (mode === 0 || mode === 3) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                        property point _startPt
                        property real  _startW: 0; property real _startH: 0
                        property real  _startX: 0; property real _startY: 0
                        onPressed: (mouse) => {
                            root._dragActive = true          // ADD THIS
                            var pt  = mapToItem(pinDelegate.parent, mouse.x, mouse.y)
                            _startPt = pt
                            _startW  = pinDelegate.pinW; _startH = pinDelegate.pinH
                            _startX  = pinDelegate.x;   _startY  = pinDelegate.y
                            mouse.accepted = true
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed) return
                            var pt = mapToItem(pinDelegate.parent, mouse.x, mouse.y)
                            var dx = pt.x - _startPt.x
                            var dy = pt.y - _startPt.y
                            var nw = _startW, nh = _startH
                            var nx = _startX, ny = _startY
                            if      (mode === 0) { nw = Math.max(80, _startW + dx); nh = Math.max(60, _startH + dy) }
                            else if (mode === 1) { nw = Math.max(80, _startW - dx); nh = Math.max(60, _startH + dy); nx = _startX + (_startW - nw) }
                            else if (mode === 2) { nw = Math.max(80, _startW + dx); nh = Math.max(60, _startH - dy); ny = _startY + (_startH - nh) }
                            else if (mode === 3) { nw = Math.max(80, _startW - dx); nh = Math.max(60, _startH - dy); nx = _startX + (_startW - nw); ny = _startY + (_startH - nh) }
                            pinDelegate.pinW = nw; pinDelegate.pinH = nh
                            pinDelegate.x    = nx; pinDelegate.y    = ny
                        }
                        onReleased: {
                            root._dragActive = false         // ADD THIS
                            root.updatePin(pinDelegate._myIndex, {
                                w: pinDelegate.pinW, h: pinDelegate.pinH,
                                posX: pinDelegate.x,  posY: pinDelegate.y
                            })
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: Style.marginXS * 2; height: Style.marginXS * 2; radius: Style.marginXXS
                            color: Qt.rgba(1,1,1,0.9)
                            opacity: rc.containsMouse || rc.pressed ? 1.0 : 0.3
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }
                    Rectangle {
                        id: pinCard
                        anchors.fill: parent
                        radius:       Style.radiusL
                        color:        "transparent"
                        border.color: cardHover.hovered ? Qt.rgba(1,1,1,0.28) : Qt.rgba(1,1,1,0.07)
                        border.width: Style.capsuleBorderWidth
                        clip:         true
                        opacity:      pinDelegate.pinOpacity
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Image {
                            anchors.fill: parent
                            visible:      pinDelegate.fileType === "image"
                            source:       pinDelegate.fileType === "image" && pinDelegate.pinImgPath !== ""
                                              ? "file://" + pinDelegate.pinImgPath : ""
                            fillMode:     pinDelegate.resolveFillMode(pinDelegate.fillMode)
                            smooth: true; asynchronous: true
                        }
                        AnimatedImage {
                            anchors.fill: parent
                            visible:      pinDelegate.fileType === "gif"
                            source:       pinDelegate.fileType === "gif" && pinDelegate.pinImgPath !== ""
                                              ? "file://" + pinDelegate.pinImgPath : ""
                            fillMode:     pinDelegate.resolveFillMode(pinDelegate.fillMode)
                            playing:      pinDelegate._playing && pinDelegate.visible
                            smooth: true; asynchronous: true
                        }
                        MediaPlayer {
                            id: mediaPlayer
                            source:      pinDelegate.fileType === "video" && pinDelegate.pinImgPath !== ""
                                             ? "file://" + pinDelegate.pinImgPath : ""
                            loops:       MediaPlayer.Infinite
                            videoOutput: videoOut
                            audioOutput: AudioOutput { muted: pinDelegate._muted }
                            Component.onCompleted:   { if (pinDelegate.fileType === "video" && pinDelegate.visible) play() }
                            Component.onDestruction: stop()
                        }
                        Connections {
                            target: pinDelegate
                            function onVisibleChanged() {
                                if (pinDelegate.fileType !== "video") return
                                if (!pinDelegate.visible) mediaPlayer.stop()
                                else if (pinDelegate._playing) mediaPlayer.play()
                            }
                        }
                        VideoOutput {
                            id: videoOut
                            anchors.fill: parent
                            visible:      pinDelegate.fileType === "video"
                            fillMode:     pinDelegate.resolveFillMode(pinDelegate.fillMode)
                        }
                        Column {
                            anchors.centerIn: parent; spacing: Style.marginS
                            visible: pinDelegate.pinImgPath === ""
                            NIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "photo-off"; color: Color.mOnSurfaceVariant }
                            NText { anchors.horizontalCenter: parent.horizontalCenter; text: root.pluginApi?.tr("pin.noFile"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                        }
                        HoverHandler { id: cardHover }
                        MouseArea {
                            id: cardMA
                            anchors.fill:    parent
                            hoverEnabled:    false
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape:     pinDelegate._dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            z: 1
                            property point _dragStart:  Qt.point(0,0)
                            property real  _itemStartX: 0
                            property real  _itemStartY: 0
                            onPressed: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    ctxMenu.open(mouse.x, mouse.y)
                                    mouse.accepted = true
                                    return
                                }
                                pinDelegate._dragging = true
                                root._dragActive = true          // ADD THIS
                                _dragStart  = mapToItem(null, mouse.x, mouse.y)
                                _itemStartX = pinDelegate.x
                                _itemStartY = pinDelegate.y
                            }
                            onPositionChanged: (mouse) => {
                                if (!pinDelegate._dragging) return
                                var p   = mapToItem(null, mouse.x, mouse.y)
                                var par = pinDelegate.parent
                                pinDelegate.x = Math.max(-(pinDelegate.pinW - 60),
                                                Math.min(par ? par.width  - 60 : 9999,
                                                _itemStartX + (p.x - _dragStart.x)))
                                pinDelegate.y = Math.max(0,
                                                Math.min(par ? par.height - 40 : 9999,
                                                _itemStartY + (p.y - _dragStart.y)))
                            }
                            onReleased: (mouse) => {
                                if (mouse.button === Qt.RightButton) return
                                pinDelegate._dragging = false
                                root._dragActive = false         // ADD THIS
                                root.updatePin(pinDelegate._myIndex, {
                                    posX: pinDelegate.x,
                                    posY: pinDelegate.y
                                })
                            }
                        }
                        Rectangle {
                            id: controlStrip
                            anchors.bottom:           parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin:     Style.marginM
                            width:  stripRow.implicitWidth + Style.marginM * 2
                            height: 36; radius: Style.radiusL
                            color:  Qt.rgba(0,0,0,0.55); z: 3
                            opacity: (cardHover.hovered || pinDelegate._ctxOpen) ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Row {
                                id: stripRow
                                anchors.centerIn: parent; spacing: Style.marginS
                                NIcon { icon: "brightness-half"; color: Qt.rgba(1,1,1,0.7); scale: 0.8; anchors.verticalCenter: parent.verticalCenter }
                                Item {
                                    width: 88; height: controlStrip.height
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        id: opTrack
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width
                                        height: Style.marginXS + Style.marginXXXS; radius: Style.radiusXXXS
                                        color: Qt.rgba(1,1,1,0.25)
                                        Rectangle {
                                            width:  opTrack.width * pinDelegate.pinOpacity
                                            height: parent.height; radius: parent.radius; color: "white"
                                            Behavior on width { NumberAnimation { duration: 50 } }
                                        }
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: opTrack.verticalCenter
                                        width: Style.marginL; height: Style.marginL
                                        radius: Math.round(Style.marginL / 2); color: "white"
                                        border.color: Qt.rgba(0,0,0,0.3); border.width: Style.capsuleBorderWidth
                                        x: opTrack.width * pinDelegate.pinOpacity - width / 2
                                        Behavior on x { NumberAnimation { duration: 50 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.SizeHorCursor; preventStealing: true
                                        property real _startX: 0; property real _startOp: 1.0
                                        onPressed: (mouse) => {
                                            _startX  = mouse.x
                                            _startOp = Math.max(0.05, Math.min(1.0, mouse.x / opTrack.width))
                                            pinDelegate.pinOpacity = _startOp
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (!(mouse.buttons & Qt.LeftButton)) return
                                            pinDelegate.pinOpacity = Math.max(0.05, Math.min(1.0,
                                                _startOp + (mouse.x - _startX) / opTrack.width))
                                        }
                                        onReleased: root.updatePin(pinDelegate._myIndex, { pinOpacity: pinDelegate.pinOpacity })
                                    }
                                }
                                Rectangle { width: Style.borderS; height: root._stripDivH; radius: Style.borderS; color: Qt.rgba(1,1,1,0.25); anchors.verticalCenter: parent.verticalCenter }
                                Rectangle {
                                    width: root._stripBtnSize; height: root._stripBtnSize; radius: root._stripBtnSize / 2
                                    visible: pinDelegate.fileType === "video" || pinDelegate.fileType === "gif"
                                    color: playMA.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    NIcon { anchors.centerIn: parent; scale: 0.8; color: "white"; icon: pinDelegate._playing ? "player-pause" : "player-play" }
                                    MouseArea {
                                        id: playMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                        onClicked: {
                                            pinDelegate._playing = !pinDelegate._playing
                                            if (pinDelegate.fileType === "video") {
                                                if (pinDelegate._playing) mediaPlayer.play()
                                                else mediaPlayer.pause()
                                            }
                                        }
                                        onEntered: TooltipService.show(parent, pinDelegate._playing ? root.pluginApi?.tr("pin.pause") : root.pluginApi?.tr("pin.play"))
                                        onExited:  TooltipService.hide()
                                    }
                                }
                                Rectangle {
                                    width: root._stripBtnSize; height: root._stripBtnSize; radius: root._stripBtnSize / 2
                                    visible: pinDelegate.fileType === "video"
                                    color: muteMA.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    NIcon { anchors.centerIn: parent; scale: 0.8; color: "white"; icon: pinDelegate._muted ? "volume-off" : "volume" }
                                    MouseArea {
                                        id: muteMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                        onClicked: pinDelegate._muted = !pinDelegate._muted
                                        onEntered: TooltipService.show(parent, pinDelegate._muted ? root.pluginApi?.tr("pin.unmute") : root.pluginApi?.tr("pin.mute"))
                                        onExited:  TooltipService.hide()
                                    }
                                }
                                Rectangle { width: Style.borderS; height: root._stripDivH; radius: Style.borderS; color: Qt.rgba(1,1,1,0.25); anchors.verticalCenter: parent.verticalCenter; visible: pinDelegate.fileType === "video" }
                                Rectangle {
                                    width: root._stripBtnSize; height: root._stripBtnSize; radius: root._stripBtnSize / 2
                                    visible: pinDelegate.fileType !== "video"
                                    color: fillMA.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    NIcon {
                                        anchors.centerIn: parent; scale: 0.8; color: "white"
                                        icon: pinDelegate.fillMode === "fit"  ? "aspect-ratio"
                                            : pinDelegate.fillMode === "crop" ? "crop" : "arrows-maximize"
                                    }
                                    MouseArea {
                                        id: fillMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                        onClicked: {
                                            var next = pinDelegate.fillMode === "fit"  ? "crop"
                                                     : pinDelegate.fillMode === "crop" ? "stretch" : "fit"
                                            pinDelegate.fillMode = next
                                            root.updatePin(pinDelegate._myIndex, { fillMode: next })
                                        }
                                        onEntered: TooltipService.show(parent,
                                            pinDelegate.fillMode === "fit"  ? root.pluginApi?.tr("pin.fillFit")
                                          : pinDelegate.fillMode === "crop" ? root.pluginApi?.tr("pin.fillCrop")
                                          : root.pluginApi?.tr("pin.fillStretch"))
                                        onExited: TooltipService.hide()
                                    }
                                }
                                Rectangle { width: Style.borderS; height: root._stripDivH; radius: Style.borderS; color: Qt.rgba(1,1,1,0.25); anchors.verticalCenter: parent.verticalCenter; visible: pinDelegate.fileType !== "video" }
                                Rectangle {
                                    width: root._stripBtnSize; height: root._stripBtnSize; radius: root._stripBtnSize / 2
                                    color: closeMA.containsMouse ? Qt.rgba(1,1,1,0.2) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                    NIcon { anchors.centerIn: parent; scale: 0.8; icon: "x"; color: "white" }
                                    MouseArea {
                                        id: closeMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                                        onClicked: root.removePin(pinDelegate._myIndex)
                                        onEntered: TooltipService.show(parent, root.pluginApi?.tr("pin.close"))
                                        onExited:  TooltipService.hide()
                                    }
                                }
                            }
                        }
                        ResizeCorner { mode: 0; anchors.bottom: parent.bottom; anchors.right: parent.right }
                        ResizeCorner { mode: 1; anchors.bottom: parent.bottom; anchors.left:  parent.left  }
                        ResizeCorner { mode: 2; anchors.top:    parent.top;    anchors.right: parent.right }
                        ResizeCorner { mode: 3; anchors.top:    parent.top;    anchors.left:  parent.left  }
                    } // pinCard
                    Item {
                        id: ctxMenu
                        visible: false; z: 200
                        property real openX: 0; property real openY: 0
                        function open(mx, my) {
                            openX = Math.max(0, Math.min(mx, pinDelegate.pinW - menuRect.implicitWidth  - 4))
                            openY = Math.max(0, Math.min(my, pinDelegate.pinH - menuRect.implicitHeight - 4))
                            visible = true; pinDelegate._ctxOpen = true
                        }
                        function close() { visible = false; pinDelegate._ctxOpen = false }
                        MouseArea {
                            x: -pinDelegate.x; y: -pinDelegate.y
                            width:  pinDelegate.parent ? pinDelegate.parent.width  : 9999
                            height: pinDelegate.parent ? pinDelegate.parent.height : 9999
                            onClicked: ctxMenu.close(); z: -1
                        }
                        Rectangle {
                            id: menuRect
                            x: ctxMenu.openX; y: ctxMenu.openY
                            implicitWidth:  menuCol.implicitWidth  + Style.marginS * 2
                            implicitHeight: menuCol.implicitHeight + Style.marginS * 2
                            width: implicitWidth; height: implicitHeight
                            radius: Style.radiusM; color: Color.mSurface
                            border.color: Qt.rgba(1,1,1,0.12); border.width: Style.capsuleBorderWidth
                            Column {
                                id: menuCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.marginS }
                                spacing: Style.marginXS
                                component MenuItem: Rectangle {
                                    property string mIcon: ""; property string mLabel: ""; property bool mEnabled: true
                                    signal activated()
                                    width: parent.width; height: 32; radius: Style.radiusS
                                    color:   miMA.containsMouse && mEnabled ? Color.mHover : "transparent"
                                    opacity: mEnabled ? 1.0 : 0.38
                                    Row {
                                        anchors { fill: parent; leftMargin: Style.marginS; rightMargin: Style.marginS }
                                        spacing: Style.marginS
                                        NIcon { icon: mIcon;  color: Color.mOnSurface; scale: 0.85; anchors.verticalCenter: parent.verticalCenter }
                                        NText { text: mLabel; color: Color.mOnSurface; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        id: miMA; anchors.fill: parent
                                        enabled: mEnabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { ctxMenu.close(); parent.activated() }
                                    }
                                }
                                MenuItem {
                                    mIcon: "aspect-ratio";    mLabel: root.pluginApi?.tr("pin.fillFit")
                                    mEnabled: pinDelegate.fillMode !== "fit";     visible: pinDelegate.fileType !== "video"
                                    onActivated: root.updatePin(pinDelegate._myIndex, { fillMode: "fit" })
                                }
                                MenuItem {
                                    mIcon: "crop";            mLabel: root.pluginApi?.tr("pin.fillCrop")
                                    mEnabled: pinDelegate.fillMode !== "crop";    visible: pinDelegate.fileType !== "video"
                                    onActivated: root.updatePin(pinDelegate._myIndex, { fillMode: "crop" })
                                }
                                MenuItem {
                                    mIcon: "arrows-maximize"; mLabel: root.pluginApi?.tr("pin.fillStretch")
                                    mEnabled: pinDelegate.fillMode !== "stretch"; visible: pinDelegate.fileType !== "video"
                                    onActivated: root.updatePin(pinDelegate._myIndex, { fillMode: "stretch" })
                                }
                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08); visible: pinDelegate.fileType !== "video" }
                                MenuItem {
                                    mIcon: "x"; mLabel: root.pluginApi?.tr("pin.close")
                                    onActivated: root.removePin(pinDelegate._myIndex)
                                }
                            }
                        }
                    }
                } // pinDelegate
            } // Repeater
        } // PanelWindow
    } // Variants
} // root
