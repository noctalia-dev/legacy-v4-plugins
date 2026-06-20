import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Services.System
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property string iconType: cfg.iconType ?? defaults.iconType ?? "arrow"

  property real contentPreferredWidth: 400 * Style.uiScaleRatio
  property real contentPreferredHeight: Math.min(contentColumn.implicitHeight + Style.marginL * 2, 600 * Style.uiScaleRatio)

  property bool useCustomColors: cfg.useCustomColors ?? defaults.useCustomColors
  property color colorTx: root.useCustomColors && cfg.colorTx || Color.mSecondary
  property color colorRx: root.useCustomColors && cfg.colorRx || Color.mPrimary

  anchors.fill: parent

  Component.onCompleted: {
    if (pluginApi)
      Logger.i("NetworkIndicator", "Panel initialized");
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: contentColumn

      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // ── Header ──

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
          icon: "activity"
          pointSize: Style.fontSizeXL
          color: Color.mPrimary
          Layout.alignment: Qt.AlignVCenter
        }

        NText {
          text: root.pluginApi?.tr("panel.title")
          pointSize: Style.fontSizeL
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignVCenter
        }

        Item {
          Layout.fillWidth: true
        }

        NText {
          text: `Interval ${(SystemStatService.networkIntervalMs / 1000)}s`
          pointSize: Style.fontSizeXXS
          color: Qt.alpha(Color.mOnSurface, 0.5)
          Layout.alignment: Qt.AlignVCenter
        }

        NIconButton {
          icon: "settings"
          tooltipText: root.pluginApi?.tr("actions.widget-settings")
          onClicked: {
            const screen = root.pluginApi?.panelOpenScreen;
            if (screen) {
              root.pluginApi.closePanel(screen);
              Qt.callLater(() => BarService.openPluginSettings(screen, root.pluginApi.manifest));
            }
          }
          Layout.alignment: Qt.AlignVCenter
        }

        NIconButton {
          icon: "close"
          tooltipText: root.pluginApi?.tr("panel.close")
          onClicked: {
            const s = root.pluginApi?.panelOpenScreen;
            if (s)
              root.pluginApi.closePanel(s);
          }
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // ── Download (RX) ──

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: rxGraph.implicitHeight + Style.marginS * 2

        NetworkGraph {
          id: rxGraph
          anchors.fill: parent
          anchors.margins: Style.marginS

          label: root.pluginApi?.tr("panel.download")
          iconName: root.iconType + "-down"
          accentColor: root.colorRx
          history: SystemStatService.rxSpeedHistory
          maxValue: SystemStatService.rxMaxSpeed
          currentSpeed: SystemStatService.rxSpeed
        }
      }

      // ── Upload (TX) ──

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: txGraph.implicitHeight + Style.marginS * 2

        NetworkGraph {
          id: txGraph
          anchors.fill: parent
          anchors.margins: Style.marginS

          label: root.pluginApi?.tr("panel.upload")
          iconName: root.iconType + "-up"
          accentColor: root.colorTx
          history: SystemStatService.txSpeedHistory
          maxValue: SystemStatService.txMaxSpeed
          currentSpeed: SystemStatService.txSpeed
        }
      }
    }
  }

  component NetworkGraph: ColumnLayout {
    id: graphRoot

    required property string label
    required property string iconName
    required property color accentColor
    required property var history
    required property real maxValue
    required property real currentSpeed

    function formatSpeed(bytesPerSec) {
      return (SystemStatService.formatSpeed(bytesPerSec).replace(/([0-9.]+)([A-Za-z]+)/, "$1 $2") + "/s");
    }

    function timeAgo(idx) {
      const n = graphRoot.history.length;
      if (n < 2 || idx < 0)
        return "";

      const secsAgo = Math.round((n - 1 - idx) * SystemStatService.networkIntervalMs / 1000);
      if (secsAgo < 60)
        return secsAgo + "s ago";

      const mins = Math.floor(secsAgo / 60);
      const secs = secsAgo % 60;
      return mins + "m " + secs + "s ago";
    }

    readonly property real yTickHigh: graphRoot.maxValue > 0 ? graphRoot.maxValue * 0.66 : 0
    readonly property real yTickLow: graphRoot.maxValue > 0 ? graphRoot.maxValue * 0.33 : 0
    readonly property real yAxisWidth: yAxisSizer.width + Style.marginXL

    spacing: Style.marginXS

    // Hidden text to measure the widest Y-axis label.
    // TODO: find a better way.
    NText {
      id: yAxisSizer
      visible: false
      text: graphRoot.formatSpeed(graphRoot.yTickHigh)
      pointSize: Style.fontSizeXS * 0.8
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NIcon {
        icon: graphRoot.iconName
        pointSize: Style.fontSizeXS
        color: graphRoot.accentColor
      }

      NText {
        text: graphRoot.label
        pointSize: Style.fontSizeXS
        color: graphRoot.accentColor
        font.weight: Font.Medium
      }

      Item {
        Layout.fillWidth: true
      }

      NText {
        text: graphRoot.formatSpeed(graphRoot.currentSpeed)
        pointSize: Style.fontSizeXS
        color: graphRoot.accentColor
        font.family: Settings.data.ui.fontFixed
      }
    }

    Item {
      Layout.fillWidth: true
      implicitHeight: 120 * Style.uiScaleRatio

      Item {
        id: graphArea
        anchors.fill: parent

        NGraph {
          id: graph
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.rightMargin: graphRoot.yAxisWidth
          values: graphRoot.history
          minValue: 0
          maxValue: graphRoot.maxValue
          color: graphRoot.accentColor
          strokeWidth: Math.max(1, Style.uiScaleRatio)
          fill: true
          fillOpacity: 0.15
          updateInterval: SystemStatService.networkIntervalMs
          animateScale: true
        }

        // ── Y-axis scale ──

        Repeater {
          model: [
            {
              value: graphRoot.yTickHigh,
              fraction: 0.66
            },
            {
              value: graphRoot.yTickLow,
              fraction: 0.33
            }
          ]

          delegate: Item {
            required property var modelData
            anchors.left: parent.left
            anchors.right: parent.right
            y: graphArea.height * (1.0 - modelData.fraction)
            visible: graphRoot.maxValue > 0

            Rectangle {
              id: horizontalLineYLabel
              anchors.left: parent.left
              anchors.right: yLabel.left
              anchors.rightMargin: Style.marginXS
              height: 1
              color: Qt.alpha(Color.mOnSurface, 0.08)
            }

            Rectangle {
              id: yLabel
              anchors.right: parent.right
              y: -height / 2
              implicitWidth: yLabelText.implicitWidth + Style.marginXS * 2
              implicitHeight: yLabelText.implicitHeight + 2
              radius: Style.radiusXS
              color: Qt.alpha(graphRoot.accentColor, 0.10)

              NText {
                id: yLabelText
                anchors.centerIn: parent
                text: graphRoot.formatSpeed(modelData.value)
                pointSize: Style.fontSizeXS * 0.8
                color: Qt.alpha(graphRoot.accentColor, 0.7)
              }
            }
          }
        }

        // ── Hover ──

        MouseArea {
          id: hover
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.rightMargin: graphRoot.yAxisWidth
          hoverEnabled: true

          readonly property int idx: {
            const n = graphRoot.history.length;
            if (n < 2 || !containsMouse)
              return -1;
            return Math.max(0, Math.min(n - 1, Math.round(mouseX / width * (n - 1))));
          }

          readonly property real value: idx >= 0 ? (graphRoot.history[idx] ?? -1) : -1

          Rectangle {
            visible: hover.idx >= 0
            x: {
              const n = graphRoot.history.length;
              if (hover.idx < 0 || n < 2)
                return 0;
              return (hover.idx / (n - 1)) * parent.width - width / 2;
            }
            width: Style.borderS
            height: parent.height
            color: Qt.alpha(Color.mOnSurface, 0.25)

            Rectangle {
              readonly property real posX: -implicitWidth / 2
              readonly property string _label: {
                if (hover.value < 0)
                  return "";
                const speed = graphRoot.formatSpeed(hover.value);
                const time = graphRoot.timeAgo(hover.idx);
                return speed + (time ? " · " + time : "");
              }

              x: Math.max(-parent.x, Math.min(hover.width - parent.x - implicitWidth, posX))
              y: Style.marginXS

              implicitWidth: bubbleText.implicitWidth + Style.marginS * 2
              implicitHeight: bubbleText.implicitHeight + Style.marginXS * 2
              radius: Style.radiusS
              color: Color.mSurfaceVariant
              border.color: Qt.alpha(Color.mOnSurface, 0.15)
              border.width: Style.borderS

              NText {
                id: bubbleText
                anchors.centerIn: parent
                text: parent._label
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
            }
          }
        }
      }
    }
  }
}
