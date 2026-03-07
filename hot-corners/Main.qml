import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root
  property var pluginApi: null

  readonly property var cornerPos: ({
    TopLeft: "TopLeft",
    TopRight: "TopRight",
    BottomLeft: "BottomLeft",
    BottomRight: "BottomRight"
  })

  // Read settings
  property var currentSettings: pluginApi ? pluginApi.pluginSettings : {}


  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      root.currentSettings = pluginApi.pluginSettings;
    }
  }

  // Configuration properties
  property int cornerSize: 5
  property int triggerDelayMs: 200 // Slight delay to prevent accidental triggers



  function executeAction(cornerId, screen) {

    
    var command = root.currentSettings?.corners?.[cornerId];
    if (!command || command === "") return;

    var args = command.split(" ").filter(function(arg) { return arg.length > 0; });
    if (args.length > 0) {
      var proc = Qt.createQmlObject('import Quickshell.Io; Process { }', root, 'CustomCommandProcess' + Date.now());
      proc.command = ["bash", "-c", command];
      proc.exited.connect(function() { proc.destroy(); });
      proc.running = true;
    }
  }

  component CornerTrigger: MouseArea {
    property string cornerId: ""
    property color debugColor: "red"
    property var screenData: null
    
    anchors.fill: parent
    hoverEnabled: true

    Timer {
      id: hoverTimer
      interval: root.triggerDelayMs
      repeat: false
      onTriggered: {
        root.executeAction(parent.cornerId, parent.screenData);
      }
    }

    onEntered: {
      hoverTimer.start();
    }

    onExited: {
      hoverTimer.stop();
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      exclusionMode: ExclusionMode.Ignore
      anchors { top: true; left: true }
      implicitWidth: root.cornerSize
      implicitHeight: root.cornerSize
      color: "transparent"
      visible: !!root.currentSettings?.corners?.[root.cornerPos.TopLeft]

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region { item: tlTrigger }

      CornerTrigger {
        id: tlTrigger
        cornerId: root.cornerPos.TopLeft
        debugColor: "red"
        screenData: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      exclusionMode: ExclusionMode.Ignore
      anchors { top: true; right: true }
      implicitWidth: root.cornerSize
      implicitHeight: root.cornerSize
      color: "transparent"
      visible: !!root.currentSettings?.corners?.[root.cornerPos.TopRight]

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region { item: trTrigger }

      CornerTrigger {
        id: trTrigger
        cornerId: root.cornerPos.TopRight
        debugColor: "blue"
        screenData: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      exclusionMode: ExclusionMode.Ignore
      anchors { bottom: true; left: true }
      implicitWidth: root.cornerSize
      implicitHeight: root.cornerSize
      color: "transparent"
      visible: !!root.currentSettings?.corners?.[root.cornerPos.BottomLeft]

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region { item: blTrigger }

      CornerTrigger {
        id: blTrigger
        cornerId: root.cornerPos.BottomLeft
        debugColor: "yellow"
        screenData: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      exclusionMode: ExclusionMode.Ignore
      anchors { bottom: true; right: true }
      implicitWidth: root.cornerSize
      implicitHeight: root.cornerSize
      color: "transparent"
      visible: !!root.currentSettings?.corners?.[root.cornerPos.BottomRight]

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region { item: brTrigger }

      CornerTrigger {
        id: brTrigger
        cornerId: root.cornerPos.BottomRight
        debugColor: "purple"
        screenData: modelData
      }
    }
  }
}
