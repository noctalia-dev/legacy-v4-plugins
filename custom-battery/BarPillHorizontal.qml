import QtQuick
import QtQuick.Controls

import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  required property ShellScreen screen

  property string icon: ""
  property string iconSource: ""
  property string text: ""
  property string suffix: ""
  property var tooltipText: null
  property bool autoHide: false
  property bool forceOpen: false
  property bool forceClose: false
  property bool oppositeDirection: false
  property bool hovered: false
  property color customBackgroundColor: "transparent"
  property color customTextIconColor: "transparent"
  property color customIconColor: "transparent"
  property bool textInsideIcon: false
  property bool transparentBackground: false
  property bool charging: false
  property bool isPowerSaver: false
  property bool isVertical: false

  readonly property bool collapseToIcon: forceClose && !forceOpen

  readonly property bool revealed: !forceClose && (forceOpen || showPill)
  readonly property bool hasIcon: root.icon !== "" || root.iconSource !== ""

  signal shown
  signal hidden
  signal entered
  signal exited
  signal clicked
  signal rightClicked
  signal middleClicked
  signal wheel(int delta)

  property bool showPill: false
  property bool shouldAnimateHide: false

  readonly property int pillHeight: Style.getCapsuleHeightForScreen(screen?.name)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screen?.name)
  readonly property int pillPaddingHorizontal: Math.round(pillHeight * 0.2)
  readonly property int pillOverlap: Math.round(pillHeight * 0.5)
  readonly property int pillMaxWidth: textInsideIcon ? 0 : Math.max(1, Math.round(textItem.implicitWidth + pillPaddingHorizontal * 2 + pillOverlap))

  readonly property color bgColor: {
    if (transparentBackground) return "transparent";
    if (hovered && !textInsideIcon) return Color.mHover;
    if (customBackgroundColor.a > 0) return customBackgroundColor;
    return Style.capsuleColor;
  }
  readonly property color fgColor: hovered ? Color.mOnHover : (customTextIconColor.a > 0) ? customTextIconColor : Color.mOnSurface

  readonly property real iconSize: Style.toOdd(pillHeight * 0.48)

  readonly property real baseIconWidth: hasIcon ? (root.iconSource !== "" ? Math.round(36 * (pillHeight * 0.75 / 24)) + Math.round(pillHeight * 0.45) : pillHeight) : 0

  readonly property real contentWidth: {
    if (collapseToIcon) {
      return baseIconWidth;
    }
    var overlap = hasIcon ? pillOverlap : 0;
    return baseIconWidth + Math.max(0, pill.width - overlap);
  }

  anchors.fill: parent
  implicitWidth: root.isVertical ? pillHeight : contentWidth
  implicitHeight: root.isVertical ? baseIconWidth : pillHeight

  Connections {
    target: root
    function onTooltipTextChanged() {
      if (hovered) {
        TooltipService.updateText(root.tooltipText);
      }
    }
  }

  Rectangle {
    id: pillBackground
    width: root.isVertical ? root.pillHeight : (collapseToIcon ? baseIconWidth : root.width)
    height: root.isVertical ? baseIconWidth : pillHeight
    radius: Style.radiusM
    color: root.bgColor
    anchors.centerIn: parent
    border.color: Style.capsuleBorderColor
    border.width: 0


    Behavior on color {
      enabled: !Color.isTransitioning
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    id: pill

    width: revealed ? pillMaxWidth : 1
    height: pillHeight

    x: {
      if (!hasIcon)
        return 0;
      return oppositeDirection ? (iconCircle.x + iconCircle.width / 2) : (iconCircle.x + iconCircle.width / 2) - width;
    }

    opacity: revealed ? Style.opacityFull : Style.opacityNone
    color: "transparent" // Make pill background transparent to avoid double opacity

    topLeftRadius: oppositeDirection ? 0 : Style.radiusM
    bottomLeftRadius: oppositeDirection ? 0 : Style.radiusM
    topRightRadius: oppositeDirection ? Style.radiusM : 0
    bottomRightRadius: oppositeDirection ? Style.radiusM : 0
    anchors.verticalCenter: parent.verticalCenter

    NText {
      id: textItem
      anchors.verticalCenter: parent.verticalCenter
      x: {
        if (!hasIcon)
          return (parent.width - width) / 2;

        var centerX = (parent.width - width) / 2;
        var offset = oppositeDirection ? Style.marginXS : -Style.marginXS;
        if (forceOpen) {
          offset += oppositeDirection ? -Style.marginXXS : Style.marginXXS;
        }
        return centerX + offset;
      }
      text: root.text + root.suffix
      family: Settings.data.ui.fontFixed
      pointSize: root.barFontSize
      color: root.fgColor
      visible: revealed && !root.textInsideIcon
    }

    Behavior on width {
      enabled: showAnim.running || hideAnim.running
      NumberAnimation {
        duration: Style.animationNormal
        easing.type: Easing.OutCubic
      }
    }
    Behavior on opacity {
      enabled: showAnim.running || hideAnim.running
      NumberAnimation {
        duration: Style.animationFast
        easing.type: Easing.OutCubic
      }
    }
  }

  Rectangle {
    id: iconCircle
    width: root.isVertical ? pillHeight : (hasIcon ? (root.iconSource !== "" ? svgContainer.width : pillHeight) : 0)
    height: root.isVertical ? (hasIcon ? (root.iconSource !== "" ? svgContainer.width : pillHeight) : 0) : pillHeight
    radius: Math.min(Style.radiusL, width / 2)
    color: "transparent" // Make icon background transparent to avoid double opacity
    anchors.centerIn: parent
    rotation: root.isVertical ? -90 : 0

    x: {
        if (root.isVertical) return (parent.width - width) / 2;
        if (root.textInsideIcon || (!showPill && !forceOpen)) {
            return (parent.width - width) / 2;
        }
        return oppositeDirection ? 0 : (parent.width - width);
    }

    NIcon {
      icon: root.icon
      visible: root.iconSource === "" && root.icon !== ""
      pointSize: iconSize
      color: root.fgColor
      x: (iconCircle.width - width) / 2
      y: (iconCircle.height - height) / 2 + (height - contentHeight) / 2
    }

    // SVG Container for masking and text anchoring
    Item {
        id: svgContainer
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // Center horizontally (always full width)
        anchors.leftMargin: (parent.width - width) / 2
        
        property real targetHeight: root.pillHeight * 0.75
        property real scaleFactor: targetHeight / 24
        
        width: Math.round(36 * scaleFactor)
        height: Math.round(24 * scaleFactor)
        clip: false

        Item {
            id: clipper
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: (root.charging || root.isPowerSaver) ? Math.round(31 * svgContainer.scaleFactor) : parent.width
            clip: true

            // Background Track Layer
            Image {
                id: svgTrack
                source: Qt.resolvedUrl("Assets/Icons/Battery/battery-100.svg")
                visible: root.iconSource !== ""
                width: svgContainer.width
                height: svgContainer.height
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                smooth: true
                opacity: 0.3     // Semi-transparent

                layer.enabled: true
                layer.effect: ShaderEffect {
                    property color targetColor: Settings.data.colorSchemes.darkMode ? "#FFFFFF" : "#1C1C1E"
                    property real colorizeMode: 1.0
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
                }
            }

            // Foreground Fill Layer
            Image {
                id: svgIcon
                source: root.iconSource
                visible: root.iconSource !== ""
                width: svgContainer.width
                height: svgContainer.height
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                smooth: true

                layer.enabled: true
                layer.effect: ShaderEffect {
                    readonly property color c: root.customIconColor.a > 0 ? root.customIconColor : root.fgColor
                    property color targetColor: c
                    property real colorizeMode: 1.0
                    fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
                }
            }
        }
    }

    // Charging/Power Saver Overlay (Replaces Terminal)
    Image {
        id: boltOverlay
        source: root.isPowerSaver ? Qt.resolvedUrl("Assets/Icons/Battery/plus.svg") : Qt.resolvedUrl("Assets/Icons/Battery/bolt.svg")
        visible: (root.charging || root.isPowerSaver) && root.iconSource !== ""
        
        property real scaleFactor: svgContainer.scaleFactor
        width: root.isPowerSaver ? Math.round(14 * scaleFactor) : Math.round(13 * scaleFactor)
        height: root.isPowerSaver ? Math.round(14 * scaleFactor) : Math.round(13 * scaleFactor)
        
        anchors.left: svgContainer.left
        anchors.leftMargin: (root.isPowerSaver
            ? Math.round(23 * scaleFactor)
            : Math.round(29 * scaleFactor) - Math.round(width * 0.2)) + 1
        anchors.verticalCenter: parent.verticalCenter
        z: 10
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 64
        sourceSize.height: 64
        smooth: true
        mipmap: true

        layer.enabled: true
        layer.effect: ShaderEffect {
            property color targetColor: Settings.data.colorSchemes.darkMode ? "#FFFFFF" : "#000000"
            property real colorizeMode: 1.0
            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
        }
    }

    
    NText {
      anchors.centerIn: svgContainer
      anchors.horizontalCenterOffset: -Math.round((root.text.length > 2 ? 3.5 : 2.5) * svgContainer.scaleFactor)
      anchors.verticalCenterOffset: Math.round(1.5 * svgContainer.scaleFactor) - 1
      text: root.text
      family: "Google Sans"
      font.weight: Font.Bold
      font.pixelSize: Math.round(15 * svgContainer.scaleFactor)
      color: root.textInsideIcon ? (Settings.data.colorSchemes.darkMode ? "#000000" : "#FFFFFF") : ((root.customIconColor.a > 0 && (root.customIconColor.r + root.customIconColor.g + root.customIconColor.b) > 1.5) ? "#000000" : "#FFFFFF")
      opacity: 0.75
      visible: root.textInsideIcon
    }
  }

  ParallelAnimation {
    id: showAnim
    running: false
    NumberAnimation {
      target: pill
      property: "width"
      from: 1
      to: pillMaxWidth
      duration: Style.animationNormal
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: pill
      property: "opacity"
      from: 0
      to: 1
      duration: Style.animationFast
      easing.type: Easing.OutCubic
    }
    onStarted: {
      showPill = true;
    }
    onStopped: {
      delayedHideAnim.start();
      root.shown();
    }
  }

  SequentialAnimation {
    id: delayedHideAnim
    running: false
    PauseAnimation {
      duration: 2500
    }
    ScriptAction {
      script: if (shouldAnimateHide) {
                hideAnim.start();
              }
    }
  }

  ParallelAnimation {
    id: hideAnim
    running: false
    NumberAnimation {
      target: pill
      property: "width"
      from: pillMaxWidth
      to: 1
      duration: Style.animationNormal
      easing.type: Easing.InCubic
    }
    NumberAnimation {
      target: pill
      property: "opacity"
      from: 1
      to: 0
      duration: Style.animationFast
      easing.type: Easing.InCubic
    }
    onStopped: {
      showPill = false;
      shouldAnimateHide = false;
      root.hidden();
    }
  }

  Timer {
    id: showTimer
    interval: Style.pillDelay
    onTriggered: {
      if (!showPill) {
        showAnim.start();
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: root.clicked ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: {
      hovered = true;
      root.entered();
      TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screen?.name), (forceOpen || forceClose) ? Style.tooltipDelay : Style.tooltipDelayLong);
      if (forceClose) {
        return;
      }
      if (!forceOpen) {
        showDelayed();
      }
    }
    onExited: {
      hovered = false;
      root.exited();
      if (!forceOpen && !forceClose) {
        hide();
      }
      TooltipService.hide();
    }
    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        root.clicked();
      } else if (mouse.button === Qt.RightButton) {
        root.rightClicked();
      } else if (mouse.button === Qt.MiddleButton) {
        root.middleClicked();
      }
    }
    onWheel: wheel => root.wheel(wheel.angleDelta.y)
  }

  function show() {
    if (collapseToIcon || root.text.trim().length === 0)
      return;
    if (!showPill) {
      shouldAnimateHide = autoHide;
      showAnim.start();
    } else {
      hideAnim.stop();
      delayedHideAnim.restart();
    }
  }

  function hide() {
    if (collapseToIcon)
      return;
    if (forceOpen) {
      return;
    }
    if (showPill) {
      hideAnim.start();
    }
    showTimer.stop();
  }

  function showDelayed() {
    if (collapseToIcon || root.text.trim().length === 0)
      return;
    if (!showPill) {
      shouldAnimateHide = autoHide;
      showTimer.start();
    } else {
      hideAnim.stop();
      delayedHideAnim.restart();
    }
  }

  onForceOpenChanged: {
    if (forceOpen) {
      // Immediately lock open without animations
      showAnim.stop();
      hideAnim.stop();
      delayedHideAnim.stop();
      showPill = true;
    } else {
      hide();
    }
  }
}
