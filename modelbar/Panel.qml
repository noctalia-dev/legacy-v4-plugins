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
    readonly property bool allowAttach: true
    readonly property var providers: mainInstance?.providers ?? []
    property int selectedTabIndex: 0
    property var selectedProvider: {
        const list = root.providers ?? [];
        if (list.length === 0)
            return null;
        return list[Math.min(root.selectedTabIndex, list.length - 1)];
    }
    property real contentPreferredWidth: 430 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.ceil(mainColumn.implicitHeight + Style.margin2L)

    anchors.fill: parent

    onProvidersChanged: {
        if (root.selectedTabIndex >= root.providers.length)
            root.selectedTabIndex = Math.max(0, root.providers.length - 1);
    }

    function usageRows(provider) {
        const usage = provider?.usage ?? {};
        const rows = [];

        if (usage.primary)
            rows.push(usage.primary);
        if (usage.secondary)
            rows.push(usage.secondary);
        if (usage.tertiary)
            rows.push(usage.tertiary);

        const extra = usage.extraRateWindows ?? [];
        for (let i = 0; i < extra.length; i++) {
            if (extra[i])
                rows.push(extra[i]);
        }

        const credits = provider?.credits ?? {};
        const limit = Number(credits.limit ?? -1);
        const used = Number(credits.used ?? -1);
        if (limit > 0 && used >= 0) {
            const usedPercent = Math.max(0, Math.min(100, used / limit * 100));
            const usedText = mainInstance ? mainInstance.formatCurrency(used, credits.currency ?? "") : String(used.toFixed(2));
            const limitText = mainInstance ? mainInstance.formatCurrency(limit, credits.currency ?? "") : String(limit.toFixed(2));
            const period = credits.period ?? "Monthly cap";
            rows.push({
                label: "Extra usage",
                usedPercent: usedPercent,
                remainingPercent: Math.max(0, Math.min(100, 100 - usedPercent)),
                detail: period + ": " + usedText + " / " + limitText
            });
        }

        return rows;
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: mainColumn
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            Item {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight

                RowLayout {
                    id: headerRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.marginM

                    NIcon {
                        icon: "ai"
                        pointSize: Style.fontSizeXL
                        color: Color.mPrimary
                    }

                    ColumnLayout {
                        spacing: Style.marginXS
                        Layout.alignment: Qt.AlignVCenter

                        NText {
                            text: "ModelBar"
                            pointSize: Style.fontSizeXL
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                        }

                        NText {
                            visible: (mainInstance?.errorText ?? "") !== ""
                            text: mainInstance?.errorText ?? ""
                            pointSize: Style.fontSizeS
                            color: Color.mError
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: Style.marginS
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        Item {
                            Layout.preferredWidth: Style.baseWidgetSize * 0.65
                            Layout.preferredHeight: Style.baseWidgetSize * 0.65
                            Layout.alignment: Qt.AlignVCenter

                            NIcon {
                                anchors.centerIn: parent
                                icon: "refresh"
                                pointSize: Style.fontSizeM
                                color: Color.mPrimary
                                opacity: mainInstance?.busy ? 1 : 0

                                RotationAnimation on rotation {
                                    running: mainInstance?.busy ?? false
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                }
                            }
                        }

                        NButton {
                            text: "Refresh"
                            fontSize: Style.fontSizeS
                            buttonRadius: Style.radiusXS
                            enabled: !(mainInstance?.busy ?? false)
                            onClicked: mainInstance?.refresh()
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Style.marginM

                NTabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    visible: root.providers.length > 1
                    currentIndex: root.selectedTabIndex
                    distributeEvenly: true
                    margins: Style.marginS
                    onCurrentIndexChanged: root.selectedTabIndex = currentIndex

                    Repeater {
                        model: root.providers

                        NTabButton {
                            readonly property var provider: modelData

                            text: provider?.providerLabel ?? "Provider"
                            tabIndex: index
                            checked: tabBar.currentIndex === index
                            pointSize: Style.fontSizeS
                        }
                    }
                }

                ColumnLayout {
                    id: contentColumn
                    Layout.fillWidth: true
                    spacing: Style.marginL

                    NText {
                        visible: !root.selectedProvider
                        Layout.fillWidth: true
                        text: "No provider data"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: Style.marginXL
                    }

                    RowLayout {
                        visible: !!root.selectedProvider
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NText {
                            text: (root.selectedProvider?.providerLabel ?? "Provider") + " Usage"
                            pointSize: Style.fontSizeXL
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }
                    }

                    NText {
                        visible: !!root.selectedProvider && !(root.selectedProvider?.ok ?? false)
                        Layout.fillWidth: true
                        text: root.selectedProvider?.error ?? "Usage unavailable"
                        pointSize: Style.fontSizeS
                        color: Color.mError
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: root.usageRows(root.selectedProvider)

                        UsageBar {
                            Layout.fillWidth: true
                            row: modelData
                            mainInstance: root.mainInstance
                        }
                    }

                    NText {
                        visible: !!root.selectedProvider && (root.selectedProvider?.ok ?? false) && root.usageRows(root.selectedProvider).length === 0
                        Layout.fillWidth: true
                        text: "No live usage windows returned"
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    component UsageBar: ColumnLayout {
        id: block

        property var row: ({})
        property var mainInstance: null
        readonly property real usedPercent: Math.max(0, Math.min(100, Number(row?.usedPercent ?? 0)))
        readonly property real remainingPercent: Math.max(0, Math.min(100, Number(row?.remainingPercent ?? (100 - usedPercent))))
        readonly property string resetText: mainInstance?.formatReset(row?.resetsAt ?? "") ?? ""

        spacing: Style.marginS

        Rectangle {
            Layout.fillWidth: true
            color: Color.mSurfaceVariant
            radius: Style.radiusS
            implicitHeight: usageColumn.implicitHeight + Style.marginXL

            ColumnLayout {
                id: usageColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Style.marginL
                }
                spacing: Style.marginS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginM

                    NText {
                        text: row?.label ?? "Usage"
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightSemiBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NText {
                        text: Math.round(block.usedPercent) + "%"
                        pointSize: Style.fontSizeS
                        font.weight: Style.fontWeightBold
                        color: block.usedPercent >= 90 ? Color.mError : block.usedPercent >= 70 ? Qt.alpha(Color.mError, 0.72) : Color.mOnSurface
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 9 * Style.uiScaleRatio
                    radius: height / 2
                    color: Qt.alpha(Color.mOnSurfaceVariant, 0.18)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * block.usedPercent / 100
                        radius: parent.radius
                        color: block.usedPercent >= 90 ? Color.mError : block.usedPercent >= 70 ? Qt.alpha(Color.mError, 0.72) : Color.mPrimary

                        Behavior on width {
                            NumberAnimation {
                                duration: Style.animationNormal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                NText {
                    Layout.fillWidth: true
                    text: row?.detail ?? (Math.round(block.remainingPercent) + "% remaining" + (block.resetText !== "" ? ", resets in " + block.resetText : ""))
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
