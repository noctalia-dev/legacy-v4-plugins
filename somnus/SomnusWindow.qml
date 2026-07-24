import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Services.Compositor
import qs.Services.UI
import qs.Commons
import qs.Widgets

PanelWindow {
    id: win

    property var pluginApi: null
    property ShellScreen screenRef: null
    signal closeRequested()

    property int selectedIndex: -1
    property bool keyboardActive: false

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            win.keyboardActive = false;
        }
    }

    Component.onCompleted: {
        Logger.i("Somnus", "SomnusWindow loaded. screenRef=" + (screenRef?.name ?? "null") + ", wlrOutput=" + (screenRef?.wlrOutput ?? "null") + ", pluginApi=" + (pluginApi !== null) + ", width=" + width + ", height=" + height)
        selectedIndex = -1;
        keyboardActive = false;
        Qt.callLater(() => { focusHandler.forceActiveFocus(); });
    }

    function executeActionByIndex(idx) {
        let actions = ["lock", "logout", "suspend", "hibernate", "reboot", "shutdown"];
        if (idx < 0 || idx >= actions.length) return;
        let actionId = actions[idx];
        Logger.i("Somnus", "Executing " + actionId);
        closeRequested();

        switch (actionId) {
        case "lock":
            CompositorService.lock()
            break
        case "logout":
            CompositorService.logout()
            break
        case "suspend":
            if (pluginApi?.pluginSettings?.lockOnSuspend ?? true)
                CompositorService.lockAndSuspend()
            else
                CompositorService.suspend()
            break
         case "hibernate":
             CompositorService.hibernate()
             break
        case "reboot":
            CompositorService.reboot()
            break
        case "shutdown":
            CompositorService.shutdown()
            break
        }
    }

    color: "transparent"
    readonly property ShellScreen localScreen: screenRef ?? (Quickshell.screens?.length > 0 ? Quickshell.screens[0] : null)
    screen: localScreen

    WlrLayershell.namespace: "somnus"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property string screenName: screenRef?.name ?? ""
    readonly property bool useOverlay: pluginApi?.pluginSettings?.useOverlay ?? true
    readonly property string wallpaperPath: screenName ? WallpaperService.getWallpaper(screenName) : ""

    readonly property real btnW: pluginApi?.pluginSettings?.buttonWidth ?? 420
    readonly property real btnH: pluginApi?.pluginSettings?.buttonHeight ?? 270
    readonly property real btnSp: pluginApi?.pluginSettings?.buttonSpacing ?? 30
    readonly property real gridW: btnW * 3 + btnSp * 2
    readonly property real gridH: btnH * 2 + btnSp * 1

    readonly property real overlayBlur: pluginApi?.pluginSettings?.overlayBlur ?? 0.75
    readonly property real overlayTint: pluginApi?.pluginSettings?.overlayTint ?? 0.6
    readonly property real panelTint: pluginApi?.pluginSettings?.panelTint ?? 0.7
    readonly property bool animEnabled: pluginApi?.pluginSettings?.animationsEnabled ?? true

    Item {
        id: focusHandler
        anchors.fill: parent
        focus: true
        HoverHandler {
            onPointChanged: {
                if (win.keyboardActive) debounceTimer.restart();
            }
        }

        Keys.onPressed: event => {
            const columns = 3;
            const total = 6;
            let row = win.selectedIndex >= 0 ? Math.floor(win.selectedIndex / columns) : 0;
            let col = win.selectedIndex >= 0 ? win.selectedIndex % columns : 0;

            if (event.key === Qt.Key_Escape) {
                closeRequested();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (win.selectedIndex >= 0 && win.selectedIndex < total) {
                    win.executeActionByIndex(win.selectedIndex);
                }
                event.accepted = true;
                return;
            }

            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                debounceTimer.stop();
                win.keyboardActive = true;
                let idx = event.key - Qt.Key_1;
                win.selectedIndex = idx;
                win.executeActionByIndex(idx);
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Right) {
                debounceTimer.stop();
                win.keyboardActive = true;
                if (win.selectedIndex < 0) win.selectedIndex = 0;
                else {
                    col = (col + 1) % columns;
                    win.selectedIndex = row * columns + col;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                debounceTimer.stop();
                win.keyboardActive = true;
                if (win.selectedIndex < 0) win.selectedIndex = total - 1;
                else {
                    col = (col - 1 + columns) % columns;
                    win.selectedIndex = row * columns + col;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                debounceTimer.stop();
                win.keyboardActive = true;
                if (win.selectedIndex < 0) win.selectedIndex = 0;
                else {
                    row = (row + 1) % 2;
                    win.selectedIndex = row * columns + col;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                debounceTimer.stop();
                win.keyboardActive = true;
                if (win.selectedIndex < 0) win.selectedIndex = 0;
                else {
                    row = (row - 1 + 2) % 2;
                    win.selectedIndex = row * columns + col;
                }
                event.accepted = true;
            }
        }
    }

    // OVERLAY MODE
    Item {
        anchors.fill: parent
        visible: useOverlay

        Rectangle {
            anchors.fill: parent
            color: "#000000"
        }

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: wallpaperPath
            cache: false
            smooth: true
            antialiasing: true
            visible: source !== ""

            layer.enabled: overlayBlur > 0
            layer.smooth: false
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: overlayBlur
                blurMax: 48
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                visible: parent.source === ""
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Color.mSurface
            opacity: overlayTint
        }

        Grid {
            anchors.centerIn: parent
            columns: 3
            spacing: btnSp

            Repeater {
                model: ListModel {
                    ListElement { actionId: "lock";      iconImg: "icons/lock.svg" }
                    ListElement { actionId: "logout";    iconImg: "icons/logout.svg" }
                    ListElement { actionId: "suspend";   iconImg: "icons/sleep.svg" }
                    ListElement { actionId: "hibernate"; iconImg: "icons/hibernate.svg" }
                    ListElement { actionId: "reboot";    iconImg: "icons/restart.svg" }
                    ListElement { actionId: "shutdown";  iconImg: "icons/power.svg" }
                }
                delegate: btnDelegate
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: closeRequested()
        }
    }

    // PANEL MODE
    Rectangle {
        anchors.fill: parent
        visible: !useOverlay
        color: Qt.rgba(0, 0, 0, panelTint)

        Grid {
            anchors.centerIn: parent
            columns: 3
            spacing: btnSp

            Repeater {
                model: ListModel {
                    ListElement { actionId: "lock";      iconImg: "icons/lock.svg" }
                    ListElement { actionId: "logout";    iconImg: "icons/logout.svg" }
                    ListElement { actionId: "suspend";   iconImg: "icons/sleep.svg" }
                    ListElement { actionId: "hibernate"; iconImg: "icons/hibernate.svg" }
                    ListElement { actionId: "reboot";    iconImg: "icons/restart.svg" }
                    ListElement { actionId: "shutdown";  iconImg: "icons/power.svg" }
                }
                delegate: btnDelegate
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: closeRequested()
        }
    }

    // BUTTON DELEGATE
    Component {
        id: btnDelegate

        Rectangle {
            id: delegateRoot
            width: btnW
            height: btnH
            radius: Style.iRadiusL
            readonly property bool effectiveHover: !win.keyboardActive && btnMouseArea.containsMouse
            readonly property bool isKeyboardFocused: win.keyboardActive && win.selectedIndex === index
            readonly property bool isActiveState: effectiveHover || isKeyboardFocused
            readonly property real hoverDesat: pluginApi?.pluginSettings?.hoverDesaturation ?? 0.0

            function desaturateColor(c, amount) {
                var newSat = Math.max(0.15, c.hslSaturation * (1 - Math.min(1, amount)));
                return Qt.hsla(c.hslHue, newSat, c.hslLightness, c.hslAlpha);
            }

            color: isActiveState
                ? desaturateColor(Color.resolveColorKey(pluginApi?.pluginSettings?.hoverColor ?? "primary"), hoverDesat)
                : Qt.rgba(0, 0, 0, pluginApi?.pluginSettings?.buttonOpacity ?? 0.75)

            Behavior on color {
                ColorAnimation { duration: animEnabled ? 150 : 0; easing.type: Easing.OutCirc }
            }
            readonly property real initialScale: animEnabled ? 0.85 : 1.0
            readonly property real initialOpacity: animEnabled ? 0.0 : 1.0

            property real entryScale: initialScale
            property real entryOpacity: initialOpacity

            opacity: entryOpacity
            transform: Scale {
                origin.x: width / 2
                origin.y: height / 2
                xScale: entryScale
                yScale: entryScale
            }

            Behavior on entryScale {
                NumberAnimation { duration: animEnabled ? 300 : 0; easing.type: Easing.OutBack; easing.overshoot: animEnabled ? 0.5 : 0 }
            }
            Behavior on entryOpacity {
                NumberAnimation { duration: animEnabled ? 250 : 0; easing.type: Easing.OutQuad }
            }

            Timer {
                id: staggerTimer
                interval: index * 80 + 50
                repeat: false
                onTriggered: {
                    delegateRoot.entryScale = 1.0
                    delegateRoot.entryOpacity = 1.0
                }
            }

            Component.onCompleted: {
                Logger.i("Somnus", "Delegate created: index=" + index + ", actionId=" + actionId + ", width=" + width + ", height=" + height + ", opacity=" + opacity)
                if (animEnabled) staggerTimer.start()
            }

            scale: isActiveState ? (animEnabled ? 1.05 : 1.0) : 1.0
            Behavior on scale {
                NumberAnimation { duration: animEnabled ? 300 : 0; easing.type: animEnabled ? Easing.OutBack : Easing.Linear; easing.overshoot: animEnabled ? 0.5 : 0 }
            }

            Column {
                anchors.centerIn: parent
                spacing: Style.marginXL

                Image {
                    id: btnIcon
                    source: iconImg
                    width: 80
                    height: 80
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter
                    smooth: true
                    mipmap: true
                    antialiasing: true

                    Behavior on scale {
                        NumberAnimation { duration: animEnabled ? 300 : 0; easing.type: animEnabled ? Easing.OutBack : Easing.Linear; easing.overshoot: animEnabled ? 0.6 : 0 }
                    }

                    scale: isActiveState ? (animEnabled ? 1.15 : 1.0) : 1.0
                }

                NText {
                    text: pluginApi?.tr("button." + actionId)
                    color: "#FFFFFF"
                    font.family: "JetBrains Mono NFM"
                    font.pixelSize: 24
                    anchors.horizontalCenter: parent.horizontalCenter

                    Behavior on color { ColorAnimation { duration: animEnabled ? 150 : 0; easing.type: Easing.OutCirc } }
                }
            }

                MouseArea {
                    id: btnMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: {
                        if (!win.keyboardActive) win.selectedIndex = index;
                    }

                    onClicked: {
                        win.selectedIndex = index;
                        win.executeActionByIndex(index);
                    }
                }
        }
    }
}
