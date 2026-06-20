import QtQuick
import QtQuick.Layouts

OutputCard {
  id: root

  property var output
  property var pluginApi

  outputName: output.name
  isDisabled: output.enabled === "no"
  disabledText: pluginApi?.tr("panel.statusDisabled")

  Repeater {
    model: root.buildProperties()
    delegate: OutputProperty {
      Layout.fillWidth: true
      label: modelData.label
      value: modelData.value
    }
  }

  function buildProperties() {
    var props = []
    if (output.resolution) push(props, "panel.resolution", output.resolution)
    if (output.refreshRate) push(props, "panel.refreshRate", output.refreshRate)
    if (output.scale) push(props, "panel.scale", output.scale)
    if (output.transform && output.transform !== "normal") {
      push(props, "panel.transform", formatTransform(output.transform))
    }
    if (output.position) push(props, "panel.position", output.position)
    if (output.adaptiveSync) push(props, "panel.adaptiveSync", output.adaptiveSync)
    return props
  }

  function push(props, key, value) {
    props.push({ label: pluginApi?.tr(key), value: value })
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
