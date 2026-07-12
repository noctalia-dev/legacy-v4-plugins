import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var mainInstance: pluginApi?.mainInstance

    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 440 * Style.uiScaleRatio
    property real contentPreferredHeight: 520 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    readonly property bool isAvailable: mainInstance?.isAvailable ?? false

    // LED brightness mirror for Repeater bindings
    property string currentBrightness: mainInstance?.ledService?.brightness ?? ""
    // Profile mirror for Repeater bindings
    property string currentProfile: mainInstance?.profileService?.activeProfile ?? ""

    // Tab state
    property int activeTab: 0
    readonly property list<string> tabNames: ["Profile", "LED", "Battery", "Fan", "Aura"]
    readonly property list<string> tabIcons: ["gauge", "lightbulb", "charging-pile", "car-fan", "sparkles"]

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // === Header ===
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                    icon: "laptop"
                    pointSize: Style.fontSizeXXL
                    color: Color.mPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    NText {
                        text: pluginApi?.tr("panel.title") || "ASUS Control"
                        pointSize: Style.fontSizeL
                        font.weight: Font.DemiBold
                        color: Color.mOnSurface
                    }

                    NText {
                        visible: root.isAvailable
                        text: (mainInstance?.asusctlVersion ?? "") + " — " + (mainInstance?.productFamily ?? "")
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }

                    NText {
                        visible: !root.isAvailable
                        text: pluginApi?.tr("panel.not-available") || "asusctl not found. Install asusctl to use this plugin."
                        pointSize: Style.fontSizeXS
                        color: Color.mError
                    }
                }

                NIconButton {
                    icon: "refresh"
                    tooltipText: I18n.tr("tooltips.refresh")
                    baseSize: Style.baseWidgetSize * 0.8
                    enabled: root.isAvailable
                    onClicked: {
                        if (mainInstance) mainInstance.refreshAll();
                    }
                }

                NIconButton {
                    icon: "close"
                    tooltipText: I18n.tr("tooltips.close")
                    baseSize: Style.baseWidgetSize * 0.8
                    onClicked: {
                        pluginApi?.withCurrentScreen(screen => {
                            pluginApi?.closePanel(screen);
                        })
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mOutline
                opacity: 0.3
            }

            // === Tab Bar ===
            Rectangle {
                Layout.fillWidth: true
                height: 36 * Style.uiScaleRatio
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    Repeater {
                        model: root.tabNames.length

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Style.radiusS
                            color: root.activeTab === index ? Color.mPrimary : "transparent"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Style.marginXS

                                NIcon {
                                    icon: root.tabIcons[index]
                                    pointSize: Style.fontSizeS
                                    color: root.activeTab === index ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                }

                                NText {
                                    text: root.tabNames[index]
                                    pointSize: Style.fontSizeS
                                    font.weight: root.activeTab === index ? Font.DemiBold : Font.Normal
                                    color: root.activeTab === index ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = index
                            }
                        }
                    }
                }
            }

            // === Tab Content ===
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurface
                radius: Style.radiusM

                // Profile Tab
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    visible: root.activeTab === 0
                    spacing: Style.marginM

                    // Not available message
                    NText {
                        visible: !root.isAvailable
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.not-available") || "asusctl not found"
                        pointSize: Style.fontSizeM
                        color: Color.mError
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    // Profile buttons
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.isAvailable
                        spacing: Style.marginS

                        NText {
                            text: pluginApi?.tr("panel.profile") || "Power Profile"
                            pointSize: Style.fontSizeM
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            Repeater {
                                model: mainInstance?.profileService?.availableProfiles ?? []

                                Rectangle {
                                    required property string modelData
                                    required property int index

                                    width: profileBtnRow.implicitWidth + Style.marginL * 2
                                    height: 36 * Style.uiScaleRatio
                                    radius: Style.radiusS
                                    color: profileMouse.containsMouse ? Color.mHover :
                                           (modelData === root.currentProfile ? Color.mPrimary : "transparent")
                                    border.color: modelData === root.currentProfile ? Color.mPrimary : Color.mOutline
                                    border.width: Style.borderS

                                    RowLayout {
                                        id: profileBtnRow
                                        anchors.centerIn: parent
                                        spacing: Style.marginXS

                                        NIcon {
                                            icon: modelData.toLowerCase() === "performance" ? "gauge" :
                                                  modelData.toLowerCase() === "quiet" ? "leaf" : "scale"
                                            pointSize: Style.fontSizeM
                                            color: modelData === root.currentProfile ? Color.mOnPrimary : Color.mOnSurface
                                        }

                                        NText {
                                            text: modelData
                                            pointSize: Style.fontSizeS
                                            font.weight: Font.DemiBold
                                            color: modelData === root.currentProfile ? Color.mOnPrimary : Color.mOnSurface
                                        }
                                    }

                                    MouseArea {
                                        id: profileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (mainInstance) mainInstance.profileService.setProfile(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // AC / Battery split
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.isAvailable
                        spacing: Style.marginS

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Color.mOutline
                            opacity: 0.2
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                NText {
                                    text: "AC"
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurfaceVariant
                                    font.weight: Font.DemiBold
                                }

                                NText {
                                    text: mainInstance?.profileService?.acProfile ?? "—"
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurface
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                NText {
                                    text: "Battery"
                                    pointSize: Style.fontSizeXS
                                    color: Color.mOnSurfaceVariant
                                    font.weight: Font.DemiBold
                                }

                                NText {
                                    text: mainInstance?.profileService?.batteryProfile ?? "—"
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurface
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // LED Tab
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    visible: root.activeTab === 1
                    spacing: Style.marginM

                    NText {
                        visible: !root.isAvailable
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.not-available") || "asusctl not found"
                        pointSize: Style.fontSizeM
                        color: Color.mError
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.isAvailable
                        spacing: Style.marginM

                        NText {
                            text: pluginApi?.tr("panel.led") || "Keyboard LED"
                            pointSize: Style.fontSizeM
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        NText {
                            text: (pluginApi?.tr("led.brightness") || "Brightness") + ": " +
                                  (mainInstance?.ledService?.brightness ?? "—")
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            Repeater {
                                model: mainInstance?.ledService?.levels ?? ["off", "low", "med", "high"]

                                Rectangle {
                                    required property string modelData
                                    required property int index

                                    width: ledBtnRow.implicitWidth + Style.marginL * 2
                                    height: 36 * Style.uiScaleRatio
                                    radius: Style.radiusS
                                    color: ledMouse.containsMouse ? Color.mHover :
                                           (modelData === root.currentBrightness ? Color.mPrimary : "transparent")
                                    border.color: modelData === root.currentBrightness ? Color.mPrimary : Color.mOutline
                                    border.width: Style.borderS

                                    RowLayout {
                                        id: ledBtnRow
                                        anchors.centerIn: parent
                                        spacing: Style.marginXS

                                        NIcon {
                                            icon: modelData === "off" ? "lightbulb-off" : "lightbulb"
                                            pointSize: Style.fontSizeM
                                            color: modelData === root.currentBrightness ? Color.mOnPrimary : Color.mOnSurface
                                        }

                                        NText {
                                            text: mainInstance?.ledService?.levelLabels[index] ?? modelData
                                            pointSize: Style.fontSizeS
                                            font.weight: Font.DemiBold
                                            color: modelData === root.currentBrightness ? Color.mOnPrimary : Color.mOnSurface
                                        }
                                    }

                                    MouseArea {
                                        id: ledMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (mainInstance) mainInstance.ledService.setBrightness(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // Battery Tab
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    visible: root.activeTab === 2
                    spacing: Style.marginM

                    NText {
                        visible: !root.isAvailable
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.not-available") || "asusctl not found"
                        pointSize: Style.fontSizeM
                        color: Color.mError
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.isAvailable
                        spacing: Style.marginM

                        NText {
                            text: pluginApi?.tr("panel.battery") || "Battery"
                            pointSize: Style.fontSizeM
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        // Charge limit display + slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginM

                            NText {
                                text: pluginApi?.tr("battery.charge-limit") || "Charge Limit"
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }

                            NText {
                                text: (root.currentLimit >= 0 ? root.currentLimit + "%" : "—")
                                pointSize: Style.fontSizeL
                                font.weight: Font.Bold
                                color: Color.mPrimary
                            }

                            property int currentLimit: mainInstance?.batteryService?.chargeLimit ?? -1
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NText {
                                text: "20%"
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }

                            NSlider {
                                id: batterySlider
                                Layout.fillWidth: true
                                from: 20
                                to: 100
                                stepSize: 1
                                value: mainInstance?.batteryService?.chargeLimit ?? 100
                                onMoved: {
                                    if (mainInstance) mainInstance.batteryService.setLimit(Math.round(value));
                                }
                            }

                            NText {
                                text: "100%"
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Color.mOutline
                            opacity: 0.2
                        }

                        // One-shot charge button
                        NButton {
                            Layout.fillWidth: true
                            text: pluginApi?.tr("battery.oneshot") || "Charge to 100% Once"
                            onClicked: {
                                if (mainInstance) mainInstance.batteryService.triggerOneshot();
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // Fan Tab
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    visible: root.activeTab === 3
                    spacing: Style.marginM

                    NText {
                        visible: !root.isAvailable
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.not-available") || "asusctl not found"
                        pointSize: Style.fontSizeM
                        color: Color.mError
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.isAvailable
                        spacing: Style.marginM

                        RowLayout {
                            Layout.fillWidth: true

                            NText {
                                text: pluginApi?.tr("panel.fan") || "Fan Curves"
                                pointSize: Style.fontSizeM
                                font.weight: Font.DemiBold
                                color: Color.mOnSurface
                                Layout.fillWidth: true
                            }

                            NText {
                                text: mainInstance?.profileService?.activeProfile ?? ""
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                            }
                        }

                        // Dynamic fan list
                        Repeater {
                            model: mainInstance?.fanCurveService?.availableFanTypes ?? []

                            ColumnLayout {
                                required property string modelData
                                required property int index
                                spacing: Style.marginS

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Color.mOutline
                                    opacity: 0.2
                                    visible: index > 0
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.marginM

                                    NText {
                                        text: modelData
                                        pointSize: Style.fontSizeS
                                        font.weight: Font.DemiBold
                                        color: Color.mOnSurface
                                        Layout.preferredWidth: 60
                                    }

                                    NText {
                                        text: {
                                            var states = mainInstance?.fanCurveService?.fanStates ?? {};
                                            var state = states[modelData];
                                            if (!state) return "—";
                                            return state.enabled ? (pluginApi?.tr("fan.enabled") || "Enabled") : (pluginApi?.tr("fan.disabled") || "Disabled");
                                        }
                                        pointSize: Style.fontSizeS
                                        color: Color.mOnSurfaceVariant
                                        Layout.fillWidth: true
                                    }

                                    // Toggle switch
                                    Rectangle {
                                        width: 44
                                        height: 24
                                        radius: 12
                                        color: fanToggle.active ? Color.mPrimary : Color.mSurfaceVariant

                                        Rectangle {
                                            x: fanToggle.active ? 22 : 2
                                            y: 2
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: fanToggle.active ? Color.mOnPrimary : Color.mOutline

                                            Behavior on x {
                                                NumberAnimation { duration: 150 }
                                            }
                                        }

                                        property bool active: {
                                            var states = mainInstance?.fanCurveService?.fanStates ?? {};
                                            var state = states[modelData];
                                            return state ? state.enabled : false;
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var states = mainInstance?.fanCurveService?.fanStates ?? {};
                                                var state = states[modelData];
                                                var newEnabled = state ? !state.enabled : true;
                                                var profile = mainInstance?.profileService?.activeProfile || "Balanced";
                                                if (mainInstance) mainInstance.fanCurveService.setFanEnabled(profile, modelData, newEnabled);
                                            }
                                        }
                                    }
                                }

                                // Show curve data points
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: {
                                            var states = mainInstance?.fanCurveService?.fanStates ?? {};
                                            var state = states[modelData];
                                            return state ? state.data : [];
                                        }

                                        Rectangle {
                                            required property var modelData
                                            width: pointLabel.implicitWidth + Style.marginS * 2
                                            height: 20
                                            radius: Style.radiusXS
                                            color: Color.mSurfaceVariant

                                            NText {
                                                id: pointLabel
                                                anchors.centerIn: parent
                                                text: modelData.temp + "c:" + modelData.pwm + "%"
                                                pointSize: Style.fontSizeXS
                                                color: Color.mOnSurfaceVariant
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Reset to default
                        NButton {
                            Layout.fillWidth: true
                            visible: (mainInstance?.fanCurveService?.availableFanTypes?.length ?? 0) > 0
                            text: pluginApi?.tr("fan.reset-default") || "Reset to Default"
                            onClicked: {
                                var profile = mainInstance?.profileService?.activeProfile || "Balanced";
                                if (mainInstance) mainInstance.fanCurveService.resetToDefault(profile);
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // Aura Tab
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    visible: root.activeTab === 4
                    spacing: Style.marginM

                    NText {
                        visible: !root.isAvailable
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.not-available") || "asusctl not found"
                        pointSize: Style.fontSizeM
                        color: Color.mError
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.isAvailable
                        spacing: Style.marginM

                        NText {
                            text: pluginApi?.tr("panel.aura") || "Aura Lighting"
                            pointSize: Style.fontSizeM
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        // Effect mode cycling
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NText {
                                text: "Effect"
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                Layout.fillWidth: true
                            }

                            NIconButton {
                                icon: "arrow-left"
                                baseSize: Style.baseWidgetSize * 0.7
                                onClicked: {
                                    if (mainInstance) mainInstance.auraService.prevEffect();
                                }
                            }

                            NIconButton {
                                icon: "arrow-right"
                                baseSize: Style.baseWidgetSize * 0.7
                                onClicked: {
                                    if (mainInstance) mainInstance.auraService.nextEffect();
                                }
                            }
                        }

                        // Static color input
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NText {
                                text: "Static color"
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                Layout.fillWidth: true
                            }

                            NTextInput {
                                id: colorInput
                                Layout.preferredWidth: 120
                                placeholderText: "ff00ff"
                                text: ""
                            }

                            NButton {
                                text: "Set"
                                onClicked: {
                                    if (mainInstance && colorInput.text.length > 0) {
                                        mainInstance.auraService.setEffect("static", colorInput.text, "");
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Color.mOutline
                            opacity: 0.2
                        }

                        // Dynamic zone power controls
                        NText {
                            text: "Zones"
                            pointSize: Style.fontSizeS
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        NText {
                            visible: (mainInstance?.auraService?.availableZones?.length ?? 0) === 0
                            text: "No aura zones detected"
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurfaceVariant
                        }

                        Repeater {
                            model: mainInstance?.auraService?.availableZones ?? []

                            ColumnLayout {
                                required property string modelData
                                required property int index
                                spacing: 4

                                NText {
                                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                    pointSize: Style.fontSizeS
                                    font.weight: Font.DemiBold
                                    color: Color.mOnSurface
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Style.marginXS

                                    Repeater {
                                        model: ["awake", "sleep", "boot", "shutdown"]

                                        Rectangle {
                                            required property string modelData
                                            required property int index

                                            property string zoneName: modelData
                                            property bool isAwake: index === 0
                                            property bool isSleep: index === 1
                                            property bool isBoot: index === 2
                                            property bool isShutdown: index === 3

                                            width: zoneChip.implicitWidth + Style.marginM * 2
                                            height: 28
                                            radius: Style.radiusS
                                            color: zoneChipMouse.containsMouse ? Color.mHover :
                                                   (zoneState ? Color.mPrimary : "transparent")
                                            border.color: zoneState ? Color.mPrimary : Color.mOutline
                                            border.width: Style.borderS

                                            property bool zoneState: {
                                                var states = mainInstance?.auraService?.zoneStates ?? {};
                                                var zs = states[zoneName];
                                                if (!zs) return false;
                                                if (isAwake) return zs.awake;
                                                if (isSleep) return zs.sleep;
                                                if (isBoot) return zs.boot;
                                                if (isShutdown) return zs.shutdown;
                                                return false;
                                            }

                                            RowLayout {
                                                id: zoneChip
                                                anchors.centerIn: parent
                                                spacing: 4

                                                NIcon {
                                                    icon: isAwake ? "sun" : isSleep ? "moon" : isBoot ? "power" : "power-off"
                                                    pointSize: Style.fontSizeXS
                                                    color: zoneChip.parent.zoneState ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                                }

                                                NText {
                                                    text: modelData
                                                    pointSize: Style.fontSizeXS
                                                    color: zoneChip.parent.zoneState ? Color.mOnPrimary : Color.mOnSurfaceVariant
                                                }
                                            }

                                            MouseArea {
                                                id: zoneChipMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var states = mainInstance?.auraService?.zoneStates ?? {};
                                                    var zs = states[zoneName] || { boot: false, awake: false, sleep: false, shutdown: false };
                                                    var newZs = {
                                                        boot: zs.boot,
                                                        awake: zs.awake,
                                                        sleep: zs.sleep,
                                                        shutdown: zs.shutdown
                                                    };
                                                    if (isAwake) newZs.awake = !newZs.awake;
                                                    else if (isSleep) newZs.sleep = !newZs.sleep;
                                                    else if (isBoot) newZs.boot = !newZs.boot;
                                                    else if (isShutdown) newZs.shutdown = !newZs.shutdown;
                                                    if (mainInstance) mainInstance.auraService.setZonePower(zoneName, newZs.boot, newZs.awake, newZs.sleep, newZs.shutdown);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
