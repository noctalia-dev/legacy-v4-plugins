import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "lib/Ui.js" as Ui

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool pillDirection: BarService.getPillDirection(root)

  readonly property var service: root.pluginApi?.mainInstance
  readonly property bool actionBusy: root.service?.actionBusy ?? false
  readonly property bool obsRunning: root.service?.obsRunning ?? false
  readonly property bool websocket: root.service?.websocket ?? false
  readonly property bool connected: root.obsRunning && root.websocket
  readonly property bool recording: root.service?.recording ?? false
  readonly property bool replayBuffer: root.service?.replayBuffer ?? false
  readonly property bool streaming: root.service?.streaming ?? false
  readonly property int recordDurationMs: root.service?.displayRecordDurationMs ?? 0
  readonly property int streamDurationMs: root.service?.displayStreamDurationMs ?? 0
  readonly property string primaryActionText: root.service?.primaryActionText ?? root.pluginApi?.tr("actions.primary.open_controls") ?? ""
  readonly property string barLabelMode: root.service?.barLabelMode ?? "short-label"
  readonly property bool showElapsedInBar: root.service?.showElapsedInBar ?? false
  readonly property var outputState: ({
    recording: root.recording,
    replayBuffer: root.replayBuffer,
    streaming: root.streaming,
    recordDurationMs: root.recordDurationMs,
    streamDurationMs: root.streamDurationMs,
  })

  readonly property string screenName: root.screen?.name ?? ""
  readonly property string barPosition: Settings.getBarPositionForScreen(root.screenName)
  readonly property bool isBarVertical: root.barPosition === "left" || root.barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(root.screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(root.screenName)

  readonly property var activeOutputs: Ui.activeOutputs(root.pluginApi, root.outputState)
  readonly property string statusTooltip: Ui.quickActionTooltip(root.pluginApi, root.outputState, root.connected, root.obsRunning, root.primaryActionText)
  readonly property bool showIdleIcon: root.activeOutputs.length === 0
  readonly property string displayText: Ui.barDisplayText(root.pluginApi, root.outputState, root.barLabelMode, root.showElapsedInBar)
  readonly property color accentColor: Ui.accentBackgroundColor(root.outputState, Color, Color.mOnSurface)
  readonly property color idleIconColor: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
  readonly property string primaryIconName: Ui.primaryIcon(root.outputState)

  readonly property bool showInBar: root.service?.showInBar ?? false
  readonly property real contentWidth: root.showInBar
                                      ? (root.isBarVertical
                                          ? root.capsuleHeight
                                          : Math.round(content.implicitWidth + Style.marginM * 2))
                                      : 0
  readonly property real contentHeight: root.showInBar
                                       ? (root.isBarVertical
                                           ? Math.round(content.implicitHeight + Style.marginM * 2)
                                           : root.capsuleHeight)
                                       : 0

  visible: root.showInBar
  implicitWidth: root.contentWidth
  implicitHeight: root.contentHeight

  Rectangle {
    id: visualCapsule

    visible: root.showInBar
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Item {
      id: content

      anchors.verticalCenter: parent.verticalCenter
      anchors.left: root.isBarVertical || !root.pillDirection ? undefined : parent.left
      anchors.right: root.isBarVertical || root.pillDirection ? undefined : parent.right
      anchors.leftMargin: Style.marginM
      anchors.rightMargin: Style.marginM
      implicitWidth: horizontalContent.visible ? horizontalContent.implicitWidth : verticalContent.implicitWidth
      implicitHeight: horizontalContent.visible ? horizontalContent.implicitHeight : verticalContent.implicitHeight

      RowLayout {
        id: horizontalContent

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.isBarVertical
        spacing: Style.marginS
        layoutDirection: root.pillDirection ? Qt.LeftToRight : Qt.RightToLeft

        NIcon {
          visible: root.showIdleIcon
          icon: "camera-video"
          pointSize: Math.max(1, Math.round(root.barFontSize * 1.15))
          applyUiScale: false
          color: root.idleIconColor
          Layout.alignment: Qt.AlignVCenter
        }

        NIcon {
          visible: !root.showIdleIcon && root.barLabelMode === "icon-only"
          icon: root.primaryIconName
          pointSize: Math.max(1, Math.round(root.barFontSize))
          applyUiScale: false
          color: root.accentColor
          Layout.alignment: Qt.AlignVCenter
        }

        NText {
          visible: root.displayText !== ""
          text: root.displayText
          pointSize: root.barFontSize
          applyUiScale: false
          font.weight: Style.fontWeightSemiBold
          color: root.accentColor
          Layout.alignment: Qt.AlignVCenter
        }
      }

      ColumnLayout {
        id: verticalContent

        anchors.centerIn: parent
        visible: root.isBarVertical
        spacing: Style.marginXS

        NIcon {
          visible: root.showIdleIcon
          icon: "camera-video"
          pointSize: Math.max(1, Math.round(root.barFontSize))
          applyUiScale: false
          color: root.idleIconColor
          Layout.alignment: Qt.AlignHCenter
        }

        NIcon {
          visible: !root.showIdleIcon && root.barLabelMode === "icon-only"
          icon: root.primaryIconName
          pointSize: Math.max(1, Math.round(root.barFontSize))
          applyUiScale: false
          color: root.accentColor
          Layout.alignment: Qt.AlignHCenter
        }

        NText {
          visible: root.displayText !== ""
          text: root.displayText
          pointSize: root.barFontSize * 0.88
          applyUiScale: false
          font.weight: Style.fontWeightSemiBold
          color: root.accentColor
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }
  }

  MouseArea {
    id: mouseArea

    anchors.fill: parent
    enabled: root.showInBar
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onEntered: {
      TooltipService.show(root, root.statusTooltip, "auto")
    }

    onExited: {
      TooltipService.hide(root)
    }

    onPressed: {
      TooltipService.hide(root)
    }

    onClicked: function(mouse) {
      if (!root.service || root.actionBusy) {
        return
      }

      if (mouse.button === Qt.LeftButton) {
        root.service.runPrimaryAction(root.screen, root)
      } else if (mouse.button === Qt.RightButton) {
        root.service.runSecondaryAction()
      } else if (mouse.button === Qt.MiddleButton) {
        root.service.runMiddleAction()
      }
    }
  }
}
