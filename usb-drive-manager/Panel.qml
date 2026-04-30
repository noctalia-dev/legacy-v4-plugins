import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    property real contentPreferredHeight: 460 * Style.uiScaleRatio
    readonly property bool allowAttach: true
    anchors.fill: parent

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var devices: mainInstance?.devices ?? []
    readonly property int mountedCount: mainInstance?.mountedCount ?? 0
    readonly property string panelIconName: mainInstance?.iconName || pluginApi?.pluginSettings?.iconName || pluginApi?.manifest?.metadata?.defaultSettings?.iconName || "usb"

    Component.onCompleted: {
        mainInstance?.refreshDevices()
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n " + JSON.stringify(text) + " | wl-copy"])
        ToastService.showNotice(
            pluginApi?.tr("notifications.path-copied"),
            text
        )
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginL

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    // Header
                    RowLayout {
                        spacing: Style.marginM

                        NIcon {
                            icon: panelIconName
                            pointSize: Style.fontSizeXL
                        }

                        NText {
                            text: pluginApi?.tr("panel.title")
                            font.pointSize: Style.fontSizeL
                            font.weight: Font.Medium
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        Item { Layout.fillWidth: true }

                        NIconButton {
                            icon: "refresh"
                            baseSize: Style.baseWidgetSize * 0.8
                            tooltipText: pluginApi?.tr("panel.refresh")
                            onClicked: mainInstance?.refreshDevices()

                            RotationAnimation on rotation {
                                running: mainInstance?.loading ?? false
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }
                    }

                    // Device list
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Style.marginS

                        // Empty state
                        Item {
                            visible: devices.length === 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Style.marginS

                                NIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    icon: panelIconName
                                    pointSize: Style.fontSizeXXL
                                    color: Color.mOnSurfaceVariant
                                    opacity: 0.4
                                }

                                NText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: pluginApi?.tr("panel.empty")
                                    pointSize: Style.fontSizeM
                                    color: Color.mOnSurfaceVariant
                                }

                                NText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: pluginApi?.tr("panel.empty-hint")
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurfaceVariant
                                    opacity: 0.7
                                }
                            }
                        }

                        // Device cards
                        ListView {
                            visible: devices.length > 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: devices
                            spacing: Style.marginS
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: DeviceCard {
                                width: ListView.view.width
                                device: modelData
                                pluginApi: root.pluginApi
                                mainInstance: root.mainInstance

                                onMountRequested: (path, label) => mainInstance?.mountDevice(path, label)
                                onUnmountRequested: (path, label) => mainInstance?.unmountDevice(path, label)
                                onEjectRequested: (path, parentPath, label) => mainInstance?.ejectDevice(path, parentPath, label)
                                onOpenRequested: mountpoint => mainInstance?.openInFileBrowser(mountpoint)
                                onCopyPathRequested: mountpoint => root.copyToClipboard(mountpoint)
                            }
                        }
                    }

                    // Footer
                    ColumnLayout {
                        visible: devices.length > 0
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        Rectangle {
                            height: Math.max(1, Style.marginXXS)
                            color: Color.mOutline
                            opacity: 0.3
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginS

                            NButton {
                                Layout.fillWidth: true
                                text: pluginApi?.tr("panel.unmount-all")
                                icon: "plug-connected-x"
                                enabled: mountedCount > 0
                                onClicked: mainInstance?.unmountAll()
                            }

                            NButton {
                                Layout.fillWidth: true
                                text: pluginApi?.tr("panel.eject-all")
                                icon: "player-eject"
                                enabled: devices.length > 0
                                onClicked: mainInstance?.ejectAll()
                            }
                        }
                    }
                }
            }
        }
    }
}
