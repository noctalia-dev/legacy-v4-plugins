import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "lib/Ui.js" as Ui

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property var service: root.pluginApi?.mainInstance
  readonly property bool obsRunning: root.service?.obsRunning ?? false
  readonly property bool websocket: root.service?.websocket ?? false
  readonly property bool recording: root.service?.recording ?? false
  readonly property bool replayBuffer: root.service?.replayBuffer ?? false
  readonly property bool streaming: root.service?.streaming ?? false
  readonly property int recordDurationMs: root.service?.displayRecordDurationMs ?? 0
  readonly property int streamDurationMs: root.service?.displayStreamDurationMs ?? 0
  readonly property bool connected: root.obsRunning && root.websocket
  readonly property bool actionBusy: root.service?.actionBusy ?? false
  readonly property bool websocketSupportMissing: root.service?.websocketSupportMissing ?? false
  readonly property bool websocketConfigMissing: root.service?.websocketConfigMissing ?? false
  readonly property bool autoCloseManagedObs: root.service?.autoCloseManagedObs ?? false
  readonly property bool canOpenVideos: root.service?.canOpenVideos ?? false
  readonly property string primaryActionText: root.service?.primaryActionText ?? root.pluginApi?.tr("actions.primary.open_controls") ?? ""
  readonly property var outputState: ({
    recording: root.recording,
    replayBuffer: root.replayBuffer,
    streaming: root.streaming,
    recordDurationMs: root.recordDurationMs,
    streamDurationMs: root.streamDurationMs,
  })
  readonly property string headerIconName: Ui.primaryIcon(root.outputState) || "camera-video"

  readonly property color statusAccentColor: Ui.accentBackgroundColor(root.outputState, Color, Color.mOnSurface)

  property bool allowAttach: true
  property real contentPreferredWidth: Math.round(372 * Style.uiScaleRatio)
  property real contentPreferredHeight: content.implicitHeight + (Style.margin2L * 2)

  Item {
    id: panelContainer
    anchors.fill: parent

    ColumnLayout {
      id: content

      x: Style.marginL
      y: Style.marginL
      width: parent.width - Style.margin2L
      spacing: Style.marginL

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
          icon: root.headerIconName
          pointSize: Math.round(Style.fontSizeXXL * 1.4)
          color: root.recording ? Color.mError : Color.mPrimary
          Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginXXS

          NText {
            text: root.pluginApi?.tr("panel.header.title") ?? ""
            pointSize: Style.fontSizeXL
            font.weight: Style.fontWeightSemiBold
            color: Color.mPrimary
          }

          NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Color.mOnSurfaceVariant
            text: Ui.panelHeaderText(root.pluginApi, root.outputState, root.connected, root.obsRunning, root.websocketSupportMissing, root.websocketConfigMissing)
          }
        }

        NIconButton {
          icon: "settings"
          tooltipText: root.pluginApi?.tr("panel.actions.open_settings") ?? ""
          Layout.alignment: Qt.AlignTop
          onClicked: root.service?.openSettingsForCurrentContext()
        }
      }

      NBox {
        Layout.fillWidth: true
        implicitHeight: statusColumn.implicitHeight + Style.marginXL

        ColumnLayout {
          id: statusColumn

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.marginM
          spacing: Style.marginXS

          NText {
            Layout.fillWidth: true
            text: `${root.pluginApi?.tr("panel.status.label") ?? ""}: ${Ui.panelStatusText(root.pluginApi, root.outputState, root.connected, root.obsRunning, root.websocketSupportMissing, root.websocketConfigMissing)}`
            font.weight: Style.fontWeightSemiBold
            color: root.statusAccentColor
          }

          NText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Color.mOnSurfaceVariant
            text: root.websocket
                  ? (root.pluginApi?.tr("panel.status.connected_hint", {
                       primaryAction: root.primaryActionText,
                     }) ?? "")
                  : Ui.panelDisconnectedHint(root.pluginApi, root.websocketSupportMissing, root.websocketConfigMissing)
          }

          NText {
            Layout.fillWidth: true
            visible: root.recording && root.recordDurationMs > 0
            text: `${root.pluginApi?.tr("panel.status.recording_elapsed") ?? ""}: ${Ui.formatDuration(root.recordDurationMs)}`
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }

          NText {
            Layout.fillWidth: true
            visible: root.streaming && root.streamDurationMs > 0
            text: `${root.pluginApi?.tr("panel.status.streaming_elapsed") ?? ""}: ${Ui.formatDuration(root.streamDurationMs)}`
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }

          NText {
            Layout.fillWidth: true
            visible: root.autoCloseManagedObs
            wrapMode: Text.WordWrap
            color: Color.mOnSurfaceVariant
            text: root.pluginApi?.tr("panel.status.managed_hint") ?? ""
          }
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginM
        rowSpacing: Style.marginM

        NButton {
          Layout.fillWidth: true
          icon: root.obsRunning ? "refresh" : "player-play"
          text: !root.obsRunning
                ? (root.pluginApi?.tr("panel.actions.launch_obs") ?? "")
                : (root.pluginApi?.tr("panel.actions.retry_connection") ?? "")
          visible: !root.obsRunning || (!root.connected && !root.websocketSupportMissing && !root.websocketConfigMissing)
          enabled: (!root.obsRunning || !root.websocket) && !root.actionBusy

          onClicked: {
            if (!root.service) {
              return
            }

            if (root.obsRunning) {
              root.service.refresh()
              return
            }

            root.service.launchObs()
          }
        }

        NButton {
          Layout.fillWidth: true
          icon: "player-record"
          text: root.recording
                ? (root.pluginApi?.tr("panel.actions.stop_recording") ?? "")
                : (root.pluginApi?.tr("panel.actions.start_recording") ?? "")
          enabled: root.connected && !root.actionBusy
          backgroundColor: root.recording ? Color.mError : Color.mPrimary
          textColor: root.recording ? Color.mOnError : Color.mOnPrimary
          onClicked: root.service?.toggleRecord()
        }

        NButton {
          Layout.fillWidth: true
          icon: "antenna-bars-5"
          text: root.streaming
                ? (root.pluginApi?.tr("panel.actions.stop_streaming") ?? "")
                : (root.pluginApi?.tr("panel.actions.start_streaming") ?? "")
          enabled: root.connected && !root.actionBusy
          backgroundColor: root.streaming ? Color.mPrimary : Color.mSurfaceVariant
          textColor: root.streaming ? Color.mOnPrimary : Color.mOnSurface
          onClicked: root.service?.toggleStream()
        }

        NButton {
          Layout.fillWidth: true
          icon: "history"
          text: root.replayBuffer
                ? (root.pluginApi?.tr("panel.actions.stop_replay") ?? "")
                : (root.pluginApi?.tr("panel.actions.start_replay") ?? "")
          enabled: root.connected && !root.actionBusy
          backgroundColor: root.replayBuffer ? Color.mSecondary : Color.mSurfaceVariant
          textColor: root.replayBuffer ? Color.mOnSecondary : Color.mOnSurface
          onClicked: root.service?.toggleReplay()
        }

        NButton {
          Layout.fillWidth: true
          icon: "device-floppy"
          text: root.pluginApi?.tr("panel.actions.save_replay") ?? ""
          enabled: root.replayBuffer && !root.actionBusy
          outlined: !root.replayBuffer
          onClicked: root.service?.saveReplay()
        }

        NButton {
          Layout.fillWidth: true
          icon: "folder"
          text: root.pluginApi?.tr("panel.actions.open_videos") ?? ""
          enabled: root.canOpenVideos
          outlined: true
          onClicked: root.service?.openVideos()
        }

        NButton {
          Layout.fillWidth: true
          icon: "refresh"
          text: root.pluginApi?.tr("panel.actions.refresh_status") ?? ""
          outlined: true
          onClicked: root.service?.refresh()
        }
      }
    }
  }
}
