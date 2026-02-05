import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

// World Clock Bar Widget Component
Item {
  id: root

  property var pluginApi: null

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Get timezones from settings
  readonly property var timezones: cfg.timezones || defaults.timezones || []
  readonly property int rotationInterval: cfg.rotationInterval ?? defaults.rotationInterval ?? 5000
  readonly property string timeFormat: cfg.timeFormat || defaults.timeFormat || "HH:mm"

  // Filter enabled timezones
  readonly property var enabledTimezones: {
    let enabled = [];
    for (let i = 0; i < timezones.length; i++) {
      if (timezones[i].enabled) {
        enabled.push(timezones[i]);
      }
    }
    return enabled;
  }

  property int currentIndex: 0
  property string currentTime: ""
  property string currentCity: ""

  readonly property real visualContentWidth: {
    if (isVertical) return root.capsuleHeight;
    var iconWidth = Style.toOdd(root.capsuleHeight * 0.6)
    var textWidth = timeText ? (timeText.implicitWidth + cityText.implicitWidth + Style.marginS * 2) : 100;
    return iconWidth + textWidth + Style.marginM * 2;
  }

  readonly property real visualContentHeight: {
    if (!isVertical) return root.capsuleHeight;
    var iconHeight = Style.toOdd(root.capsuleHeight * 0.45);
    var textHeight = root.barFontSize * 0.65 * 1.4; // Approximate text height
    return iconHeight + textHeight + Style.marginS * 2 + Style.marginM * 2;
  }

  readonly property real contentWidth: isVertical ? root.capsuleHeight : visualContentWidth
  readonly property real contentHeight: isVertical ? visualContentHeight : root.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Rotation timer
  Timer {
    id: rotationTimer
    interval: root.rotationInterval
    running: enabledTimezones.length > 1
    repeat: true
    onTriggered: {
      root.currentIndex = (root.currentIndex + 1) % enabledTimezones.length;
      updateTime();
    }
  }

  // Update time when Time singleton changes
  Connections {
    target: Time
    function onNowChanged() {
      updateTime();
    }
  }

  property var timeProcesses: ({})

  function updateTime() {
    if (enabledTimezones.length === 0) {
      currentCity = I18n.tr("world-clock.no-timezone");
      currentTime = "--:--";
      return;
    }

    let tz = enabledTimezones[currentIndex];
    currentCity = tz.name;

    // Get time using date command with TZ environment variable
    getTimeInTimezone(tz.timezone);
  }

  function getTimeInTimezone(timezone) {
    // Create format string based on user preference
    let format = timeFormat;
    if (format === "HH:mm") format = "+%H:%M";
    else if (format === "HH:mm:ss") format = "+%H:%M:%S";
    else if (format === "h:mm A") format = "+%I:%M %p";
    else if (format === "h:mm:ss A") format = "+%I:%M:%S %p";
    else format = "+%H:%M";

    let processId = "time_" + timezone.replace(/\//g, "_");
    
    if (!timeProcesses[processId]) {
      timeProcesses[processId] = timeProcessComponent.createObject(root, {
        processId: processId,
        timezone: timezone,
        dateFormat: format
      });
    } else {
      timeProcesses[processId].dateFormat = format;
      timeProcesses[processId].running = true;
    }
  }

  Component {
    id: timeProcessComponent
    Process {
      property string processId: ""
      property string timezone: ""
      property string dateFormat: "+%H:%M"
      
      running: false
      command: ["sh", "-c", "TZ=" + timezone + " date '" + dateFormat + "'"]
      stdout: StdioCollector {}
      
      Component.onCompleted: {
        running = true;
      }
      
      onExited: (exitCode) => {
        if (exitCode === 0) {
          root.currentTime = stdout.text.trim();
        }
      }
    }
  }

  readonly property string displayText: {
    if (enabledTimezones.length === 0) return I18n.tr("world-clock.no-timezone");
    return `${currentCity} ${currentTime}`;
  }

  readonly property string tooltipText: {
    if (enabledTimezones.length === 0) return pluginApi?.tr("world-clock.configure") || "Configure timezones";
    return `${currentCity}\n${currentTime}\n${pluginApi?.tr("world-clock.tooltip.click") || "Click to configure"}`;
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusM
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // Horizontal layout
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: isVertical ? 0 : Style.marginS 
      anchors.rightMargin: isVertical ? 0 : Style.marginS 
      anchors.topMargin: isVertical ? Style.marginS : 0
      anchors.bottomMargin: isVertical ? Style.marginS : 0
      spacing: Style.marginXS
      visible: !isVertical

      NIcon {
        icon: "history"
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        pointSize: Style.toOdd(Style.capsuleHeight * 0.5)
        Layout.alignment: Qt.AlignVCenter
      }

      NText {
        id: cityText
        text: root.currentCity
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        pointSize: root.barFontSize
        applyUiScale: false
        Layout.alignment: Qt.AlignVCenter
      }

      NText {
        id: timeText
        text: root.currentTime
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        pointSize: root.barFontSize
        font.weight: Font.Bold
        applyUiScale: false
        Layout.alignment: Qt.AlignVCenter
      }
    }

    // Vertical layout
    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginXS
      visible: isVertical

      NIcon {
        icon: "history"
        pointSize: Style.toOdd(root.capsuleHeight * 0.45)
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        Layout.alignment: Qt.AlignHCenter
      }

      NText {
        text: root.currentTime.substring(0, 5)
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        pointSize: root.barFontSize * 0.65
        applyUiScale: false
        Layout.alignment: Qt.AlignHCenter
        visible: enabledTimezones.length > 0
      }
    }
  }

  // Mouse interaction
  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: {
      if (pluginApi) {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }

    onEntered: {
      if (tooltipText) {
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection());
      }
    }

    onExited: {
      TooltipService.hide();
    }
  }

  Component.onCompleted: {
    updateTime();
  }
}
