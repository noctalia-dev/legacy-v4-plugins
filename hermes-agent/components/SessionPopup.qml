import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Popup {
  id: root
  modal: true
  dim: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  anchors.centerIn: Overlay.overlay

  property var pluginApi: null
  property var mainInstance: null
  property var screen: null
  property var sessions: []
  readonly property real maxHeight: (screen ? screen.height : 800) * 0.5
  readonly property real rowHeight: 44 * Style.uiScaleRatio

  signal sessionSelected(string sessionId)

  implicitWidth: Math.min(680 * Style.uiScaleRatio, (screen ? screen.width * 0.7 : 680))
  implicitHeight: Math.min(Math.max(sessions.length * rowHeight, rowHeight) + headerHeight + padding * 2, maxHeight)
  padding: Style.marginM

  readonly property real headerHeight: 32 * Style.uiScaleRatio

  background: Rectangle {
    radius: Style.radiusL
    color: Color.mSurface
    border.color: Color.mPrimary
    border.width: Style.borderM
  }

  contentItem: ColumnLayout {
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: root.headerHeight

      NText {
        text: pluginApi?.tr("panel.sessions")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
        Layout.fillWidth: true
      }

      NText {
        text: root.sessions.length > 0 ? root.sessions.length + " sessions" : ""
        pointSize: Style.fontSizeXXS
        color: Color.mOnSurfaceVariant
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      color: Color.mOutline
      Layout.bottomMargin: Style.marginS
    }

    NScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalPolicy: ScrollBar.AlwaysOff

      ColumnLayout {
        width: parent ? parent.availableWidth : root.width
        spacing: Style.marginXXS

        Repeater {
          model: root.sessions

          ItemDelegate {
            Layout.fillWidth: true
            Layout.preferredHeight: root.rowHeight
            background: Rectangle {
              radius: Style.radiusM
              color: hovered ? Qt.alpha(Color.mPrimary, 0.08) : "transparent"
            }
            onClicked: {
              root.sessionSelected(modelData.id);
              root.close();
            }

            contentItem: RowLayout {
              spacing: Style.marginM

              NText {
                text: String(index + 1) + "."
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightSemiBold
                color: Color.mPrimary
                Layout.preferredWidth: 30 * Style.uiScaleRatio
              }

              NText {
                text: modelData.title || modelData.preview || modelData.id?.substring(0, 8) || "Session"
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightSemiBold
                color: Color.mOnSurface
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              NText {
                text: _relativeTime(modelData.started_at)
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 48 * Style.uiScaleRatio
              }
            }
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: root.sessions.length === 0

          NText {
            anchors.centerIn: parent
            text: pluginApi?.tr("panel.noSessions")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }
      }
    }
  }

  function _relativeTime(ts) {
    if (!ts || ts <= 0) return "";
    var diff = Date.now() - ts * 1000;
    var minutes = Math.floor(diff / 60000);
    if (minutes < 1) return "now";
    if (minutes < 60) return minutes + "m";
    var hours = Math.floor(minutes / 60);
    if (hours < 24) return hours + "h";
    return Math.floor(hours / 24) + "d";
  }

  function openNear(_buttonItem) {
    open();
  }
}
