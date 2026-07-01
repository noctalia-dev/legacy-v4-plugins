import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

// Popover: themed NVIDIA header with the Battery⇄HDMI toggle, live dGPU stats, the
// external-display readout, and the list of processes holding the GPU. Detailed
// nvidia-smi stats are polled ONLY while this panel is visible.
Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 360 * Style.uiScaleRatio
  property real contentPreferredHeight: (panelCol.implicitHeight + Style.marginL * 2) * Style.uiScaleRatio
  readonly property bool allowAttach: true

  anchors.fill: parent

  readonly property var main: pluginApi?.mainInstance
  readonly property var s: main ? main.stats : ({})
  readonly property string runtime: (s && s.runtime) ? s.runtime : "unknown"
  readonly property bool active: runtime === "active"
  readonly property string pending: main ? main.pending : "battery"
  readonly property bool needsRestart: main ? main.needsRestart : false
  readonly property bool ext: main ? main.external : false
  readonly property bool lit: root.ext || root.active

  // Detailed nvidia-smi stats — polled ONLY while this panel is visible, so the
  // background bar poll never wakes the dGPU.
  property var full: ({})

  Process {
    id: fullProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.full = JSON.parse(this.text);
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 2000
    running: root.visible && !!root.main
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.main && !fullProc.running) {
        fullProc.command = ["bash", root.main.statCmd, "full"];
        fullProc.running = true;
      }
    }
  }

  function fmt1(n) {
    return (Math.round((Number(n) || 0) * 10) / 10).toFixed(1);
  }

  function subtitle() {
    var api = root.pluginApi;
    if (root.needsRestart) {
      var m = (root.pending === "hdmi") ? api?.tr("common.mode-hdmi") : api?.tr("common.mode-battery");
      return api?.tr("panel.subtitle-pending", {
        "mode": m
      });
    }
    if (root.pending === "hdmi")
      return root.ext ? api?.tr("panel.subtitle-driving") : api?.tr("panel.subtitle-hdmi");
    return root.active ? api?.tr("panel.subtitle-battery-awake") : api?.tr("panel.subtitle-battery-asleep");
  }

  function statRows() {
    var d = root.full || {};
    var api = root.pluginApi;
    return [
      {
        "icon": "bolt",
        "label": api?.tr("panel.stat-power"),
        "value": fmt1(d.powerW) + " W"
      }, {
        "icon": "temperature",
        "label": api?.tr("panel.stat-temp"),
        "value": (d.tempC || 0) + "°C"
      }, {
        "icon": "activity",
        "label": api?.tr("panel.stat-util"),
        "value": (d.util || 0) + "%"
      }, {
        "icon": "memory",
        "label": api?.tr("panel.stat-vram"),
        "value": fmt1(d.vramUsed) + " / " + fmt1(d.vramTotal) + " GB"
      }
    ];
  }

  Item {
    id: panelContainer
    anchors.fill: parent

    ColumnLayout {
      id: panelCol
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      // Header: themed NVIDIA mark + title + Battery/HDMI toggle
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Item {
          id: headerMark
          implicitWidth: Math.round(Style.fontSizeXXL * 1.7)
          implicitHeight: Math.round(Style.fontSizeXXL * 1.2)
          width: implicitWidth
          height: implicitHeight

          Image {
            id: headerEye
            anchors.fill: parent
            source: Qt.resolvedUrl("Assets/nvidia-eye.svg")
            fillMode: Image.PreserveAspectFit
            sourceSize.width: parent.width
            sourceSize.height: parent.height
            smooth: true
            mipmap: true
            visible: false
          }
          MultiEffect {
            anchors.fill: headerEye
            source: headerEye
            colorization: 1.0
            colorizationColor: root.lit ? Color.mPrimary : Color.mOnSurface
            Behavior on colorizationColor {
              ColorAnimation {
                duration: Style.animationFast
              }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            text: (root.s && root.s.gpuName) ? root.s.gpuName : root.pluginApi?.tr("panel.title-fallback")
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
          }

          NText {
            text: root.subtitle()
            pointSize: Style.fontSizeS
            color: root.needsRestart ? Color.mError : (root.pending === "hdmi" ? Color.mPrimary : Color.mOnSurfaceVariant)
          }
        }

        NToggle {
          checked: root.pending === "hdmi"
          onToggled: {
            if (root.main)
              root.main.toggle();
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
      }

      // Mode context: external display + what is holding the dGPU awake
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          NIcon {
            icon: "device-tv"
            color: root.ext ? Color.mPrimary : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeM
          }
          NText {
            text: root.pluginApi?.tr("panel.external")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.fillWidth: true
          }
          NText {
            text: root.ext ? ((root.s.external || "?") + " · " + (root.s.externalName || "")) : root.pluginApi?.tr("common.none")
            color: root.ext ? Color.mPrimary : Color.mOnSurface
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: root.active
          NIcon {
            icon: "stack"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeM
          }
          NText {
            text: root.pluginApi?.tr("panel.gpu-processes")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
            Layout.fillWidth: true
          }
          NText {
            text: (root.full && root.full.heldBy && root.full.heldBy.length > 0) ? root.full.heldBy : root.pluginApi?.tr("panel.none-reported")
            color: Color.mOnSurface
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightBold
            elide: Text.ElideRight
            Layout.maximumWidth: 180 * Style.uiScaleRatio
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
      }

      // Live dGPU stats (dimmed while the dGPU is asleep)
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        opacity: root.active ? 1.0 : 0.4

        Repeater {
          model: root.statRows()

          delegate: RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: modelData.icon
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeM
            }
            NText {
              text: modelData.label
              color: Color.mOnSurfaceVariant
              pointSize: Style.fontSizeS
              Layout.fillWidth: true
            }
            NText {
              text: modelData.value
              color: Color.mOnSurface
              pointSize: Style.fontSizeS
              font.weight: Style.fontWeightBold
            }
          }
        }
      }

      // Apply banner — only when a mode change is pending
      NDivider {
        Layout.fillWidth: true
        visible: root.needsRestart
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM
        visible: root.needsRestart

        NText {
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: root.pluginApi?.tr("panel.apply-note")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }

        NButton {
          text: root.pluginApi?.tr("panel.apply-button")
          fontSize: Style.fontSizeS
          backgroundColor: Color.mError
          textColor: Color.mOnError
          onClicked: {
            if (root.main)
              root.main.apply();
          }
        }
      }
    }
  }
}
