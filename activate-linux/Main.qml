import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.System

// Adapted from https://git.outfoxxed.me/quickshell/quickshell-examples/src/branch/master/activate_linux

Item {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string osName: HostService?.osPretty || "Linux"

  readonly property string firstLine:
    (cfg.customizeText ?? defaults.customizeText ?? false) ?
    (cfg.firstLine ?? defaults.firstLine ?? "Activate Linux") :
    (pluginApi?.tr("panel.activate", { osName: root.osName }) || `Activate ${root.osName}`)

  readonly property string secondLine:
    (cfg.customizeText ?? defaults.customizeText ?? false) ?
    (cfg.secondLine ?? defaults.secondLine ?? "Go to Settings to activate Linux.") :
    (pluginApi?.tr("panel.goto_settings", { osName: root.osName }) || `Go to Settings to activate ${root.osName}.`)

  readonly property int firstLineSize: cfg.firstLineSize ?? defaults.firstLineSize ?? 22
  readonly property int secondLineSize: cfg.secondLineSize ?? defaults.secondLineSize ?? 14
  readonly property int marginRight: cfg.marginRight ?? defaults.marginRight ?? 50
  readonly property int marginBottom: cfg.marginBottom ?? defaults.marginBottom ?? 50

  Variants {
    model: Quickshell.screens // Display on all screens

    PanelWindow {

      anchors { right: true; bottom: true }
      margins { right: root.marginRight; bottom: root.marginBottom }

      implicitWidth: content.width
      implicitHeight: content.height

      color: "transparent"

      // Give the window an empty click mask so all clicks pass through it.
      mask: Region {}
      WlrLayershell.layer: WlrLayer.Overlay

      ColumnLayout {
        id: content

        NText {
          text: firstLine
          color: "#50ffffff"
          pointSize: root.firstLineSize
        }

        NText {
          text: secondLine
          color: "#50ffffff"
          pointSize: root.secondLineSize
        }
      }
    }
  }
}
