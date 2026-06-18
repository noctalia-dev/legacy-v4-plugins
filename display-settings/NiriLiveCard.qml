import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

OutputCard {
  id: root

  property var output
  property var pluginApi
  property bool modifying: false
  property var transforms: []

  signal modeRequested(string modeLabel)
  signal scaleRequested(real scale)
  signal autoScaleRequested()
  signal transformRequested(string transformName)
  signal vrrToggleRequested()
  signal powerToggleRequested()

  readonly property real scaleStep: 0.25
  readonly property real minScale: 0.25
  readonly property real currentScale: parseFloat(output.scale) || 1.0

  outputName: output.name
  isDisabled: !output.enabled
  disabledText: pluginApi?.tr("panel.statusOff")
  contentSpacing: Style.marginS

  ModeDropdown {
    Layout.fillWidth: true
    visible: root.output.enabled && (root.output.modes || []).length > 0
    enabled: !root.modifying
    output: root.output
    pluginApi: root.pluginApi
    onModeSelected: label => root.modeRequested(label)
  }

  ColumnLayout {
    visible: root.output.enabled
    Layout.fillWidth: true
    spacing: Style.marginXS

    NText {
      text: root.pluginApi?.tr("panel.scale")
      pointSize: Style.fontSizeS; font.weight: Font.DemiBold; color: Color.mOnSurfaceVariant
    }

    RowLayout {
      spacing: Style.marginS

      NIconButton {
        icon: "minus"; baseSize: 28
        enabled: !root.modifying && root.currentScale > root.minScale
        onClicked: root.scaleRequested(Math.max(root.minScale, root.currentScale - root.scaleStep))
      }

      NText {
        text: root.output.scale || "?"
        pointSize: Style.fontSizeM; font.weight: Font.Bold; color: Color.mOnSurface
        Layout.preferredWidth: 50 * Style.uiScaleRatio
        horizontalAlignment: Text.AlignHCenter
      }

      NIconButton {
        icon: "plus"; baseSize: 28
        enabled: !root.modifying
        onClicked: root.scaleRequested(root.currentScale + root.scaleStep)
      }

      PillButton {
        label: root.pluginApi?.tr("panel.auto")
        enabled: !root.modifying
        onActivated: root.autoScaleRequested()
      }
    }
  }

  ColumnLayout {
    visible: root.output.enabled
    Layout.fillWidth: true
    spacing: Style.marginXS

    NText {
      text: root.pluginApi?.tr("panel.transform")
      pointSize: Style.fontSizeS; font.weight: Font.DemiBold; color: Color.mOnSurfaceVariant
    }

    Flow {
      Layout.fillWidth: true
      spacing: Style.marginXS

      Repeater {
        model: root.transforms
        delegate: PillButton {
          label: root.formatTransform(modelData)
          active: root.output.transform === modelData
          enabled: !root.modifying
          onActivated: { if (!active) root.transformRequested(modelData) }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    ColumnLayout {
      visible: root.output.enabled
      spacing: Style.marginXS

      NText {
        text: root.pluginApi?.tr("panel.vrr")
        pointSize: Style.fontSizeS; font.weight: Font.DemiBold; color: Color.mOnSurfaceVariant
      }

      RowLayout {
        spacing: Style.marginS

        PillButton {
          label: root.output.vrrEnabled
            ? root.pluginApi?.tr("panel.on")
            : root.pluginApi?.tr("panel.off")
          active: root.output.vrrEnabled
          enabled: !root.modifying && root.output.vrrSupported
          opacity: root.output.vrrSupported ? 1.0 : 0.4
          onActivated: root.vrrToggleRequested()
        }

        NText {
          visible: !root.output.vrrSupported
          text: root.pluginApi?.tr("panel.vrrNotSupported")
          pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
        }
      }
    }

    Item { Layout.fillWidth: true }

    ColumnLayout {
      spacing: Style.marginXS

      NText {
        text: root.pluginApi?.tr("panel.power")
        pointSize: Style.fontSizeS; font.weight: Font.DemiBold; color: Color.mOnSurfaceVariant
      }

      PillButton {
        label: root.output.enabled
          ? root.pluginApi?.tr("panel.turnOff")
          : root.pluginApi?.tr("panel.turnOn")
        enabled: !root.modifying
        onActivated: root.powerToggleRequested()
      }
    }
  }

  function formatTransform(t) {
    var labels = {
      "normal": "Normal",
      "90": "90°",
      "180": "180°",
      "270": "270°",
      "flipped": "Flip",
      "flipped-90": "Flip 90°",
      "flipped-180": "Flip 180°",
      "flipped-270": "Flip 270°"
    }
    return labels[t] || t
  }
}
