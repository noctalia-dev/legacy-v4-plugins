import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Panel Component
Item {
    id: root

    readonly property bool allowAttach: true
    property real contentPreferredHeight: 600 * Style.uiScaleRatio + Style.marginM
    property real contentPreferredWidth: 440 * Style.uiScaleRatio

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // SmartPanel
    readonly property var geometryPlaceholder: panelContainer

    // Plugin API (injected by PluginPanelSlot)
    property var pluginApi: null
    readonly property var main: pluginApi?.mainInstance
    readonly property string platform: cfg.platform ?? defaults.platform
    readonly property string bin: platform === 'gitlab' ? 'glab' : 'gh'
    readonly property string platformIcon: platform === 'gitlab' ? "brand-gitlab" : "brand-github"

    readonly property bool ready: main && main.isBinInstalled && main.isAuthenticated
    readonly property bool showNoScope: ready && platform === 'gitlab' && !main.hasScope
    readonly property bool showLists: ready && !showNoScope

    anchors.fill: parent

    // Shared list-item delegate (PRs and Issues)
    Component {
        id: itemDelegate

        Rectangle {
            id: itemCard

            width: ListView.view.width
            height: itemContent.implicitHeight + Style.margin2M
            radius: Style.radiusM
            color: itemMouseArea.containsMouse ? Color.mHover : Color.mSurface

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.main?.openUrl(modelData.url)
            }

            ColumnLayout {
                id: itemContent

                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginXXS

                NText {
                    Layout.fillWidth: true
                    text: modelData.title ?? ""
                    elide: Text.ElideRight
                    pointSize: Style.fontSizeM
                    font.weight: Font.Bold
                    color: itemMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                }
                NText {
                    Layout.fillWidth: true
                    text: modelData.ref ?? ""
                    elide: Text.ElideRight
                    pointSize: Style.fontSizeXXS
                    color: itemMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
                }
            }
        }
    }

    Rectangle {
        id: panelContainer

        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginL

            // HEADER (title row + tab row in a single card)
            NBox {
                id: headerBox

                Layout.fillWidth: true
                implicitHeight: headerColumn.implicitHeight + Style.margin2M

                ColumnLayout {
                    id: headerColumn

                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    RowLayout {
                        id: headerRow

                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NIcon {
                            color: Color.mPrimary
                            icon: root.platformIcon
                            pointSize: Style.fontSizeXXL
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginXXS

                            NText {
                                Layout.fillWidth: true
                                color: Color.mOnSurface
                                elide: Text.ElideRight
                                font.weight: Style.fontWeightBold
                                pointSize: Style.fontSizeL
                                text: pluginApi?.tr("panel.title")
                            }
                        }
                        NIconButton {
                            baseSize: Style.baseWidgetSize * 0.8
                            icon: "refresh"
                            tooltipText: pluginApi?.tr("panel.refresh")

                            onClicked: root.main?.refresh()
                        }
                        NIconButton {
                            baseSize: Style.baseWidgetSize * 0.8
                            icon: "settings"
                            tooltipText: I18n.tr("common.settings")

                            onClicked: {
                                var screen = pluginApi?.panelOpenScreen;
                                if (screen && pluginApi?.manifest) {
                                    BarService.openPluginSettings(screen, pluginApi.manifest);
                                }
                            }
                        }
                        NIconButton {
                            baseSize: Style.baseWidgetSize * 0.8
                            icon: "close"
                            tooltipText: I18n.tr("common.close")

                            onClicked: {
                                pluginApi?.closePanel(pluginApi?.panelOpenScreen);
                            }
                        }
                    }

                    NDivider {
                        Layout.fillWidth: true
                        visible: userRow.visible || tabBar.visible
                    }

                    // User info — second row of the header card. Hidden until
                    // we have a username; the surrounding ColumnLayout reclaims
                    // the row's height automatically.
                    RowLayout {
                        id: userRow

                        Layout.fillWidth: true
                        spacing: Style.marginM
                        visible: root.ready && (root.main?.username ?? "").length > 0

                        NImageRounded {
                            Layout.alignment: Qt.AlignVCenter
                            borderColor: Color.mPrimary
                            borderWidth: 2
                            fallbackIcon: "user"
                            fallbackIconSize: 24
                            height: Math.round(40 * Style.uiScaleRatio)
                            imagePath: root.main?.avatarUrl ?? ""
                            radius: Math.min(Style.radiusL, width / 2)
                            width: Math.round(40 * Style.uiScaleRatio)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Style.marginXS

                            NText {
                                Layout.fillWidth: true
                                color: Color.mOnSurface
                                elide: Text.ElideRight
                                font.weight: Font.Bold
                                pointSize: Style.fontSizeM
                                text: root.main?.username ?? ""
                            }
                            NText {
                                Layout.fillWidth: true
                                color: Color.mOnSurface
                                elide: Text.ElideRight
                                font.weight: Font.Thin
                                pointSize: Style.fontSizeXS
                                text: root.main?.repo || root.main?.bio || pluginApi?.tr("panel.no-bio")
                            }
                        }
                    }

                    // Tab bar (PRs/MRs vs Issues) — third row of the header card.
                    // Hidden in error/no-scope states so the card collapses to
                    // fewer rows.
                    NTabBar {
                        id: tabBar

                        Layout.fillWidth: true
                        distributeEvenly: true
                        spacing: Style.marginXS
                        tabHeight: Style.toOdd(Style.baseWidgetSize * 0.8)
                        visible: root.showLists

                        NTabButton {
                            tabIndex: 0
                            pointSize: Style.fontSizeXS
                            checked: tabBar.currentIndex === 0
                            text: pluginApi?.tr(root.platform === 'gitlab' ? "panel.mr-count" : "panel.pr-count", {
                                count: root.main?.prsCount ?? 0
                            })
                        }
                        NTabButton {
                            tabIndex: 1
                            pointSize: Style.fontSizeXS
                            checked: tabBar.currentIndex === 1
                            text: pluginApi?.tr("panel.issues-count", {
                                count: root.main?.issuesCount ?? 0
                            })
                        }
                    }
                }
            }

            // Unified error/notice box (bin missing, auth failed, no scope).
            // Visible whenever we are *definitively* not in the lists state and
            // not still loading. The three error cases are then disambiguated
            // by inspecting the underlying flags.
            NBox {
                id: statusBox

                readonly property bool binMissing: !(root.main?.isBinInstalled ?? false)
                readonly property bool authMissing: !binMissing && !(root.main?.isAuthenticated ?? false)

                readonly property string statusIcon: {
                    if (binMissing) return root.platformIcon;
                    if (authMissing) return "user-exclamation";
                    return "alert-triangle";
                }
                readonly property string statusText: {
                    if (binMissing) return pluginApi?.tr("panel.bin-not-installed", { bin: root.bin });
                    if (authMissing) return pluginApi?.tr("panel.auth-error", { bin: root.bin });
                    return pluginApi?.tr("panel.no-scope");
                }
                Layout.fillWidth: true
                Layout.preferredHeight: statusError.implicitHeight + Style.margin2M
                visible: !root.showLists && !(root.main?.loading ?? false)

                ColumnLayout {
                    id: statusError

                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginL

                    NIcon {
                        Layout.alignment: Qt.AlignHCenter
                        color: Color.mOnSurfaceVariant
                        icon: statusBox.statusIcon
                        pointSize: Style.fontSizeXXL
                    }
                    NText {
                        Layout.fillWidth: true
                        color: Color.mOnSurfaceVariant
                        horizontalAlignment: Text.AlignHLeft
                        pointSize: Style.fontSizeL
                        text: statusBox.statusText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Tab view container (lets NTabView fill remaining vertical space)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showLists

                NTabView {
                    id: tabView

                    anchors.fill: parent
                    currentIndex: tabBar.currentIndex

                    // Tab 0: PRs / MRs
                    Item {
                        height: tabView.height

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Style.marginXS

                            NBox {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                NListView {
                                    id: prListView

                                    anchors.fill: parent
                                    anchors.margins: Style.marginS
                                    clip: true
                                    interactive: true
                                    model: root.main?.prsList ?? []
                                    delegate: itemDelegate
                                    spacing: Style.marginM
                                    visible: (root.main?.prsList?.length ?? 0) > 0

                                    ScrollBar.vertical: ScrollBar {}
                                }

                                NText {
                                    anchors.centerIn: parent
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                    text: pluginApi?.tr("panel.loading")
                                    visible: (root.main?.loading ?? false) && (root.main?.prsList?.length ?? 0) === 0
                                }

                                NText {
                                    anchors.centerIn: parent
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                    text: pluginApi?.tr(root.platform === 'gitlab' ? "panel.no-mrs" : "panel.no-prs")
                                    visible: !root.main?.loading && (root.main?.prsList?.length ?? 0) === 0
                                }
                            }
                        }
                    }

                    // Tab 1: Issues
                    Item {
                        height: tabView.height

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Style.marginS

                            NBox {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                NListView {
                                    id: issueListView

                                    anchors.fill: parent
                                    anchors.margins: Style.marginS
                                    clip: true
                                    interactive: true
                                    model: root.main?.issuesList ?? []
                                    delegate: itemDelegate
                                    spacing: Style.marginM
                                    visible: (root.main?.issuesList?.length ?? 0) > 0

                                    ScrollBar.vertical: ScrollBar {}
                                }

                                NText {
                                    anchors.centerIn: parent
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                    text: pluginApi?.tr("panel.loading")
                                    visible: (root.main?.loading ?? false) && (root.main?.issuesList?.length ?? 0) === 0
                                }

                                NText {
                                    anchors.centerIn: parent
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                    text: pluginApi?.tr("panel.no-issues")
                                    visible: !root.main?.loading && (root.main?.issuesList?.length ?? 0) === 0
                                }
                            }
                        }
                    }
                }
            }

            // Bottom spacer: keeps header and error block top-aligned when lists are hidden
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.showLists
            }
        }
    }
}
