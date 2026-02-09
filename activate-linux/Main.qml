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
  readonly property string osName: HostService?.osPretty || "Linux"

  readonly property string firstLine:
    (pluginApi?.pluginSettings?.customizeText || pluginApi?.manifest?.metadata?.defaultSettings?.customizeText || false) ?
    (pluginApi?.pluginSettings?.firstLine || pluginApi?.manifest?.metadata?.defaultSettings?.firstLine || "Activate Linux") :
    (pluginApi?.tr("panel.activate", { osName: root.osName }) || `Activate ${root.osName}`)

  readonly property string secondLine:
    (pluginApi?.pluginSettings?.customizeText || pluginApi?.manifest?.metadata?.defaultSettings?.customizeText || false) ?
    (pluginApi?.pluginSettings?.secondLine || pluginApi?.manifest?.metadata?.defaultSettings?.secondLine || "Go to Settings to activate Linux.") :
    (pluginApi?.tr("panel.goto_settings", { osName: root.osName }) || `Go to Settings to activate ${root.osName}.`)

  Variants {
    model: Quickshell.screens // Display on all screens

    PanelWindow {

      anchors { right: true; bottom: true }
      margins { right: 50; bottom: 50 }

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
          pointSize: 22
        }

        NText {
          text: secondLine
          color: "#50ffffff"
          pointSize: 14
        }
      }
    }
  }
}

