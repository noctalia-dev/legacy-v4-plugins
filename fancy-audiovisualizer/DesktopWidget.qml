import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.Media

DraggableDesktopWidget {
  id: root

  property var pluginApi: null

  implicitWidth: Math.round(300 * widgetScale)
  implicitHeight: Math.round(300 * widgetScale)

  showBackground: false

  // Scaled dimensions
  readonly property int scaledRadiusL: Math.round(Style.radiusL * widgetScale)

  // Settings from plugin
  readonly property real sensitivity: pluginApi?.pluginSettings?.sensitivity ?? pluginApi?.manifest?.metadata?.defaultSettings?.sensitivity
  readonly property real rotationSpeed: pluginApi?.pluginSettings?.rotationSpeed ?? pluginApi?.manifest?.metadata?.defaultSettings?.rotationSpeed
  readonly property real barWidth: pluginApi?.pluginSettings?.barWidth ?? pluginApi?.manifest?.metadata?.defaultSettings?.barWidth
  readonly property real ringOpacity: pluginApi?.pluginSettings?.ringOpacity ?? pluginApi?.manifest?.metadata?.defaultSettings?.ringOpacity
  readonly property real bloomIntensity: pluginApi.pluginSettings?.bloomIntensity ?? pluginApi?.manifest?.metadata?.defaultSettings?.bloomIntensity
  readonly property int visualizationMode: pluginApi?.pluginSettings?.visualizationMode ?? pluginApi?.manifest?.metadata?.defaultSettings?.visualizationMode ?? 3
  readonly property real waveThickness: pluginApi?.pluginSettings?.waveThickness ?? pluginApi?.manifest?.metadata?.defaultSettings?.waveThickness ?? 1.0
  readonly property real innerDiameter: pluginApi?.pluginSettings?.innerDiameter ?? pluginApi?.manifest?.metadata?.defaultSettings?.innerDiameter ?? 0.7
  readonly property bool fadeWhenIdle: pluginApi?.pluginSettings?.fadeWhenIdle ?? false
  readonly property bool useCustomColors: pluginApi?.pluginSettings?.useCustomColors ?? false
  readonly property color customPrimaryColor: pluginApi?.pluginSettings?.customPrimaryColor ?? "#6750A4"
  readonly property color customSecondaryColor: pluginApi?.pluginSettings?.customSecondaryColor ?? "#625B71"

  // Animation time for shader (0 to 3600, 1 hour cycle)
  property real shaderTime: 0
  NumberAnimation on shaderTime {
    loops: Animation.Infinite
    from: 0
    to: 3600
    duration: 3600000
    running: !SpectrumService.isIdle
  }

  // Hidden canvas that encodes audio data as a 32x1 texture
  Canvas {
    id: audioCanvas
    width: 32
    height: 1
    visible: false

    onPaint: {
      var ctx = getContext("2d");
      var values = SpectrumService.values;
      if (!values || values.length === 0) {
        ctx.fillStyle = "black";
        ctx.fillRect(0, 0, 32, 1);
        return;
      }
      for (var i = 0; i < 32; i++) {
        var v = values[i] || 0;
        // Encode amplitude in grayscale (R=G=B=amplitude)
        var c = Math.floor(v * 255);
        ctx.fillStyle = "rgb(" + c + "," + c + "," + c + ")";
        ctx.fillRect(i, 0, 1, 1);
      }
    }
  }

  // Trigger canvas repaint when audio data changes
  Connections {
    target: SpectrumService
    function onValuesChanged() {
      if (!SpectrumService.isIdle) {
        audioCanvas.requestPaint();
      }
    }
  }

  // Unique instance ID for SpectrumService registration
  // This prevents the old widget's destruction from unregistering the new widget
  readonly property string spectrumInstanceId: "plugin:fancy-audiovisualizer:" + Date.now() + Math.random()

  // Register with SpectrumService when pluginApi becomes available
  onPluginApiChanged: {
    if (pluginApi) {
      SpectrumService.registerComponent(spectrumInstanceId);
      audioCanvas.requestPaint();
    }
  }

  Component.onDestruction: {
    SpectrumService.unregisterComponent(spectrumInstanceId);
  }

  // Audio texture source (outside ShaderEffect to avoid 'source' property warning)
  ShaderEffectSource {
    id: audioTextureSource
    sourceItem: audioCanvas
    live: true
    hideSource: true
  }

  // The shader effect visualization
  ShaderEffect {
    id: visualizer
    anchors.fill: parent
    visible: pluginApi !== null
    opacity: (root.fadeWhenIdle && SpectrumService.isIdle) ? 0 : 1

    Behavior on opacity {
      NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
    }

    // Audio texture - named 'source' to match ShaderEffectSource's property and avoid warning
    property var source: audioTextureSource

    // Uniforms passed to shader
    property real time: root.shaderTime
    property real itemWidth: visualizer.width
    property real itemHeight: visualizer.height
    property color primaryColor: root.useCustomColors ? root.customPrimaryColor : Color.mPrimary
    property color secondaryColor: root.useCustomColors ? root.customSecondaryColor : Color.mSecondary
    property real sensitivity: root.sensitivity
    property real rotationSpeed: root.rotationSpeed
    property real barWidth: root.barWidth
    property real ringOpacity: root.ringOpacity
    property real cornerRadius: scaledRadiusL
    property real bloomIntensity: root.bloomIntensity
    property real visualizationMode: root.visualizationMode
    property real waveThickness: root.waveThickness
    property real innerDiameter: root.innerDiameter

    fragmentShader: pluginApi ? Qt.resolvedUrl(pluginApi.pluginDir + "/shaders/visualizer.frag.qsb") : ""
  }

  // Fallback when shader not loaded
  Rectangle {
    anchors.fill: parent
    color: Color.mSurface
    radius: scaledRadiusL
    visible: !visualizer.visible || visualizer.fragmentShader === ""

    Text {
      anchors.centerIn: parent
      text: "Loading..."
      color: Color.mOnSurface
      font.pointSize: Math.round(Style.fontSizeM * widgetScale)
    }
  }
}
