import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var pluginApi: null

  property var lights: []
  
  function getLights() {
    return lights
  }

  function setLightOnState(id, state) {
    const command = ["openhue", "set", "light"]
    command.push(id)
    command.push(state ? "--on" : "--off")

    // Only update command field if it's different from last one
    if (setter.command !== command) {
      setter.command = command
    }

    setter.running = true
  }

  function setLightBrightness(id, value) {
    const command = ["openhue", "set", "light"]
    command.push(id)
    command.push("--brightness", String(Math.round(value)))

    // Only update command field if it's different from last one
    if (setter.command !== command) {
      setter.command = command
    }

    setter.running = true
  }

  function refresh() {
    if (!getLights.running) {
      getLights.running = true
    }
  }

  Process {
    id: getLights
    command: ["openhue", "get", "lights", "--json"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        let data = [];
        for (const light of JSON.parse(text)) {
          data.push({
            id: light.HueData.id,
            name: light.HueData.metadata.name,
            brightness: light.HueData.dimming.brightness,
            on: light.HueData.on.on
          });
        }
        root.lights = data;
      }
    }
  }

  Process {
    id: setter
    running: false
    onStarted: {
      console.log("Running setter command: ", command)
    }
    onExited: {
      refresh()
    }
  }

  Component.onCompleted: {
    refresh()
  }
}
