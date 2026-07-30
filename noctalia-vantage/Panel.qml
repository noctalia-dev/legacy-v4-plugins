import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "./ui"
import "./services"

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: mainLayout
    readonly property bool allowAttach: true

    property real contentPreferredWidth: Math.round(540 * Style.uiScaleRatio)
    property real contentPreferredHeight: Math.round((mainLayout.implicitHeight + 2 * Style.marginL) * Style.uiScaleRatio )

    property int fanModeIndex: fanModeToIndex(vantage.fan.value)

    // ===== MODES =====
    property var fanModesUI: [
        {
            key: 0,
            label: pluginApi?.tr("panel.fan.mode.super_silent"),
            icon: "leaf"
        },
        {
            key: 1,
            label: pluginApi?.tr("panel.fan.mode.standard"),
            icon: "balance"
        },
        {
            key: 4,
            label: pluginApi?.tr("panel.fan.mode.efficient_thermal_dissipation"),
            icon: "bolt"
        }
    ]

    function fanModeToIndex(mode) {
        for (let i = 0; i < fanModesUI.length; i++) {
            if (fanModesUI[i].key === mode)
                return i;
        }
        return 1;
    }

    function indexToFanMode(index) {
        return fanModesUI[index].key;
    }

    function indexToLabel(index) {
        return fanModesUI[index].label;
    }

    anchors.fill: parent

    VantageService {
        id: vantage
        pluginApi: root.pluginApi
    }

    Component.onCompleted: {
        if (pluginApi) {
            vantage.refresh();
            Logger.i("NoctaliaVantage", "Panel initialized");
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NBox {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + Style.margin2M

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                NIcon {
                    pointSize: Style.fontSizeXXL
                    icon: "letter-v"
                }

                ColumnLayout {
                    spacing: Style.marginXXS
                    Layout.fillWidth: true

                    NText {
                        text: pluginApi?.tr("widget.title")
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                NIconButton {
                    icon: "close"
                    tooltipText: pluginApi?.tr("panel.close")
                    baseSize: Style.baseWidgetSize * 0.8
                    onClicked: root.pluginApi.closePanel(root.pluginApi.panelOpenScreen)
                }
            }
        }

        NBox {
            Layout.fillWidth: true
            Layout.preferredHeight: controlsLayout.implicitHeight + Style.margin2L

            ColumnLayout {
                id: controlsLayout
                anchors.fill: parent
                anchors.margins: Style.marginL
                spacing: Style.marginM

                ColumnLayout {
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NText {
                            text: pluginApi?.tr("panel.fan.title")
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            text: root.indexToLabel(root.fanModeIndex)
                            color: Color.mOnSurfaceVariant
                        }
                    }

                    NValueSlider {
                        Layout.fillWidth: true
                        from: 0
                        to: 2
                        stepSize: 1
                        snapAlways: true
                        heightRatio: 0.5
                        value: root.fanModeToIndex(vantage.fan.value)

                        onMoved: v => {
                            root.fanModeIndex = v;
                        }

                        onPressedChanged: pressed => {
                            if (!pressed) {
                                vantage.fan.set(root.indexToFanMode(root.fanModeIndex));
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NIcon {
                            icon: "moon"
                            pointSize: Style.fontSizeS
                            color: root.fanModeIndex === 0 ? Color.mPrimary : Color.mOnSurfaceVariant
                        }

                        NIcon {
                            icon: "car-fan"
                            pointSize: Style.fontSizeS
                            color: root.fanModeIndex === 1 ? Color.mPrimary : Color.mOnSurfaceVariant
                            Layout.fillWidth: true
                        }

                        NIcon {
                            icon: "flame"
                            pointSize: Style.fontSizeS
                            color: root.fanModeIndex === 2 ? Color.mPrimary : Color.mOnSurfaceVariant
                        }
                    }
                }

                NDivider {
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                        text: pluginApi?.tr("panel.fan.mode.dust_cleaning")
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NIconButton {
                        icon: "windmill"
                        onClicked: vantage.fan.set(vantage.fanModes.DustCleaning)
                    }
                }
            }
        }

        NBox {
            Layout.fillWidth: true
            Layout.preferredHeight: list.contentHeight 

            NListView {
                id: list

                anchors {
                    fill: parent
                    leftMargin: Style.marginL
                }
                spacing: Style.marginS

                model: [
                    {
                        visible: vantage.fnLock.available,
                        baseIcon: "keyboard",
                        title: pluginApi?.tr("panel.toggle.fn_lock.title"),
                        description: pluginApi?.tr("panel.toggle.fn_lock.description"),
                        tooltip: pluginApi?.tr("panel.toggle.fn_lock.tooltip"),
                        checked: vantage.fnLock.value,
                        onToggled: checked => vantage.fnLock.set(checked)
                    },
                    {
                        visible: vantage.superKey.available,
                        baseIcon: "brand-windows",
                        title: pluginApi?.tr("panel.toggle.super_key.title"),
                        description: pluginApi?.tr("panel.toggle.super_key.description"),
                        tooltip: pluginApi?.tr("panel.toggle.super_key.tooltip"),
                        checked: vantage.superKey.value,
                        onToggled: checked => vantage.superKey.set(checked)
                    },
                    {
                        visible: vantage.touchpad.available,
                        baseIcon: "device-laptop",
                        title: pluginApi?.tr("panel.toggle.touchpad.title"),
                        description: pluginApi?.tr("panel.toggle.touchpad.description"),
                        tooltip: pluginApi?.tr("panel.toggle.touchpad.tooltip"),
                        checked: vantage.touchpad.value,
                        onToggled: checked => vantage.touchpad.set(checked)
                    },
                    {
                        visible: vantage.conservation.available,
                        baseIcon: "battery-charging",
                        checkedIcon: "battery-eco",
                        title: pluginApi?.tr("panel.toggle.conservation.title"),
                        description: pluginApi?.tr("panel.toggle.conservation.description"),
                        tooltip: pluginApi?.tr("panel.toggle.conservation.tooltip"),
                        checked: vantage.conservation.value,
                        onToggled: checked => vantage.conservation.set(checked)
                    },
                    {
                        visible: vantage.fastCharge.available,
                        baseIcon: "battery-charging",
                        title: pluginApi?.tr("panel.toggle.fast_charge.title"),
                        description: pluginApi?.tr("panel.toggle.fast_charge.description"),
                        tooltip: pluginApi?.tr("panel.toggle.fast_charge.tooltip"),
                        checked: vantage.fastCharge.value,
                        onToggled: checked => vantage.fastCharge.set(checked)
                    },
                    {
                        visible: vantage.alwaysOnUSB.available,
                        baseIcon: "device-usb",
                        title: pluginApi?.tr("panel.toggle.always_on_usb.title"),
                        description: pluginApi?.tr("panel.toggle.always_on_usb.description"),
                        tooltip: pluginApi?.tr("panel.toggle.always_on_usb.tooltip"),
                        checked: vantage.alwaysOnUSB.value,
                        onToggled: checked => vantage.alwaysOnUSB.set(checked)
                    },
                    {
                        visible: vantage.overdrive.available,
                        baseIcon: "bolt",
                        title: pluginApi?.tr("panel.toggle.overdrive.title"),
                        description: pluginApi?.tr("panel.toggle.overdrive.description"),
                        tooltip: pluginApi?.tr("panel.toggle.overdrive.tooltip"),
                        checked: vantage.overdrive.value,
                        onToggled: checked => vantage.overdrive.set(checked)
                    },
                    {
                        visible: vantage.hybrid.available,
                        baseIcon: "cpu",
                        title: pluginApi?.tr("panel.toggle.hybrid.title"),
                        description: pluginApi?.tr("panel.toggle.hybrid.description"),
                        tooltip: pluginApi?.tr("panel.toggle.hybrid.tooltip"),
                        checked: vantage.hybrid.value,
                        onToggled: checked => vantage.hybrid.set(checked)
                    }
                ].filter(item => item.visible)

                delegate: SettingsRow {
                    required property var modelData
                    baseIcon: modelData.baseIcon
                    checkedIcon: modelData.checkedIcon ?? ""
                    title: modelData.title
                    description: modelData.description
                    tooltip: modelData.tooltip
                    checked: modelData.checked
                    onToggled: checked => modelData.onToggled(checked)
                }
            }
        }
    }
}
