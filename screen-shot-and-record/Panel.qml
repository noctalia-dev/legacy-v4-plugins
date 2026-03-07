import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import Quickshell.Io
import qs.Services.UI

Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel properties (required for panel behavior)
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  // Preferred dimensions
  property real contentPreferredWidth: panelContainer.implicitWidth + Style.marginM * 2
  property real contentPreferredHeight: panelContainer.implicitHeight + Style.marginM * 2

  property var mainInstance: pluginApi?.mainInstance

  anchors.fill: parent

  property bool recording: false

  property string target: ""

  Component.onDestruction: {
    if (target != ""){
      mainInstance?.open(target)
    }
  }

    Process {
        id: checkRecordingProc
        command: ["pidof", "wf-recorder"]
        running: true
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.recording = true;
            }
        }
    }

  NBox {
      id: panelContainer

      anchors.centerIn: parent

      implicitWidth: Math.max(titleRow.implicitWidth, buttonColumn.implicitWidth) + Style.marginM * 2
      implicitHeight: mainLayout.implicitHeight + Style.marginM * 2

      ColumnLayout {
          id: mainLayout
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
              id: titleRow
              Layout.fillWidth: true
              spacing: Style.marginS

              NIcon {
                  icon: "screenshot"
                  pointSize: Style.fontSizeL
                  color: Color.mPrimary
              }

              NText {
                  text: pluginApi?.tr("panel.title")
                  pointSize: Style.fontSizeL
                  font.weight: Style.fontWeightBold
                  color: Color.mOnSurface
                  Layout.fillWidth: true
                  wrapMode: Text.WordWrap
              }
          }

          ColumnLayout {
              id: buttonColumn
              Layout.fillWidth: true
              spacing: Style.marginS

              NButton {
                  icon: "screenshot"
                  text: pluginApi?.tr("panel.target.screenshot")
                  backgroundColor: Color.mPrimary
                  textColor: Color.mOnPrimary
                  Layout.fillWidth: true
                  onClicked: {
                      root.target = "screenshot"
                      pluginApi.closePanel(pluginApi.panelOpenScreen)
                  }
              }
              NButton {
                  icon: "text-recognition"
                  text: pluginApi?.tr("panel.target.ocr")
                  backgroundColor: Color.mPrimary
                  textColor: Color.mOnPrimary
                  Layout.fillWidth: true
                  onClicked: {
                      root.target = "ocr"
                      pluginApi.closePanel(pluginApi.panelOpenScreen)
                  }
              }
              NButton {
                  icon: "photo-search"
                  text: pluginApi?.tr("panel.target.search")
                  backgroundColor: Color.mPrimary
                  textColor: Color.mOnPrimary
                  Layout.fillWidth: true
                  onClicked: {
                      root.target = "search"
                      pluginApi.closePanel(pluginApi.panelOpenScreen)
                  }
              }
              NButton {
                  icon: "camera"
                  text: pluginApi?.tr("panel.target.record")
                  backgroundColor: Color.mPrimary
                  textColor: Color.mOnPrimary
                  Layout.fillWidth: true
                  visible: !root.recording
                  onClicked: {
                      root.target = "record"
                      pluginApi.closePanel(pluginApi.panelOpenScreen)
                  }
              }
              NButton {
                  icon: "camera-spark"
                  text: pluginApi?.tr("panel.target.recordsound")
                  backgroundColor: Color.mPrimary
                  textColor: Color.mOnPrimary
                  Layout.fillWidth: true
                  visible: !root.recording
                  onClicked: {
                      root.target = "recordsound"
                      pluginApi.closePanel(pluginApi.panelOpenScreen)
                  }
              }
              NButton {
                  icon: "close"
                  text: pluginApi?.tr("panel.target.stop")
                  backgroundColor: Color.mError
                  textColor: Color.mOnError
                  Layout.fillWidth: true
                  visible: root.recording
                  onClicked: {
                      mainInstance?.stopRecording()
                      pluginApi.closePanel(pluginApi.panelOpenScreen)
                  }
              }
          }
      }
  }
}