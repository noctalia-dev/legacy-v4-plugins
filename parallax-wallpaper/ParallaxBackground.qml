import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.Power
import qs.Services.UI

Variants {
  id: backgroundVariants
  model: Quickshell.screens

  property var pluginApi

  delegate: Loader {

    required property ShellScreen modelData

    active: modelData && (!PowerProfileService.noctaliaPerformanceMode || !Settings.data.noctaliaPerformance.disableWallpaper)

    sourceComponent: PanelWindow {
      id: root

      // ── Plugin settings ──

      property var cfg: backgroundVariants.pluginApi?.pluginSettings || ({})
      property var defaults: backgroundVariants.pluginApi?.manifest?.metadata?.defaultSettings || ({})

      readonly property real zoomAmount: cfg.zoomAmount ?? defaults.zoomAmount ?? 1.1
      readonly property string parallaxDirection: cfg.parallaxDirection ?? defaults.parallaxDirection ?? "horizontal"
      readonly property bool enableHorizontal: parallaxDirection === "horizontal" || parallaxDirection === "both"
      readonly property bool enableVertical: parallaxDirection === "vertical" || parallaxDirection === "both"
      readonly property real hParallaxAmount: cfg.hParallaxAmount ?? defaults.hParallaxAmount ?? 50
      readonly property int hParallaxDuration: cfg.hParallaxDuration ?? defaults.hParallaxDuration ?? 400
      readonly property real vParallaxAmount: cfg.vParallaxAmount ?? defaults.vParallaxAmount ?? 50
      readonly property int vParallaxDuration: cfg.vParallaxDuration ?? defaults.vParallaxDuration ?? 400
      readonly property bool invertDirection: cfg.invertDirection ?? defaults.invertDirection ?? false
      readonly property bool autoZoom: cfg.autoZoom ?? defaults.autoZoom ?? false
      readonly property string parallaxEasingStr: cfg.parallaxEasing ?? defaults.parallaxEasing ?? "OutCubic"

      // ── Parallax state ──

      property real parallaxX: 0
      property real parallaxY: 0

      onHParallaxAmountChanged: updateParallax()
      onVParallaxAmountChanged: updateParallax()
      onEnableHorizontalChanged: updateParallax()
      onEnableVerticalChanged: updateParallax()
      onInvertDirectionChanged: updateParallax()

      function getEasingType() {
        switch(parallaxEasingStr) {
          case "Linear": return Easing.Linear;
          case "InQuad": return Easing.InQuad;
          case "OutQuad": return Easing.OutQuad;
          case "InOutQuad": return Easing.InOutQuad;
          case "InCubic": return Easing.InCubic;
          case "OutCubic": return Easing.OutCubic;
          case "InOutCubic": return Easing.InOutCubic;
          case "InQuart": return Easing.InQuart;
          case "OutQuart": return Easing.OutQuart;
          case "InOutQuart": return Easing.InOutQuart;
          case "InExpo": return Easing.InExpo;
          case "OutExpo": return Easing.OutExpo;
          case "InOutExpo": return Easing.InOutExpo;
          default: return Easing.OutCubic;
        }
      }

      Behavior on parallaxX {
        NumberAnimation {
          duration: root.hParallaxDuration
          easing.type: root.getEasingType()
        }
      }

      Behavior on parallaxY {
        NumberAnimation {
          duration: root.vParallaxDuration
          easing.type: root.getEasingType()
        }
      }

      // ── Wallpaper transition state ──

      property string transitionType: "fade"
      property real transitionProgress: 0
      property bool isStartupTransition: true
      property bool wallpaperReady: false

      visible: wallpaperReady

      readonly property real edgeSmoothness: Settings.data.wallpaper.transitionEdgeSmoothness
      readonly property var allTransitions: WallpaperService.allTransitions
      readonly property bool transitioning: transitionAnimation.running

      // Wipe direction: 0=left, 1=right, 2=up, 3=down
      property real wipeDirection: 0

      // Disc
      property real discCenterX: 0.5
      property real discCenterY: 0.5

      // Stripe
      property real stripesCount: 16
      property real stripesAngle: 0

      // Pixelate
      property real pixelateMaxBlockSize: 64.0

      // Honeycomb
      property real honeycombCellSize: 0.04
      property real honeycombCenterX: 0.5
      property real honeycombCenterY: 0.5

      property string futureWallpaper: ""
      property string transitioningToOriginalPath: ""

      property real fillMode: WallpaperService.getFillModeUniform()
      property vector4d fillColor: Qt.vector4d(Settings.data.wallpaper.fillColor.r, Settings.data.wallpaper.fillColor.g, Settings.data.wallpaper.fillColor.b, 1.0)

      property bool isSolid1: false
      property bool isSolid2: false
      property color _solidColor1: Settings.data.wallpaper.solidColor
      property color _solidColor2: Settings.data.wallpaper.solidColor
      property vector4d solidColor1: Qt.vector4d(_solidColor1.r, _solidColor1.g, _solidColor1.b, 1.0)
      property vector4d solidColor2: Qt.vector4d(_solidColor2.r, _solidColor2.g, _solidColor2.b, 1.0)

      Component.onCompleted: {
        setWallpaperInitial();
        updateParallax();
      }

      // ── Parallax logic ──

      function updateParallax() {
        var wsId = 1;
        for (var i = 0; i < CompositorService.workspaces.count; i++) {
          var ws = CompositorService.workspaces.get(i);
          if (ws.isActive) {
            if (ws.output === modelData.name || !ws.output) {
              wsId = ws.id;
              break;
            }
          }
        }

        var factor = root.invertDirection ? 1 : -1;
        var rawH = (wsId - 1) * root.hParallaxAmount * factor;
        var rawV = (wsId - 1) * root.vParallaxAmount * factor;

        root.parallaxX = root.enableHorizontal ? rawH : 0;
        root.parallaxY = root.enableVertical ? rawV : 0;
      }

      Connections {
        target: CompositorService
        function onWorkspaceChanged() {
          root.updateParallax();
        }
        function onDisplayScalesChanged() {
          if (!WallpaperService.isInitialized) {
            return;
          }

          const currentPath = WallpaperService.getWallpaper(modelData.name);
          if (!currentPath || WallpaperService.isSolidColorPath(currentPath)) {
            return;
          }

          if (isStartupTransition) {
            const compositorScale = CompositorService.getDisplayScale(modelData.name);
            const targetWidth = Math.round(modelData.width * compositorScale);
            const targetHeight = Math.round(modelData.height * compositorScale);
            ImageCacheService.getLarge(currentPath, targetWidth, targetHeight, function (cachedPath, success) {
              WallpaperService.wallpaperProcessingComplete(modelData.name, currentPath, success ? cachedPath : "");
            });
            return;
          }

          requestPreprocessedWallpaper(currentPath);
        }
      }

      Component.onDestruction: {
        transitionAnimation.stop();
        startupTransitionTimer.stop();
        debounceTimer.stop();
        shaderLoader.active = false;
        currentWallpaper.source = "";
        nextWallpaper.source = "";
      }

      Connections {
        target: Settings.data.wallpaper
        function onFillModeChanged() {
          fillMode = WallpaperService.getFillModeUniform();
        }
      }

      Connections {
        target: WallpaperService
        function onWallpaperChanged(screenName, path) {
          if (screenName === modelData.name) {
            requestPreprocessedWallpaper(path);
          }
        }
      }

      color: "transparent"
      screen: modelData
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "noctalia-parallax-" + (screen?.name || "unknown")

      anchors {
        bottom: true
        top: true
        right: true
        left: true
      }

      Timer {
        id: debounceTimer
        interval: 333
        running: false
        repeat: false
        onTriggered: changeWallpaper()
      }

      // Delay startup transition until compositor maps the window
      Timer {
        id: startupTransitionTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: _executeStartupTransition()
      }

      Image {
        id: currentWallpaper

        source: ""
        smooth: true
        mipmap: false
        visible: false
        cache: true
        asynchronous: true
        onStatusChanged: {
          if (status === Image.Error) {
            Logger.w("Parallax Wallpaper", "Current wallpaper failed to load:", source);
          } else if (status === Image.Ready && !wallpaperReady) {
            wallpaperReady = true;
          }
        }
      }

      Image {
        id: nextWallpaper

        property bool pendingTransition: false

        source: ""
        smooth: true
        mipmap: false
        visible: false
        cache: false
        asynchronous: true
        onStatusChanged: {
          if (status === Image.Error) {
            Logger.w("Parallax Wallpaper", "Next wallpaper failed to load:", source);
            pendingTransition = false;
          } else if (status === Image.Ready) {
            if (!wallpaperReady) {
              wallpaperReady = true;
            }
            if (pendingTransition) {
              pendingTransition = false;
              currentWallpaper.asynchronous = false;
              transitionAnimation.start();
            }
          }
        }
      }

      // Shader loader with parallax transform
      Loader {
        id: shaderLoader
        anchors.fill: parent
        active: true

        scale: {
          if (!root.autoZoom) return root.zoomAmount;
          var ax = 2 * Math.abs(root.parallaxX);
          var ay = 2 * Math.abs(root.parallaxY);
          var zx = (width > ax) ? width / (width - ax) : root.zoomAmount;
          var zy = (height > ay) ? height / (height - ay) : root.zoomAmount;
          return Math.max(root.zoomAmount, zx, zy);
        }
        transform: Translate {
          x: root.parallaxX
          y: root.parallaxY
        }

        sourceComponent: {
          switch (transitionType) {
          case "wipe":
            return wipeShaderComponent;
          case "disc":
            return discShaderComponent;
          case "stripes":
            return stripesShaderComponent;
          case "pixelate":
            return pixelateShaderComponent;
          case "honeycomb":
            return honeycombShaderComponent;
          case "fade":
          case "none":
          default:
            return fadeShaderComponent;
          }
        }
      }

      // Fade/None transition
      Component {
        id: fadeShaderComponent
        ShaderEffect {
          anchors.fill: parent

          property variant source1: currentWallpaper
          property variant source2: nextWallpaper
          property real progress: root.transitionProgress

          property real fillMode: root.fillMode
          property vector4d fillColor: root.fillColor
          property real imageWidth1: source1.sourceSize.width
          property real imageHeight1: source1.sourceSize.height
          property real imageWidth2: source2.sourceSize.width
          property real imageHeight2: source2.sourceSize.height
          property real screenWidth: width
          property real screenHeight: height

          property real isSolid1: root.isSolid1 ? 1.0 : 0.0
          property real isSolid2: root.isSolid2 ? 1.0 : 0.0
          property vector4d solidColor1: root.solidColor1
          property vector4d solidColor2: root.solidColor2

          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_fade.frag.qsb")
        }
      }

      // Wipe transition
      Component {
        id: wipeShaderComponent
        ShaderEffect {
          anchors.fill: parent

          property variant source1: currentWallpaper
          property variant source2: nextWallpaper
          property real progress: root.transitionProgress
          property real smoothness: root.edgeSmoothness
          property real direction: root.wipeDirection

          property real fillMode: root.fillMode
          property vector4d fillColor: root.fillColor
          property real imageWidth1: source1.sourceSize.width
          property real imageHeight1: source1.sourceSize.height
          property real imageWidth2: source2.sourceSize.width
          property real imageHeight2: source2.sourceSize.height
          property real screenWidth: width
          property real screenHeight: height

          property real isSolid1: root.isSolid1 ? 1.0 : 0.0
          property real isSolid2: root.isSolid2 ? 1.0 : 0.0
          property vector4d solidColor1: root.solidColor1
          property vector4d solidColor2: root.solidColor2

          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_wipe.frag.qsb")
        }
      }

      // Disc transition
      Component {
        id: discShaderComponent
        ShaderEffect {
          anchors.fill: parent

          property variant source1: currentWallpaper
          property variant source2: nextWallpaper
          property real progress: root.transitionProgress
          property real smoothness: root.edgeSmoothness
          property real aspectRatio: root.width / root.height
          property real centerX: root.discCenterX
          property real centerY: root.discCenterY

          property real fillMode: root.fillMode
          property vector4d fillColor: root.fillColor
          property real imageWidth1: source1.sourceSize.width
          property real imageHeight1: source1.sourceSize.height
          property real imageWidth2: source2.sourceSize.width
          property real imageHeight2: source2.sourceSize.height
          property real screenWidth: width
          property real screenHeight: height

          property real isSolid1: root.isSolid1 ? 1.0 : 0.0
          property real isSolid2: root.isSolid2 ? 1.0 : 0.0
          property vector4d solidColor1: root.solidColor1
          property vector4d solidColor2: root.solidColor2

          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_disc.frag.qsb")
        }
      }

      // Stripes transition
      Component {
        id: stripesShaderComponent
        ShaderEffect {
          anchors.fill: parent

          property variant source1: currentWallpaper
          property variant source2: nextWallpaper
          property real progress: root.transitionProgress
          property real smoothness: root.edgeSmoothness
          property real aspectRatio: root.width / root.height
          property real stripeCount: root.stripesCount
          property real angle: root.stripesAngle

          property real fillMode: root.fillMode
          property vector4d fillColor: root.fillColor
          property real imageWidth1: source1.sourceSize.width
          property real imageHeight1: source1.sourceSize.height
          property real imageWidth2: source2.sourceSize.width
          property real imageHeight2: source2.sourceSize.height
          property real screenWidth: width
          property real screenHeight: height

          property real isSolid1: root.isSolid1 ? 1.0 : 0.0
          property real isSolid2: root.isSolid2 ? 1.0 : 0.0
          property vector4d solidColor1: root.solidColor1
          property vector4d solidColor2: root.solidColor2

          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_stripes.frag.qsb")
        }
      }

      // Pixelate transition
      Component {
        id: pixelateShaderComponent
        ShaderEffect {
          anchors.fill: parent

          property variant source1: currentWallpaper
          property variant source2: nextWallpaper
          property real progress: root.transitionProgress
          property real maxBlockSize: root.pixelateMaxBlockSize

          property real fillMode: root.fillMode
          property vector4d fillColor: root.fillColor
          property real imageWidth1: source1.sourceSize.width
          property real imageHeight1: source1.sourceSize.height
          property real imageWidth2: source2.sourceSize.width
          property real imageHeight2: source2.sourceSize.height
          property real screenWidth: width
          property real screenHeight: height

          property real isSolid1: root.isSolid1 ? 1.0 : 0.0
          property real isSolid2: root.isSolid2 ? 1.0 : 0.0
          property vector4d solidColor1: root.solidColor1
          property vector4d solidColor2: root.solidColor2

          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_pixelate.frag.qsb")
        }
      }

      // Honeycomb transition
      Component {
        id: honeycombShaderComponent
        ShaderEffect {
          anchors.fill: parent

          property variant source1: currentWallpaper
          property variant source2: nextWallpaper
          property real progress: root.transitionProgress
          property real cellSize: root.honeycombCellSize
          property real centerX: root.honeycombCenterX
          property real centerY: root.honeycombCenterY
          property real aspectRatio: root.width / root.height

          property real fillMode: root.fillMode
          property vector4d fillColor: root.fillColor
          property real imageWidth1: source1.sourceSize.width
          property real imageHeight1: source1.sourceSize.height
          property real imageWidth2: source2.sourceSize.width
          property real imageHeight2: source2.sourceSize.height
          property real screenWidth: width
          property real screenHeight: height

          property real isSolid1: root.isSolid1 ? 1.0 : 0.0
          property real isSolid2: root.isSolid2 ? 1.0 : 0.0
          property vector4d solidColor1: root.solidColor1
          property vector4d solidColor2: root.solidColor2

          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/wp_honeycomb.frag.qsb")
        }
      }

      NumberAnimation {
        id: transitionAnimation
        target: root
        property: "transitionProgress"
        from: 0.0
        to: 1.0
        duration: Settings.data.wallpaper.transitionDuration
        easing.type: Easing.InOutCubic
        onFinished: {
          transitioningToOriginalPath = "";

          isSolid1 = isSolid2;
          _solidColor1 = _solidColor2;

          const tempSource = nextWallpaper.source;
          currentWallpaper.source = tempSource;
          transitionProgress = 0.0;

          Qt.callLater(() => {
                         nextWallpaper.source = "";
                         isSolid2 = false;
                         Qt.callLater(() => {
                                        currentWallpaper.asynchronous = true;
                                      });
                       });
        }
      }

      function _pathStr(p) {
        var s = p.toString();
        if (s.startsWith("file://")) {
          return s.substring(7);
        }
        return s;
      }

      function setWallpaperInitial() {
        if (!WallpaperService || !WallpaperService.isInitialized) {
          Qt.callLater(setWallpaperInitial);
          return;
        }
        if (!ImageCacheService || !ImageCacheService.initialized) {
          Qt.callLater(setWallpaperInitial);
          return;
        }

        if (Settings.data.wallpaper.useSolidColor) {
          var solidPath = WallpaperService.createSolidColorPath(Settings.data.wallpaper.solidColor.toString());
          futureWallpaper = solidPath;
          performStartupTransition();
          WallpaperService.wallpaperProcessingComplete(modelData.name, solidPath, "");
          return;
        }

        const wallpaperPath = WallpaperService.getWallpaper(modelData.name);

        if (WallpaperService.isSolidColorPath(wallpaperPath)) {
          futureWallpaper = wallpaperPath;
          performStartupTransition();
          WallpaperService.wallpaperProcessingComplete(modelData.name, wallpaperPath, "");
          return;
        }

        const compositorScale = CompositorService.getDisplayScale(modelData.name);
        const targetWidth = Math.round(modelData.width * compositorScale);
        const targetHeight = Math.round(modelData.height * compositorScale);

        ImageCacheService.getLarge(wallpaperPath, targetWidth, targetHeight, function (cachedPath, success) {
          if (success) {
            futureWallpaper = cachedPath;
          } else {
            futureWallpaper = wallpaperPath;
          }
          performStartupTransition();
          WallpaperService.wallpaperProcessingComplete(modelData.name, wallpaperPath, success ? cachedPath : "");
        });
      }

      function requestPreprocessedWallpaper(originalPath) {
        if (transitioning && originalPath === transitioningToOriginalPath) {
          return;
        }

        transitioningToOriginalPath = originalPath;

        if (WallpaperService.isSolidColorPath(originalPath)) {
          futureWallpaper = originalPath;
          debounceTimer.restart();
          WallpaperService.wallpaperProcessingComplete(modelData.name, originalPath, "");
          return;
        }

        const compositorScale = CompositorService.getDisplayScale(modelData.name);
        const targetWidth = Math.round(modelData.width * compositorScale);
        const targetHeight = Math.round(modelData.height * compositorScale);

        ImageCacheService.getLarge(originalPath, targetWidth, targetHeight, function (cachedPath, success) {
          if (originalPath !== transitioningToOriginalPath) {
            return;
          }
          if (success) {
            futureWallpaper = cachedPath;
          } else {
            futureWallpaper = originalPath;
          }

          if (_pathStr(futureWallpaper) === _pathStr(currentWallpaper.source)) {
            transitioningToOriginalPath = "";
            WallpaperService.wallpaperProcessingComplete(modelData.name, originalPath, success ? cachedPath : "");
            return;
          }

          debounceTimer.restart();
          WallpaperService.wallpaperProcessingComplete(modelData.name, originalPath, success ? cachedPath : "");
        });
      }

      function setWallpaperImmediate(source) {
        transitionAnimation.stop();
        transitionProgress = 0.0;

        var isSolidSource = WallpaperService.isSolidColorPath(source);
        isSolid1 = isSolidSource;
        isSolid2 = false;

        if (isSolidSource) {
          var colorStr = WallpaperService.getSolidColor(source);
          _solidColor1 = colorStr;
          currentWallpaper.source = "";
          nextWallpaper.source = "";
          if (!wallpaperReady) {
            wallpaperReady = true;
          }
          return;
        }

        nextWallpaper.source = "";
        nextWallpaper.sourceSize = undefined;

        currentWallpaper.source = "";

        Qt.callLater(() => {
                       currentWallpaper.source = source;
                     });
      }

      function setWallpaperWithTransition(source) {
        var isSolidSource = WallpaperService.isSolidColorPath(source);

        if (isSolidSource && isSolid1) {
          var newColor = WallpaperService.getSolidColor(source);
          if (newColor === _solidColor1.toString()) {
            return;
          }
        }

        if (!isSolidSource && _pathStr(source) === _pathStr(currentWallpaper.source)) {
          return;
        }

        if (transitioning && source === nextWallpaper.source) {
          return;
        }

        if (transitioning) {
          transitionAnimation.stop();
          transitionProgress = 0;

          isSolid1 = isSolid2;
          _solidColor1 = _solidColor2;
          const newCurrentSource = nextWallpaper.source;
          currentWallpaper.source = newCurrentSource;

          Qt.callLater(() => {
                         nextWallpaper.source = "";
                         isSolid2 = false;

                         Qt.callLater(() => {
                                        _startTransitionTo(source, isSolidSource);
                                      });
                       });
          return;
        }

        _startTransitionTo(source, isSolidSource);
      }

      function _startTransitionTo(source, isSolidSource) {
        isSolid2 = isSolidSource;

        if (isSolidSource) {
          var colorStr = WallpaperService.getSolidColor(source);
          _solidColor2 = colorStr;
          nextWallpaper.source = "";
          if (!wallpaperReady) {
            wallpaperReady = true;
          }
          currentWallpaper.asynchronous = false;
          transitionAnimation.start();
        } else {
          nextWallpaper.source = source;
          if (nextWallpaper.status === Image.Ready) {
            if (!wallpaperReady) {
              wallpaperReady = true;
            }
            currentWallpaper.asynchronous = false;
            transitionAnimation.start();
          } else {
            nextWallpaper.pendingTransition = true;
          }
        }
      }

      function changeWallpaper() {
        transitionType = Settings.data.wallpaper.transitionType;

        if (transitionType == "random") {
          var index = Math.floor(Math.random() * allTransitions.length);
          transitionType = allTransitions[index];
        }

        if (transitionType !== "none" && !allTransitions.includes(transitionType)) {
          transitionType = "fade";
        }

        switch (transitionType) {
        case "none":
          setWallpaperImmediate(futureWallpaper);
          break;
        case "wipe":
          wipeDirection = Math.random() * 4;
          setWallpaperWithTransition(futureWallpaper);
          break;
        case "disc":
          discCenterX = Math.random();
          discCenterY = Math.random();
          setWallpaperWithTransition(futureWallpaper);
          break;
        case "stripes":
          stripesCount = Math.round(Math.random() * 20 + 4);
          stripesAngle = Math.random() * 360;
          setWallpaperWithTransition(futureWallpaper);
          break;
        case "pixelate":
          pixelateMaxBlockSize = Math.round(Math.random() * 80 + 32);
          setWallpaperWithTransition(futureWallpaper);
          break;
        case "honeycomb":
          honeycombCellSize = Math.random() * 0.04 + 0.02;
          honeycombCenterX = Math.random();
          honeycombCenterY = Math.random();
          setWallpaperWithTransition(futureWallpaper);
          break;
        default:
          setWallpaperWithTransition(futureWallpaper);
          break;
        }
      }

      function performStartupTransition() {
        if (Settings.data.wallpaper.skipStartupTransition) {
          setWallpaperImmediate(futureWallpaper);
          isStartupTransition = false;
          return;
        }

        transitionType = Settings.data.wallpaper.transitionType;

        if (transitionType == "random") {
          var index = Math.floor(Math.random() * allTransitions.length);
          transitionType = allTransitions[index];
        }

        if (transitionType !== "none" && !allTransitions.includes(transitionType)) {
          transitionType = "fade";
        }

        switch (transitionType) {
        case "wipe":
          wipeDirection = Math.random() * 4;
          break;
        case "disc":
          discCenterX = 0.5;
          discCenterY = 0.5;
          break;
        case "stripes":
          stripesCount = Math.round(Math.random() * 20 + 4);
          stripesAngle = Math.random() * 360;
          break;
        case "pixelate":
          pixelateMaxBlockSize = 64.0;
          break;
        case "honeycomb":
          honeycombCellSize = 0.04;
          honeycombCenterX = 0.5;
          honeycombCenterY = 0.5;
          break;
        }

        startupTransitionTimer.start();
      }

      function _executeStartupTransition() {
        if (transitionType === "none") {
          setWallpaperImmediate(futureWallpaper);
        } else {
          setWallpaperWithTransition(futureWallpaper);
        }
        isStartupTransition = false;
      }
    }
  }
}
