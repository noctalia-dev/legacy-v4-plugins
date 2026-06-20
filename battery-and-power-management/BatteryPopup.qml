import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var screen: null
    
    readonly property var mainWidget: pluginApi?.mainInstance || null

    property real contentPreferredWidth: (panelContent.implicitWidth + Style.marginM * 10) * Style.uiScaleRatio
    property real contentPreferredHeight: (mainLayout.implicitHeight + Style.marginM * 4) * Style.uiScaleRatio
    
    readonly property var geometryPlaceholder: mainLayout
    readonly property bool allowAttach: true

    anchors.fill: parent

    Component.onCompleted: {
        if (root.mainWidget && typeof root.mainWidget.updatePowerProfile === "function") {
            root.mainWidget.updatePowerProfile();
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.centerIn: parent
        spacing: Style.marginM

        // --- CAPSULE 1: BATTERY INFO ---
        Rectangle {
            id: batteryCapsule
            Layout.preferredWidth: root.contentPreferredWidth - (Style.marginM * 2)
            Layout.preferredHeight: 64 * Style.uiScaleRatio
            
            color: Color.mSurfaceVariant
            radius: Style.capsuleRadius ?? Style.radiusM
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth

            RowLayout {
                id: panelContent
                anchors.fill: parent
                anchors.margins: Style.marginL
                spacing: Style.marginL

                ColumnLayout {
                    spacing: Style.marginS
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: false
                    Layout.leftMargin: Style.marginS * 2
                    Layout.rightMargin: Style.marginS

                    NIcon {
                        icon: root.mainWidget?.getBatteryIcon()
                        pointSize: Style.fontSizeXL
                        color: Color.mPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    NText {
                        text: root.mainWidget ? root.mainWidget.batPercent + "%" : "0%"
                        font.weight: Font.Bold
                        pointSize: Style.fontSizeM
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    width: 1
                    color: Color.mOutline
                    opacity: 0.15
                }

                ColumnLayout {
                    spacing: Style.marginS
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    NText {
                        text: root.mainWidget ? root.mainWidget.batStatus : pluginApi?.tr("battery.status_unknown")
                        font.weight: Font.Bold
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NText {
                        text: {
                            if (!root.mainWidget) {
                                return "...";
                            }
                            if (root.mainWidget.batStatus === pluginApi?.tr("battery.status_charging")) {
                                return pluginApi?.tr("battery.time_to_full", { time: root.mainWidget.timeRemaining });
                            } else if (root.mainWidget.batStatus === pluginApi?.tr("battery.status_discharging")) {
                                return pluginApi?.tr("battery.remaining", { time: root.mainWidget.timeRemaining });
                            } else {
                                return root.mainWidget.wattNum.toFixed(1) + " W";
                            }
                        }
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        Layout.fillWidth: true
                        elide: Text.ElideNone
                    }
                }
            }
        }

        // --- CAPSULE 2: POWER PROFILE ---
        Rectangle {
            id: profileCapsule
            Layout.preferredWidth: batteryCapsule.Layout.preferredWidth
            Layout.preferredHeight: 52 * Style.uiScaleRatio
            
            color: Color.mSurfaceVariant
            radius: Style.capsuleRadius ?? Style.radiusM
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth

            RowLayout {
                anchors.centerIn: parent
                spacing: Style.marginL * 1.5

                ProfileButton {
                    icon: "leaf"
                    profile: "power-saver"
                    active: root.mainWidget?.currentProfile === "power-saver"
                    onClicked: root.mainWidget?.setPowerProfile("power-saver")
                }

                ProfileButton {
                    icon: "scale"
                    profile: "balanced"
                    active: root.mainWidget?.currentProfile === "balanced"
                    onClicked: root.mainWidget?.setPowerProfile("balanced")
                }

                ProfileButton {
                    icon: "gauge"
                    profile: "performance"
                    active: root.mainWidget?.currentProfile === "performance"
                    onClicked: root.mainWidget?.setPowerProfile("performance")
                }
            }
        }

        // --- CAPSULE 3: BATTERY THRESHOLD ---
        Rectangle {
            id: thresholdCapsule
            Layout.preferredWidth: batteryCapsule.Layout.preferredWidth
            Layout.preferredHeight: 52 * Style.uiScaleRatio
            
            color: Color.mSurfaceVariant
            radius: Style.capsuleRadius ?? Style.radiusM
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginL
                anchors.rightMargin: Style.marginL
                spacing: Style.marginM

                NIcon {
                    icon: "shield-heart"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignVCenter
                }

                NSlider {
                    id: thresholdSlider
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    
                    from: 50
                    to: 100
                    stepSize: 5
                    value: root.mainWidget ? root.mainWidget.batteryThreshold : 80
                    
                    onMoved: root.mainWidget?.setBatteryThreshold(value)
                }

                NText {
                    text: thresholdSlider.value + "%"
                    font.weight: Font.Bold
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    Layout.preferredWidth: 40 * Style.uiScaleRatio
                    horizontalAlignment: Text.AlignRight
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    component ProfileButton: MouseArea {
        property string icon: ""
        property string profile: ""
        property bool active: false
        
        implicitWidth: 36 * Style.uiScaleRatio
        implicitHeight: 36 * Style.uiScaleRatio
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        Rectangle {
            anchors.fill: parent
            radius: Style.radiusS ?? 4
            
            color: parent.active ? Color.mPrimary : Color.mSurface
            opacity: parent.active ? 1.0 : (parent.containsMouse ? 0.8 : 0.0)
        }

        NIcon {
            anchors.centerIn: parent
            icon: parent.icon
            pointSize: Style.fontSizeS
            color: parent.active 
                ? Color.mOnPrimary 
                : (parent.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant)
        }
    }
}