import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
    id: root

    readonly property var cfg: pluginApi?.pluginSettings ?? ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
    readonly property string platform: cfg.platform ?? defaults.platform
    readonly property var main: pluginApi?.mainInstance
    property string selectedRepo: cfg.selectedRepo ?? defaults.selectedRepo
    property string requestLabel: platform === 'gitlab' ? pluginApi?.tr("panel.mr") : pluginApi?.tr("panel.pr")
    property string text: pluginApi?.tr("desktop.text", {
        issues: main?.issuesCount ?? 0,
        requestCount: main?.prsCount ?? 0,
        requestLabel
    })
    property var pluginApi: null

    implicitHeight: 120
    implicitWidth: 200

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginS

        NIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: root.platform === 'gitlab' ? 'brand-gitlab' : "brand-github"
            pointSize: Style.fontSizeXXL
        }
        NText {
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: Style.fontSizeM
            text: root.selectedRepo
        }
        NText {
            Layout.alignment: Qt.AlignHCenter
            color: Color.mOnSurfaceVariant
            font.pointSize: Style.fontSizeS
            text: root.text
        }
    }
}
