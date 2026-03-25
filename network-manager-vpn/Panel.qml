import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    readonly property var main: pluginApi && pluginApi.mainInstance ? pluginApi.mainInstance : null
    readonly property var vpnList: main ? main.vpnList : []
    readonly property var activeList: vpnList.filter(v => v.connected || v.isLoading)
    readonly property var inactiveList: vpnList.filter(v => !v.connected && !v.isLoading)
    property real contentPreferredWidth: Math.round(500 * Style.uiScaleRatio)
    property real contentPreferredHeight: Math.min(500, mainColumn.implicitHeight + Style.marginL * 2)

    function t(key: string, data) : string {
        if (!pluginApi)
            return "";

        return pluginApi.tr(key, data);
    }

    Component.onCompleted: {
        if (main) main.refresh()
    }

    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        // HEADER
        NBox {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(header.implicitHeight + Style.marginM * 2 + 1)

            ColumnLayout {
                id: header
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                RowLayout {
                    NIcon {
                        icon: "shield"
                        pointSize: Style.fontSizeXXL
                        color: Color.mPrimary
                    }

                    NLabel {
                        label: t("common.vpn")
                    }

                    NBox {
                        Layout.fillWidth: true
                    }

                    NIconButton {
                        icon: "refresh"
                        tooltipText: t("common.refresh")
                        baseSize: Style.baseWidgetSize * 0.8
                        enabled: true
                        onClicked: {
                            if (main) {
                                main.refresh()
                            }
                        }
                    }

                    NIconButton {
                        icon: "close"
                        tooltipText: t("common.close")
                        baseSize: Style.baseWidgetSize * 0.8
                        onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                    }
                }
            }
        }

        NScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalPolicy: ScrollBar.AlwaysOff
            verticalPolicy: ScrollBar.AsNeeded
            reserveScrollbarSpace: false

            ColumnLayout {
                anchors.fill: parent
                spacing: Style.marginM
                
                // CONNECTED
                NBox {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(networksListActive.implicitHeight + Style.marginXL)
                    visible: activeList.length > 0

                    ColumnLayout {
                        id: networksListActive
                        anchors.fill: parent
                        anchors.margins: Style.marginM
                        spacing: Style.marginM

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Style.marginS
                            spacing: Style.marginS

                            NLabel {
                                label: t("common.connected")
                                Layout.fillWidth: true
                            }
                        }

                        Repeater {
                            model: activeList

                            VpnListItem {
                                name: modelData.name
                                type: modelData.type
                                isConnected: true
                                isLoading: modelData.isLoading
                                onButtonClicked: {
                                    if (!main) return
                                    main.disconnectFrom(modelData.uuid)
                                }
                            }
                        }
                    }
                }

                // DISCONNECTED
                NBox {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(networksListInactive.implicitHeight + Style.marginXL)
                    visible: inactiveList.length > 0

                    ColumnLayout {
                        id: networksListInactive
                        anchors.fill: parent
                        anchors.margins: Style.marginM
                        spacing: Style.marginM

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Style.marginS
                            spacing: Style.marginS

                            NLabel {
                                label: t("common.disconnected")
                                Layout.fillWidth: true
                            }
                        }

                        Repeater {
                            model: inactiveList

                            VpnListItem {
                                name: modelData.name
                                type: modelData.type
                                isConnected: false
                                isLoading: modelData.isLoading
                                onButtonClicked: {
                                    if (!main) return
                                    main.connectTo(modelData.uuid)
                                }
                            }
                        }
                    }
                }

                // EMPTY
                NBox {
                    id: emptyBox
                    visible: vpnList.length < 1
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(emptyColumn.implicitHeight + Style.marginM * 2 + 1)

                    ColumnLayout {
                        id: emptyColumn
                        anchors.fill: parent
                        anchors.margins: Style.marginM
                        spacing: Style.marginL

                        Item {
                            Layout.fillHeight: true
                        }

                        NIcon {
                            icon: "search"
                            pointSize: 48
                            color: Color.mOnSurfaceVariant
                            Layout.alignment: Qt.AlignHCenter
                        }

                        NText {
                            text: t("panel.emptyTitle")
                            pointSize: Style.fontSizeL
                            color: Color.mOnSurfaceVariant
                            Layout.alignment: Qt.AlignHCenter
                        }

                        NText {
                            text: t("panel.emptyDescription")
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                            Layout.alignment: Qt.AlignHCenter
                        }

                        NButton {
                            text: t("common.refresh")
                            icon: "refresh"
                            Layout.alignment: Qt.AlignHCenter
                            onClicked: { 
                                if (main) {
                                    main.refresh()
                                } 
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }
}
