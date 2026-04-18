import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 560 * Style.uiScaleRatio

    property var main: pluginApi?.mainInstance ?? null

    property string view: "list"

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                // Back button (only visible in browser view)
                NIconButton {
                    icon: "arrow-left"
                    visible: root.view === "browser"
                    onClicked: root.view = "list"
                }

                NIcon {
                    icon: "smart-home"
                    color: root.main?.authenticated ? Color.mPrimary : Color.mOnSurfaceVariant
                }

                NText {
                    text: root.view === "list" ? pluginApi?.tr("panel.title") : pluginApi?.tr("panel.title_add")
                    pointSize: Style.fontSizeL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                // Connection indicator dot
                Rectangle {
                    width: Style.marginS
                    height: Style.marginS
                    radius: width / 2
                    color: {
                        if (!root.main?.connected)
                            return Color.mError;
                        if (!root.main?.authenticated)
                            return Color.mOnError;
                        return Color.mPrimary;
                    }
                }

                // Add entities button (only in list view)
                NIconButton {
                    icon: "plus"
                    visible: root.view === "list"
                    onClicked: {
                        browserView.load();
                        root.view = "browser";
                    }
                }
            }

            NDivider {
                Layout.fillWidth: true
            }

            // List view
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.view === "list"

                // Empty / error states - shown only when there is nothing to list
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginM
                    visible: !(root.main?.entities && root.main.entities.count > 0)

                    // Connection error - only after a genuine drop, not during initial startup
                    ColumnLayout {
                        visible: !!(root.main && !root.main.connected && !root.main.authFailed && root.main.haToken !== "" && root.main.isReconnecting)
                        spacing: Style.marginM

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.error_connection_failed")
                            color: Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeM
                        }

                        NButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.btn_reconnect")
                            onClicked: root.main.reconnect()
                        }
                    }

                    // Auth error / missing token
                    ColumnLayout {
                        visible: !!(root.main && (root.main.authFailed || root.main.haToken === ""))
                        spacing: Style.marginM

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.main?.haToken === "" ? pluginApi?.tr("panel.error_token_missing") : pluginApi?.tr("panel.error_auth_failed")
                            color: Color.mSecondary
                            pointSize: Style.fontSizeM
                        }

                        NButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.btn_retry_auth")
                            onClicked: root.main.reconnect()
                        }
                    }

                    // Authenticated but nothing pinned yet
                    ColumnLayout {
                        visible: !!(root.main && root.main.authenticated && root.main.entities.count === 0)
                        spacing: Style.marginM

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.empty_no_entities")
                            color: Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeM
                        }

                        NButton {
                            Layout.alignment: Qt.AlignHCenter
                            text: pluginApi?.tr("panel.btn_add_entities")
                            onClicked: {
                                browserView.load();
                                root.view = "browser";
                            }
                        }
                    }
                }

                // Entity list - only when entities exist
                ListView {
                    anchors.fill: parent
                    clip: true
                    visible: !!(root.main?.entities && root.main.entities.count > 0)
                    model: root.main?.entities ?? null
                    spacing: Style.marginS

                    delegate: Rectangle {
                        id: entityDelegate
                        width: ListView.view.width
                        height: Math.round(64 * Style.uiScaleRatio) + (showBrightness ? Math.round(56 * Style.uiScaleRatio) : 0) + (showColorTemp ? Math.round(56 * Style.uiScaleRatio) : 0)
                        color: Color.mSurfaceVariant
                        radius: Style.radiusM
                        clip: true

                        property bool isWaiting: false
                        property bool isExpanded: false

                        readonly property bool canExpand: isLight(model.domain) && (model.supports_brightness || model.supports_color_temp)

                        readonly property bool showBrightness: isExpanded && model.supports_brightness
                        readonly property bool showColorTemp: isExpanded && model.supports_color_temp

                        Behavior on height {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.InOutQuad
                            }
                        }

                        Connections {
                            target: root.main

                            function onEntityUpdated(updatedId) {
                                if (updatedId === model.entity_id)
                                    entityDelegate.isWaiting = false;
                            }
                        }

                        // Single fallback timer - resets isWaiting if no state update arrives
                        Timer {
                            id: waitingTimeout
                            running: entityDelegate.isWaiting
                            interval: isAutomation(model.domain) ? 5000 : 3000
                            onTriggered: entityDelegate.isWaiting = false
                        }

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: Style.marginM
                            }
                            spacing: Style.marginS

                            // ── Main row ─────────────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.marginM

                                NIcon {
                                    icon: domainIcon(model.domain)
                                    color: stateColor(model.domain, model.state)

                                    SequentialAnimation on opacity {
                                        running: entityDelegate.isWaiting
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            to: 0.4
                                            duration: 400
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            to: 1.0
                                            duration: 400
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    opacity: entityDelegate.isWaiting ? opacity : 1.0
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.marginXS

                                    NText {
                                        text: model.friendly_name
                                        color: Color.mOnSurface
                                        pointSize: Style.fontSizeM
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    NText {
                                        text: {
                                            if (entityDelegate.isWaiting)
                                                return pluginApi?.tr("panel.state_updating");
                                            if (isSensor(model.domain))
                                                return model.state + (model.unit ? " " + model.unit : "");
                                            if (isLight(model.domain) && model.state === "on" && model.brightness >= 0)
                                                return pluginApi?.tr("panel.state_on_brightness", {
                                                    percent: Math.round(model.brightness / 255 * 100)
                                                });
                                            return model.state;
                                        }
                                        color: Color.mOnSurfaceVariant
                                        pointSize: Style.fontSizeS
                                    }
                                }

                                // Expand chevron for lights with adjustable properties
                                NIconButton {
                                    visible: entityDelegate.canExpand
                                    icon: entityDelegate.isExpanded ? "chevron-up" : "chevron-down"
                                    color: Color.mOnSurfaceVariant
                                    onClicked: entityDelegate.isExpanded = !entityDelegate.isExpanded
                                }

                                // Automation / script trigger
                                NIconButton {
                                    id: automationBtn
                                    visible: isAutomation(model.domain)
                                    icon: entityDelegate.isWaiting ? "refresh" : "player-play"
                                    color: entityDelegate.isWaiting ? Color.mOnSurfaceVariant : Color.mTertiary

                                    rotation: entityDelegate.isWaiting ? rotation : 0

                                    RotationAnimation on rotation {
                                        running: entityDelegate.isWaiting
                                        from: 0
                                        to: 360
                                        duration: 800
                                        loops: Animation.Infinite
                                        onStopped: automationBtn.rotation = 0
                                    }

                                    onClicked: {
                                        entityDelegate.isWaiting = true;
                                        const service = model.domain === "script" ? "turn_on" : "trigger";
                                        root.main.callService(model.domain, service, model.entity_id);
                                    }
                                }

                                // Toggle for controllable non-light domains
                                NIconButton {
                                    id: switchToggleBtn
                                    visible: isControllable(model.domain) && !isLight(model.domain)
                                    icon: entityDelegate.isWaiting ? "refresh" : (model.state === "on" ? "toggle-right" : "toggle-left")
                                    color: model.state === "on" ? Color.mTertiary : Color.mOutline

                                    rotation: entityDelegate.isWaiting ? rotation : 0

                                    RotationAnimation on rotation {
                                        running: entityDelegate.isWaiting
                                        from: 0
                                        to: 360
                                        duration: 800
                                        loops: Animation.Infinite
                                        onStopped: switchToggleBtn.rotation = 0
                                    }

                                    onClicked: {
                                        entityDelegate.isWaiting = true;
                                        root.main.callService(model.domain, "toggle", model.entity_id);
                                    }
                                }

                                // Light toggle (separate so chevron and toggle coexist)
                                NIconButton {
                                    id: lightToggleBtn
                                    visible: isLight(model.domain)
                                    icon: entityDelegate.isWaiting ? "refresh" : (model.state === "on" ? "toggle-right" : "toggle-left")
                                    color: model.state === "on" ? Color.mTertiary : Color.mOutline

                                    rotation: entityDelegate.isWaiting ? rotation : 0

                                    RotationAnimation on rotation {
                                        running: entityDelegate.isWaiting
                                        from: 0
                                        to: 360
                                        duration: 800
                                        loops: Animation.Infinite
                                        onStopped: lightToggleBtn.rotation = 0
                                    }

                                    onClicked: {
                                        entityDelegate.isWaiting = true;
                                        root.main.callService("light", "toggle", model.entity_id);
                                    }
                                }
                            }

                            // Brightness slider
                            RowLayout {
                                Layout.fillWidth: true
                                visible: entityDelegate.showBrightness
                                spacing: Style.marginS

                                NIcon {
                                    icon: "sun"
                                    color: Color.mOnSurfaceVariant
                                }

                                NSlider {
                                    id: brightnessSlider
                                    Layout.fillWidth: true
                                    from: 1
                                    to: 255
                                    value: model.brightness > 0 ? model.brightness : 255
                                    stepSize: 1

                                    onPressedChanged: {
                                        if (!pressed)
                                            root.main.callLightService(model.entity_id, value, -1);
                                    }

                                    Rectangle {
                                        visible: brightnessSlider.pressed
                                        width: ttBrightness.implicitWidth + Style.marginM * 2
                                        height: ttBrightness.implicitHeight + Style.marginS * 2
                                        radius: Style.radiusS
                                        color: Color.mSurface
                                        border.color: Color.mOutline
                                        border.width: Style.borderS
                                        z: 10

                                        x: Math.min(Math.max(0, (brightnessSlider.value - brightnessSlider.from) / (brightnessSlider.to - brightnessSlider.from) * brightnessSlider.width - width / 2), brightnessSlider.width - width)
                                        y: -height - Style.marginS

                                        NText {
                                            id: ttBrightness
                                            anchors.centerIn: parent
                                            text: Math.round(brightnessSlider.value / 255 * 100) + "%"
                                            color: Color.mOnSurface
                                            pointSize: Style.fontSizeS
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                NText {
                                    text: Math.round((model.brightness > 0 ? model.brightness : 255) / 255 * 100) + "%"
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                    Layout.preferredWidth: Math.round(44 * Style.uiScaleRatio)
                                }
                            }

                            // Color temperature slider
                            RowLayout {
                                Layout.fillWidth: true
                                visible: entityDelegate.showColorTemp
                                spacing: Style.marginS

                                NIcon {
                                    icon: "flame"
                                    color: Color.mOnSurfaceVariant
                                }

                                NSlider {
                                    id: colorTempSlider
                                    Layout.fillWidth: true
                                    from: 153
                                    to: 500
                                    value: model.color_temp > 0 ? model.color_temp : 300
                                    stepSize: 1

                                    onPressedChanged: {
                                        if (!pressed)
                                            root.main.callLightService(model.entity_id, -1, value);
                                    }

                                    Rectangle {
                                        visible: colorTempSlider.pressed
                                        width: ttColorTemp.implicitWidth + Style.marginM * 2
                                        height: ttColorTemp.implicitHeight + Style.marginS * 2
                                        radius: Style.radiusS
                                        color: Color.mSurface
                                        border.color: Color.mOutline
                                        border.width: Style.borderS
                                        z: 10

                                        x: Math.min(Math.max(0, (colorTempSlider.value - colorTempSlider.from) / (colorTempSlider.to - colorTempSlider.from) * colorTempSlider.width - width / 2), colorTempSlider.width - width)
                                        y: -height - Style.marginS

                                        NText {
                                            id: ttColorTemp
                                            anchors.centerIn: parent
                                            text: Math.round(1000000 / colorTempSlider.value) + "K"
                                            color: Color.mOnSurface
                                            pointSize: Style.fontSizeS
                                            font.weight: Font.Bold
                                        }
                                    }
                                }

                                NText {
                                    text: Math.round(1000000 / colorTempSlider.value) + "K"
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                    Layout.preferredWidth: Math.round(44 * Style.uiScaleRatio)
                                }
                            }
                        }
                    }
                }
            }

            // Browser view
            BrowserView {
                id: browserView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.view === "browser"
                enabled: root.view === "browser"
                clip: true
                pluginApi: root.pluginApi
                main: root.main
            }
        }
    }

    // Domain helpers

    function isControllable(domain) {
        return ["light", "switch", "input_boolean", "fan", "cover", "lock"].includes(domain);
    }

    function isSensor(domain) {
        return ["sensor", "binary_sensor", "weather", "number"].includes(domain);
    }

    function isAutomation(domain) {
        return ["automation", "script"].includes(domain);
    }

    function isLight(domain) {
        return domain === "light";
    }

    function domainIcon(domain) {
        const icons = {
            "light": "bulb",
            "switch": "toggle-right",
            "input_boolean": "toggle-right",
            "sensor": "chart-line",
            "binary_sensor": "activity",
            "climate": "temperature",
            "cover": "door",
            "fan": "wind",
            "lock": "lock",
            "media_player": "device-speaker",
            "weather": "cloud",
            "automation": "robot",
            "script": "player-play"
        };
        return icons[domain] ?? "smart-home";
    }

    function stateColor(domain, state) {
        if (isControllable(domain))
            return state === "on" ? Color.mTertiary : Color.mOnSurfaceVariant;
        return Color.mTertiary;
    }
}
