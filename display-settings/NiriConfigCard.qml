import QtQuick
import QtQuick.Layouts

OutputCard {
  id: root

  property var output
  property var pluginApi

  headerIcon: "file-code"
  outputName: output.name
  isDisabled: !output.enabled
  disabledText: pluginApi?.tr("panel.statusOff")

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
    if (output.mode) push(props, "panel.mode", output.mode)
    if (output.scale) push(props, "panel.scale", output.scale)
    if (output.transform) push(props, "panel.transform", output.transform)
    if (output.position) push(props, "panel.position", output.position)
    if (!output.enabled) push(props, "panel.enabled", pluginApi?.tr("panel.off"))
    if (output.vrr) push(props, "panel.vrr", output.vrr)
    return props
  }

  function push(props, key, value) {
    props.push({ label: pluginApi?.tr(key), value: value })
  }
}
