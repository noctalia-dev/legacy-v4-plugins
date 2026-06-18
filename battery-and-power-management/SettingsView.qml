import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null

    property bool editColorizeByProfile:
        pluginApi?.pluginSettings?.colorizeByProfile ??
        pluginApi?.manifest?.metadata?.defaultSettings?.colorizeByProfile ??
        true

    property string editColorPowerSaver:
        pluginApi?.pluginSettings?.colorPowerSaver ??
        pluginApi?.manifest?.metadata?.defaultSettings?.colorPowerSaver ??
        Color.mSecondary

    property string editColorPerformance:
        pluginApi?.pluginSettings?.colorPerformance ??
        pluginApi?.manifest?.metadata?.defaultSettings?.colorPerformance ??
        Color.mError

    property bool editShowProfile:
        pluginApi?.pluginSettings?.showProfile  ??
        pluginApi?.manifest?.metadata?.defaultSettings?.showProfile ??
        true

    property bool editShowBalancedIcon:
        pluginApi?.pluginSettings?.showBalancedIcon  ??
        pluginApi?.manifest?.metadata?.defaultSettings?.showBalancedIcon ??
        false

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.colorizeByProfile = root.editColorizeByProfile
        pluginApi.pluginSettings.colorPowerSaver = root.editColorPowerSaver
        pluginApi.pluginSettings.colorPerformance = root.editColorPerformance
        pluginApi.pluginSettings.showProfile = root.editShowProfile
        pluginApi.pluginSettings.showBalancedIcon = root.editShowBalancedIcon
        pluginApi.saveSettings()
    }

    // All palette colors
    readonly property var noctaliaPalette: [
        Color.mPrimary, Color.mSecondary, Color.mTertiary, Color.mError,
        Color.mSurface, Color.mSurfaceVariant, Color.mOutline
    ]

    Component.onCompleted: {
        Logger.d("BatterySettings", "editColorPowerSaver: " + editColorPowerSaver)
        Logger.d("BatterySettings", "editColorPerformance: " + editColorPerformance)
    }

    //Dynamic coloring based on selected profile
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.dynamic-coloring")
        description: pluginApi?.tr("settings.dynamic-coloring-desc")
        checked: root.editColorizeByProfile
        onToggled: checked => {
            root.editColorizeByProfile = checked
            root.saveSettings()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        enabled: root.editColorizeByProfile
        opacity: enabled ? 1.0 : 0.5

        // Power saver color
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
                text: pluginApi?.tr("settings.color-powersaver")
                font.weight: Font.Bold
            }
            NText {
                text: pluginApi?.tr("settings.color-powersaver-desc")
                font.pointSize: Style.fontSizeSmall
                color: Color.mOnSurfaceVariant
            }

            RowLayout {
                spacing: Style.marginS

                Repeater {
                    id: powerSaverColor
                    model: root.noctaliaPalette

                    Rectangle {
                        //width: 28
                        //height: 28
                        radius: Style.radiusL
                        color: modelData
                        border.color: Qt.colorEqual(root.editColorPowerSaver, modelData) ? Color.mOnSurface : Color.mOutline
                        border.width: Qt.colorEqual(root.editColorPowerSaver, modelData) ? 3 : 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Logger.d("BatterySettings", "Power Saver selected: " + modelData)
                                root.editColorPowerSaver = modelData
                                root.saveSettings()
                            }
                        }
                    }
                }
            }
        }

        // Space separator
        Item { Layout.preferredHeight: Style.marginS }

        // Performance color
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
                text: pluginApi?.tr("settings.color-performance")
                font.weight: Font.Bold
            }
            NText {
                text: pluginApi?.tr("settings.color-performance-desc")
                font.pointSize: Style.fontSizeSmall
                color: Color.mOnSurfaceVariant
            }

            RowLayout {
                spacing: Style.marginS

                Repeater {
                    id: performanceColor
                    model: root.noctaliaPalette

                    Rectangle {
                        //width: 28
                        //height: 28
                        radius: Style.radiusL
                        color: modelData
                        border.color: Qt.colorEqual(root.editColorPerformance, modelData) ? Color.mOnSurface : Color.mOutline
                        border.width: Qt.colorEqual(root.editColorPerformance, modelData) ? 3 : 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Logger.d("BatterySettings", "Performance selected: " + modelData)
                                root.editColorPerformance = modelData
                                root.saveSettings()
                            }
                        }
                    }
                }
            }
        }
    }

    //Show profile in widget
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-profile")
        description: pluginApi?.tr("settings.show-profile-desc")
        checked: root.editShowProfile
        onToggled: checked => {
            root.editShowProfile = checked
            root.saveSettings()
        }
    }

    //Show balanced icon
    NToggle {
        enabled: root.editShowProfile
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-balanced")
        description: pluginApi?.tr("settings.show-balanced-desc")
        checked: root.editShowBalancedIcon
        onToggled: checked => {
            Logger.d("BatterySettings", "showBalancedIcon checked: " + checked)
            root.editShowBalancedIcon = checked
            root.saveSettings()
        }
    }

    Item { Layout.fillHeight: true }
}
