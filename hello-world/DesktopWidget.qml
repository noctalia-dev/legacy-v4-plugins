import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  readonly property string message: widgetData.message ?? cfg.message ?? defaults.message ?? "Hello World"

  implicitWidth: 200
  implicitHeight: 120

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginS

    NIcon {
      icon: "noctalia"
      pointSize: Style.fontSizeXXL
      Layout.alignment: Qt.AlignHCenter
    }

    NText {
      text: root.message
      font.pointSize: Style.fontSizeM
      Layout.alignment: Qt.AlignHCenter
    }

    NText {
      text: "Desktop Widget"
      font.pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      Layout.alignment: Qt.AlignHCenter
    }
  }
}
