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

    property string currentBrightness: mainInstance?.ledBrightness ?? ""
    property string currentProfile: mainInstance?.activeProfile ?? ""

    property int activeTab: 0
    readonly property list<string> tabNames: ["Profile", "LED", "Battery", "Fan"]
    readonly property list<string> tabIcons: ["gauge", "lightbulb", "charging-pile", "car-fan"]

    // Aura color picker state
    property string auraStaticColor: "#ff00ff"
    property bool syncAura: pluginApi?.pluginSettings?.syncAuraColor ?? false

    readonly property var auraSchemeColors: [
        { "hex": "#ff0000", "label": "R" },
        { "hex": "#ff4400", "label": "O" },
        { "hex": "#ffff00", "label": "Y" },
        { "hex": "#00ff00", "label": "G" },
        { "hex": "#00ffff", "label": "C" },
        { "hex": "#0000ff", "label": "B" },
        { "hex": "#8800ff", "label": "I" },
        { "hex": "#ff00ff", "label": "M" },
        { "hex": "#ffffff", "label": "W" },
        { "hex": "#ff8844", "label": "A" },
        { "hex": "#44ff88", "label": "L" },
        { "hex": "#4488ff", "label": "S" }
    ]

    function auraApplyStatic() {
        if (mainInstance && root.auraStaticColor.length > 0) {
            mainInstance._auraSetEffect("static", root.auraStaticColor, "");
        }
    }

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

                Item { Layout.fillWidth: true }

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
                                model: mainInstance?.availableProfiles ?? []

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
                                            if (mainInstance) mainInstance._setProfile(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }

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
                                    text: mainInstance?.acProfile ?? "—"
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
                                    text: mainInstance?.batteryProfile ?? "—"
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurface
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // LED Tab
                Flickable {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    visible: root.activeTab === 1
                    contentHeight: ledContent.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: ledContent
                        width: parent.width
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

                        NText {
                            text: pluginApi?.tr("panel.led") || "Keyboard LED"
                            pointSize: Style.fontSizeM
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        NText {
                            text: (pluginApi?.tr("led.brightness") || "Brightness") + ": " +
                                  (mainInstance?.ledBrightness ?? "—")
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            Repeater {
                                model: mainInstance?.ledLevels ?? ["off", "low", "med", "high"]

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
                                            text: mainInstance?.ledLevelLabels[index] ?? modelData
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
                                            if (mainInstance) mainInstance._setLedBrightness(modelData);
                                        }
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

                        // Aura controls
                        NText {
                            text: pluginApi?.tr("panel.aura") || "Aura Lighting"
                            pointSize: Style.fontSizeM
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        NText {
                            visible: root.syncAura
                            text: pluginApi?.tr("aura.sync-active") || "Color is synced to Noctalia theme"
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurfaceVariant
                        }

                        // Effect mode cycling
                        RowLayout {
                            Layout.fillWidth: true
                            enabled: !root.syncAura
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
                                    if (mainInstance) mainInstance._auraPrevEffect();
                                }
                            }

                            NIconButton {
                                icon: "arrow-right"
                                baseSize: Style.baseWidgetSize * 0.7
                                onClicked: {
                                    if (mainInstance) mainInstance._auraNextEffect();
                                }
                            }
                        }

                        // Static color picker
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NText {
                                text: pluginApi?.tr("aura.static-color") || "Static color"
                                pointSize: Style.fontSizeS
                                font.weight: Font.DemiBold
                                color: Color.mOnSurface
                            }

                            NColorPicker {
                                Layout.fillWidth: true
                                enabled: !root.syncAura
                                selectedColor: root.auraStaticColor
                                onColorSelected: function(color) {
                                    root.auraStaticColor = color;
                                    root.auraApplyStatic();
                                }
                            }

                            NText {
                                text: pluginApi?.tr("aura.scheme-colors") || "Quick colors"
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }

                            Flow {
                                Layout.fillWidth: true
                                enabled: !root.syncAura
                                spacing: Style.marginXS

                                Repeater {
                                    model: root.auraSchemeColors

                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: 28
                                        height: 28
                                        radius: Style.radiusS
                                        color: modelData.hex
                                        border.color: root.auraStaticColor === modelData.hex ? Color.mOnSurface : Color.mOutline
                                        border.width: root.auraStaticColor === modelData.hex ? 2 : 1

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.auraStaticColor = modelData.hex;
                                                root.auraApplyStatic();
                                            }
                                        }
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

                        // Zone power controls
                        NText {
                            text: "Zones"
                            pointSize: Style.fontSizeS
                            font.weight: Font.DemiBold
                            color: Color.mOnSurface
                        }

                        NText {
                            visible: (mainInstance?.auraAvailableZones?.length ?? 0) === 0
                            text: "No aura zones detected"
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurfaceVariant
                        }

                        Repeater {
                            model: mainInstance?.auraAvailableZones ?? []

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
                                                var states = mainInstance?.auraZoneStates ?? {};
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
                                                    var states = mainInstance?.auraZoneStates ?? {};
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
                                                    if (mainInstance) mainInstance._auraSetZonePower(zoneName, newZs.boot, newZs.awake, newZs.sleep, newZs.shutdown);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                                text: (mainInstance?.chargeLimit >= 0 ? mainInstance.chargeLimit + "%" : "—")
                                pointSize: Style.fontSizeL
                                font.weight: Font.Bold
                                color: Color.mPrimary
                            }
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
                                Layout.fillWidth: true
                                from: 20
                                to: 100
                                stepSize: 1
                                value: mainInstance?.chargeLimit ?? 100
                                onMoved: {
                                    if (mainInstance) mainInstance._setBatteryLimit(Math.round(value));
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

                        NButton {
                            Layout.fillWidth: true
                            text: pluginApi?.tr("battery.oneshot") || "Charge to 100% Once"
                            onClicked: {
                                if (mainInstance) mainInstance._triggerOneshot();
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
                                text: mainInstance?.activeProfile ?? ""
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                            }
                        }

                        Repeater {
                            model: mainInstance?.availableFanTypes ?? []

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
                                            var states = mainInstance?.fanStates ?? {};
                                            var state = states[modelData];
                                            if (!state) return "—";
                                            return state.enabled ? (pluginApi?.tr("fan.enabled") || "Enabled") : (pluginApi?.tr("fan.disabled") || "Disabled");
                                        }
                                        pointSize: Style.fontSizeS
                                        color: Color.mOnSurfaceVariant
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        id: fanToggle
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
                                            var states = mainInstance?.fanStates ?? {};
                                            var state = states[modelData];
                                            return state ? state.enabled : false;
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var states = mainInstance?.fanStates ?? {};
                                                var state = states[modelData];
                                                var newEnabled = state ? !state.enabled : true;
                                                var profile = mainInstance?.activeProfile || "Balanced";
                                                if (mainInstance) mainInstance._setFanEnabled(profile, modelData, newEnabled);
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: {
                                            var states = mainInstance?.fanStates ?? {};
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

                        NButton {
                            Layout.fillWidth: true
                            visible: (mainInstance?.availableFanTypes?.length ?? 0) > 0
                            text: pluginApi?.tr("fan.reset-default") || "Reset to Default"
                            onClicked: {
                                var profile = mainInstance?.activeProfile || "Balanced";
                                if (mainInstance) mainInstance._resetFanToDefault(profile);
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

            }
        }
    }
}
