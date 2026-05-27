import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root

  property var pluginApi: null
  property var mainInstance: null
  property bool errorDetailsExpanded: false

  signal errorDetailsExpandedRequested(bool value)
  signal dismissRequested()

  function copiedErrorText() {
    const summary = String(mainInstance?.lastError || "").trim();
    const details = String(mainInstance?.lastErrorDetails || "").trim();
    if (details.length === 0) {
      return summary;
    }
    return summary + "\n\n" + details;
  }

  visible: !!(mainInstance?.lastError && mainInstance.lastError.length > 0)
  Layout.fillWidth: true
  implicitHeight: errorBannerContent.implicitHeight + Style.marginS * 2
  Layout.preferredHeight: implicitHeight
  radius: Style.radiusM
  color: Qt.alpha(Color.mError, 0.08)
  border.width: Style.borderS
  border.color: Qt.alpha(Color.mError, 0.32)

  ColumnLayout {
    id: errorBannerContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: Style.marginS
    anchors.rightMargin: Style.marginS
    anchors.topMargin: Style.marginS
    spacing: Style.marginXS

    RowLayout {
      Layout.fillWidth: true

      NIcon {
        icon: "alert-triangle"
        pointSize: Style.fontSizeL
        color: Color.mError
      }

      NText {
        text: pluginApi?.tr("panel.errorBannerTitle")
        color: Color.mError
        font.weight: Font.Bold
      }

      Item { Layout.fillWidth: true }

      NIconButton {
        icon: "copy"
        tooltipText: pluginApi?.tr("panel.errorCopy")
        onClicked: {
          const text = root.copiedErrorText();
          if (text.length === 0) {
            return;
          }
          Quickshell.clipboardText = text;
          ToastService.showNotice(pluginApi?.tr("panel.title"), pluginApi?.tr("panel.errorCopied"), "copy");
        }
      }

      NButton {
        text: root.errorDetailsExpanded
          ? pluginApi?.tr("panel.errorHideDetails")
          : pluginApi?.tr("panel.errorShowDetails")
        icon: root.errorDetailsExpanded ? "chevron-up" : "chevron-down"
        onClicked: root.errorDetailsExpandedRequested(!root.errorDetailsExpanded)
      }

      NIconButton {
        icon: "x"
        tooltipText: pluginApi?.tr("panel.errorDismiss")
        onClicked: root.dismissRequested()
      }
    }

    NText {
      Layout.fillWidth: true
      text: mainInstance?.lastError ?? ""
      color: Color.mOnSurface
      wrapMode: Text.WordWrap
      font.weight: Font.Medium
    }

    Rectangle {
      visible: root.errorDetailsExpanded && (mainInstance?.lastErrorDetails ?? "").length > 0
      Layout.fillWidth: true
      Layout.preferredHeight: 136 * Style.uiScaleRatio
      radius: Style.radiusS
      color: Qt.alpha(Color.mSurface, 0.55)
      border.width: Style.borderS
      border.color: Qt.alpha(Color.mError, 0.18)

      NScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginXS
        showScrollbarWhenScrollable: true
        gradientColor: "transparent"

        NText {
          width: parent.width
          text: mainInstance?.lastErrorDetails ?? ""
          color: Color.mOnSurface
          wrapMode: Text.WrapAnywhere
        }
      }
    }
  }
}
